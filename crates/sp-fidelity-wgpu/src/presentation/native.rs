//! Port of FrameInterpolationSwapchain{DX12,VK}, using their game-queue
//! composition path. Copyright (C) 2024 Advanced Micro Devices, Inc. MIT.
use super::{
    composition::Composition,
    pacing::{FramePacing, FramePacingTuning},
};
use crate::FfxWgpuBackend;
use sp_fidelity::{error::*, interface::*, types::*};
use std::{
    cell::RefCell,
    rc::Rc,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc,
    },
    thread,
    time::{Duration, Instant},
};

/// UI registration flags from the SDK's swapchain API.
pub const UI_PREMULTIPLIED_ALPHA: u32 = 1;
pub const UI_INTERNAL_DOUBLE_BUFFERING: u32 = 2;

#[derive(Clone, Debug)]
pub enum PresentationError {
    Sdk(FfxErrorCode),
    Gpu(String),
    Surface(&'static str),
    InvalidInput(&'static str),
    WorkerStopped,
    WorkerPanicked,
}
impl std::fmt::Display for PresentationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}
impl std::error::Error for PresentationError {}
impl From<FfxErrorCode> for PresentationError {
    fn from(e: FfxErrorCode) -> Self {
        Self::Sdk(e)
    }
}
type Result<T> = std::result::Result<T, PresentationError>;

/// Immutable metadata for one actual presentation call.
#[derive(Clone, Copy, Debug)]
pub struct PresentInfo {
    pub frame_id: u64,
    pub interpolated: bool,
}

/// Acquired target with its presentation operation. Dropping it without calling
/// present discards the acquisition (including a wgpu SurfaceTexture).
type PresentOperation = Box<dyn FnOnce(&wgpu::Queue, PresentInfo) -> Result<()> + Send>;

pub struct PresentFrame {
    pub texture: wgpu::Texture,
    present: PresentOperation,
}
impl PresentFrame {
    pub fn new(
        texture: wgpu::Texture,
        present: impl FnOnce(&wgpu::Queue, PresentInfo) -> Result<()> + Send + 'static,
    ) -> Self {
        Self {
            texture,
            present: Box::new(present),
        }
    }
}

/// Presentation boundary. Initial configuration runs on the creating thread;
/// later configuration and generated-frame acquisition run on the presentation worker.
/// Real-only default composition acquires/presents on the creating thread. The
/// built-in target wraps a real wgpu surface; integrations may supply another.
pub trait PresentationTarget: Send + 'static {
    fn configure(
        &mut self,
        device: &wgpu::Device,
        config: &wgpu::SurfaceConfiguration,
    ) -> Result<()>;
    fn acquire(&mut self) -> Result<PresentFrame>;
}

pub struct SurfaceTarget {
    surface: Arc<wgpu::Surface<'static>>,
}
impl SurfaceTarget {
    pub fn new(surface: Arc<wgpu::Surface<'static>>) -> Self {
        Self { surface }
    }
}
impl PresentationTarget for SurfaceTarget {
    fn configure(
        &mut self,
        device: &wgpu::Device,
        config: &wgpu::SurfaceConfiguration,
    ) -> Result<()> {
        let mut config = config.clone();
        let raw = config.format.remove_srgb_suffix();
        if raw != config.format && !config.view_formats.contains(&raw) {
            config.view_formats.push(raw);
        }
        self.surface.configure(device, &config);
        Ok(())
    }
    fn acquire(&mut self) -> Result<PresentFrame> {
        let surface = match self.surface.get_current_texture() {
            wgpu::CurrentSurfaceTexture::Success(frame)
            | wgpu::CurrentSurfaceTexture::Suboptimal(frame) => frame,
            wgpu::CurrentSurfaceTexture::Timeout => {
                return Err(PresentationError::Surface("timeout"));
            }
            wgpu::CurrentSurfaceTexture::Occluded => {
                return Err(PresentationError::Surface("occluded"));
            }
            wgpu::CurrentSurfaceTexture::Outdated => {
                return Err(PresentationError::Surface("outdated"));
            }
            wgpu::CurrentSurfaceTexture::Lost => return Err(PresentationError::Surface("lost")),
            wgpu::CurrentSurfaceTexture::Validation => {
                return Err(PresentationError::Surface("validation"));
            }
        };
        Ok(PresentFrame::new(
            surface.texture.clone(),
            move |queue, _| {
                queue.present(surface);
                Ok(())
            },
        ))
    }
}

/// GPU-complete and present-call timing; these are not physical scanout times.
#[derive(Clone, Debug, Default)]
pub struct PresentationReport {
    pub frame_id: u64,
    pub generated: bool,
    pub interpolation_complete: Option<Instant>,
    pub present_calls: Vec<Instant>,
    pub pacing_interval: Duration,
}

struct Output {
    texture: wgpu::Texture,
    info: PresentInfo,
}
struct Job {
    ready: wgpu::SubmissionIndex,
    frames: Vec<Output>,
    reset: bool,
    generated: bool,
    debug: bool,
    tuning: FramePacingTuning,
    done: mpsc::Sender<Result<PresentationReport>>,
    report: PresentationReport,
}
enum Work {
    Present(Job),
    Configure(wgpu::SurfaceConfiguration, mpsc::Sender<Result<()>>),
}
struct Slot {
    interpolated: wgpu::Texture,
    composed: [wgpu::Texture; 2],
    pending: Option<mpsc::Receiver<Result<PresentationReport>>>,
}

/// Native equivalent of AMD's frame interpolation swapchain. The consumer
/// supplies the window/surface and controls rendering; this adapter owns only
/// generation dispatch, composition, resource reuse and presentation.
pub struct FrameInterpolationSwapchain {
    backend: Rc<RefCell<FfxWgpuBackend>>,
    device: wgpu::Device,
    queue: wgpu::Queue,
    pending_config: Rc<RefCell<FfxFrameGenerationConfig>>,
    config: FfxFrameGenerationConfig,
    surface_config: wgpu::SurfaceConfiguration,
    composition: Composition,
    slots: Vec<Slot>,
    next_slot: usize,
    ui: Option<wgpu::Texture>,
    ui_flags: u32,
    reset: bool,
    transfer: FfxBackbufferTransferFunction,
    luminance: [f32; 2],
    tuning: FramePacingTuning,
    sender: Option<mpsc::SyncSender<Work>>,
    stop: Arc<AtomicBool>,
    workers: Vec<thread::JoinHandle<()>>,
    fault: Arc<Mutex<Option<PresentationError>>>,
    reports: Vec<PresentationReport>,
    last_submission: Option<wgpu::SubmissionIndex>,
    target: Arc<Mutex<Box<dyn PresentationTarget>>>,
    debug_index: u32,
}

impl FrameInterpolationSwapchain {
    /// Configures the supplied target and installs the SDK configuration hook
    /// on `backend`. Keep this adapter alive until the SDK stops using its hook.
    pub fn new(
        backend: Rc<RefCell<FfxWgpuBackend>>,
        queue: &wgpu::Queue,
        mut target: impl PresentationTarget,
        config: &wgpu::SurfaceConfiguration,
    ) -> Result<Self> {
        let device = backend.borrow().device.clone();
        target.configure(&device, config)?;
        let pending_config = Rc::new(RefCell::new(FfxFrameGenerationConfig::default()));
        let weak = Rc::downgrade(&pending_config);
        backend
            .borrow_mut()
            .set_frame_generation_configurator(Some(Box::new(move |config| {
                let pending = weak.upgrade().ok_or(FFX_ERROR_INVALID_POINTER)?;
                *pending.borrow_mut() = config.clone();
                Ok(())
            })));
        let stop = Arc::new(AtomicBool::new(false));
        let fault = Arc::new(Mutex::new(None));
        let (send, receive) = mpsc::sync_channel(1);
        let (paced_send, paced_receive) = mpsc::sync_channel(1);
        let pacer_device = device.clone();
        let pacer_stop = stop.clone();
        let pacer_fault = fault.clone();
        let pacer = thread::Builder::new()
            .name("FSR completion pacing".into())
            .spawn(move || {
                pace(pacer_device, receive, paced_send, pacer_stop, pacer_fault);
            })
            .map_err(|e| PresentationError::Gpu(e.to_string()))?;
        let target: Arc<Mutex<Box<dyn PresentationTarget>>> =
            Arc::new(Mutex::new(Box::new(target)));
        let worker_target = target.clone();
        let present_device = device.clone();
        let present_queue = queue.clone();
        let present_stop = stop.clone();
        let present_fault = fault.clone();
        let presenter = match thread::Builder::new()
            .name("FSR presentation".into())
            .spawn(move || {
                present_loop(
                    present_device,
                    present_queue,
                    worker_target,
                    paced_receive,
                    present_stop,
                    present_fault,
                );
            }) {
            Ok(worker) => worker,
            Err(e) => {
                drop(send);
                let _ = pacer.join();
                return Err(PresentationError::Gpu(e.to_string()));
            }
        };
        let slots = make_slots(&device, config);
        Ok(Self {
            composition: Composition::new(&device),
            backend,
            device,
            queue: queue.clone(),
            pending_config,
            config: Default::default(),
            surface_config: config.clone(),
            slots,
            next_slot: 0,
            ui: None,
            ui_flags: 0,
            reset: true,
            transfer: FfxBackbufferTransferFunction::Srgb,
            luminance: [0., 1000.],
            tuning: Default::default(),
            sender: Some(send),
            stop,
            workers: vec![pacer, presenter],
            fault,
            reports: Vec::new(),
            last_submission: None,
            target,
            debug_index: 0,
        })
    }

    /// Explicit configuration for standalone interpolation users. Composite
    /// FSR3 users call `ffx_fsr3_configure_frame_generation` instead.
    pub fn configure_frame_generation(&mut self, config: &FfxFrameGenerationConfig) -> Result<()> {
        *self.pending_config.borrow_mut() = config.clone();
        self.apply_config()
    }

    fn apply_config(&mut self) -> Result<()> {
        let next = self.pending_config.borrow().clone();
        let same_callback = match (
            &self.config.frame_generation_callback,
            &next.frame_generation_callback,
        ) {
            (Some(a), Some(b)) => Rc::ptr_eq(a, b),
            (None, None) => true,
            _ => false,
        };
        let same_present = match (&self.config.present_callback, &next.present_callback) {
            (Some(a), Some(b)) => Rc::ptr_eq(a, b),
            (None, None) => true,
            _ => false,
        };
        if self.config.frame_generation_enabled != next.frame_generation_enabled
            || !same_callback
            || !same_present
            || self.config.allow_async_workloads != next.allow_async_workloads
            || self.config.flags != next.flags
        {
            self.wait_for_presents()?;
            if next.frame_generation_enabled {
                self.reset = true;
            }
        }
        self.config = next;
        Ok(())
    }

    /// UI is consumed on the owner queue before `present` returns. This is
    /// stronger than AMD's optional internal-copy lifetime guarantee: both
    /// registration modes can safely update their input after present returns.
    pub fn register_ui_resource(&mut self, texture: Option<&wgpu::Texture>, flags: u32) {
        self.ui = texture.cloned();
        self.ui_flags = flags;
    }
    pub fn set_transfer_function(
        &mut self,
        transfer: FfxBackbufferTransferFunction,
        luminance: [f32; 2],
    ) -> Result<()> {
        self.wait_for_presents()?;
        self.transfer = transfer;
        self.luminance = luminance;
        self.reset = true;
        Ok(())
    }
    pub fn set_frame_pacing_tuning(&mut self, tuning: FramePacingTuning) {
        self.tuning = tuning;
    }
    pub fn reset_history(&mut self) {
        self.reset = true;
    }

    /// Submit the caller's live SDK command list, generate and compose the
    /// frame, then enqueue paced presentation. Configure HUD-less resources
    /// within this same live command-list scope. This consumes the command
    /// list and its external resource handles, like `ffx_take_command_list_wgpu`.
    /// An error while draining earlier work or validating inputs leaves the
    /// list live. On any error, retrieve and submit/discard it if still present;
    /// a generation failure consumes it and queues the real-frame fallback.
    pub fn present(&mut self, command_list: FfxCommandList, color: &wgpu::Texture) -> Result<()> {
        self.present_with_interpolation(command_list, color, None)
    }

    /// SDK's externally recorded interpolation path. `interpolated` must have
    /// been written by this command list (or an earlier submission on this queue).
    pub fn present_with_interpolation(
        &mut self,
        command_list: FfxCommandList,
        color: &wgpu::Texture,
        interpolated: Option<&wgpu::Texture>,
    ) -> Result<()> {
        self.apply_config()?;
        if let Some(error) = self.fault.lock().unwrap().clone() {
            return Err(error);
        }
        self.retire_slot(self.next_slot)?;
        if color.width() != self.surface_config.width
            || color.height() != self.surface_config.height
            || !color
                .usage()
                .contains(wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_SRC)
        {
            return Err(PresentationError::InvalidInput(
                "present color must match output size and have TEXTURE_BINDING | COPY_SRC",
            ));
        }
        if self.ui.as_ref().is_some_and(|ui| ui.size() != color.size()) {
            return Err(PresentationError::InvalidInput("UI must match output size"));
        }
        let slot = &self.slots[self.next_slot];
        let mut generated = None;
        let mut generation_error = None;
        if self.config.frame_generation_enabled {
            if let Some(texture) = interpolated {
                generated = Some(texture.clone());
            } else if let Some(callback) = &self.config.frame_generation_callback {
                let description = {
                    let mut backend = self.backend.borrow_mut();
                    let color = backend.ffx_get_resource_wgpu(
                        color,
                        "FSR present color",
                        FFX_RESOURCE_STATE_COMPUTE_READ,
                    );
                    let output = backend.ffx_get_resource_wgpu(
                        &slot.interpolated,
                        "FSR interpolated",
                        FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                    );
                    FfxFrameGenerationDispatchDescription {
                        command_list,
                        present_color: color,
                        outputs: [
                            output,
                            Default::default(),
                            Default::default(),
                            Default::default(),
                        ],
                        num_interpolated_frames: 1,
                        reset: self.reset,
                        back_buffer_transfer_function: self.transfer,
                        min_max_luminance: self.luminance,
                        interpolation_rect: self.config.interpolation_rect,
                        frame_id: self.config.frame_id,
                    }
                };
                match callback(&description) {
                    Ok(()) => generated = Some(slot.interpolated.clone()),
                    Err(e) => generation_error = Some(PresentationError::Sdk(e)),
                }
            }
        }
        let mut backend = self.backend.borrow_mut();
        if let Some(e) = backend.take_job_error() {
            generation_error = Some(PresentationError::Gpu(e.to_string()));
            generated = None;
        }
        drop(backend);
        // Match the SDK's non-interpolated present: one composition into the
        // acquired back buffer on the game queue. Acquire/drain before consuming
        // the encoder so a surface failure still leaves the caller's list live.
        if generated.is_none() {
            self.reset = true;
        }
        let direct = if generated.is_none() && self.config.present_callback.is_none() {
            if self.slots.iter().any(|slot| slot.pending.is_some()) {
                self.wait_for_presents()?;
            }
            Some(self.target.lock().unwrap().acquire()?)
        } else {
            None
        };
        let mut backend = self.backend.borrow_mut();
        let mut encoder = backend
            .ffx_take_command_list_wgpu(command_list)
            .ok_or(PresentationError::InvalidInput("invalid command list"))?;
        drop(backend);
        if let Some(acquired) = direct {
            self.composition.encode(
                &self.device,
                &mut encoder,
                color,
                self.ui.as_ref(),
                &acquired.texture,
                self.ui_flags & UI_PREMULTIPLIED_ALPHA != 0,
                self.config
                    .draw_debug_pacing_lines
                    .then_some(self.debug_index),
            );
            self.debug_index = (self.debug_index + 1) % 6;
            self.last_submission = Some(self.queue.submit([encoder.finish()]));
            let now = Instant::now();
            (acquired.present)(
                &self.queue,
                PresentInfo {
                    frame_id: self.config.frame_id,
                    interpolated: false,
                },
            )?;
            if self.reports.len() == self.slots.len() {
                self.reports.remove(0);
            }
            self.reports.push(PresentationReport {
                frame_id: self.config.frame_id,
                present_calls: vec![now],
                ..Default::default()
            });
            self.reset = true;
            return generation_error.map_or(Ok(()), Err);
        }
        // A custom callback may fail after consuming its list. Preserve the
        // caller's submitted-scene boundary even in that error case.
        if self.config.present_callback.is_some() {
            self.last_submission = Some(self.queue.submit([encoder.finish()]));
            encoder = self.device.create_command_encoder(&Default::default());
        }
        let slot = &self.slots[self.next_slot];
        let has_generated = generated.is_some();
        let reset = self.reset;
        self.reset = !has_generated;
        let mut frames = Vec::with_capacity(2);
        let mut sources = Vec::with_capacity(2);
        if let Some(generated) = generated {
            sources.push((generated, true));
        }
        // An SDK failure must still show the real frame, never uninitialized FI.
        if !self.config.only_present_interpolated || !has_generated {
            sources.push((color.clone(), false));
        }
        for (i, (source, is_interpolated)) in sources.into_iter().enumerate() {
            let target = &slot.composed[i];
            if let Some(callback) = &self.config.present_callback {
                let desc = {
                    let mut backend = self.backend.borrow_mut();
                    let list = backend.ffx_get_command_list_wgpu(encoder);
                    FfxPresentCallbackDescription {
                        device: 1,
                        command_list: list,
                        current_back_buffer: backend.ffx_get_resource_wgpu(
                            &source,
                            "FSR composition input",
                            FFX_RESOURCE_STATE_COMPUTE_READ,
                        ),
                        current_ui: self
                            .ui
                            .as_ref()
                            .map(|ui| {
                                backend.ffx_get_resource_wgpu(
                                    ui,
                                    "FSR UI",
                                    FFX_RESOURCE_STATE_COMPUTE_READ,
                                )
                            })
                            .unwrap_or_default(),
                        output_swap_chain_buffer: backend.ffx_get_resource_wgpu(
                            target,
                            "FSR composition output",
                            FFX_RESOURCE_STATE_RENDER_TARGET,
                        ),
                        is_interpolated_frame: is_interpolated,
                        use_premul_alpha: self.ui_flags & UI_PREMULTIPLIED_ALPHA != 0,
                        frame_id: self.config.frame_id,
                    }
                };
                let result = callback(&desc);
                encoder = self
                    .backend
                    .borrow_mut()
                    .ffx_take_command_list_wgpu(desc.command_list)
                    .ok_or(PresentationError::InvalidInput(
                        "callback consumed its command list",
                    ))?;
                result?;
            } else {
                self.composition.encode(
                    &self.device,
                    &mut encoder,
                    &source,
                    self.ui.as_ref(),
                    target,
                    self.ui_flags & UI_PREMULTIPLIED_ALPHA != 0,
                    None,
                );
            }
            frames.push(Output {
                texture: target.clone(),
                info: PresentInfo {
                    frame_id: self.config.frame_id,
                    interpolated: is_interpolated,
                },
            });
        }
        let ready = self.queue.submit([encoder.finish()]);
        self.last_submission = Some(ready.clone());
        let (done, pending) = mpsc::channel();
        let job = Job {
            ready,
            frames,
            reset,
            generated: has_generated,
            debug: self.config.draw_debug_pacing_lines,
            tuning: self.tuning,
            done,
            report: PresentationReport {
                frame_id: self.config.frame_id,
                generated: has_generated,
                ..Default::default()
            },
        };
        self.sender
            .as_ref()
            .ok_or(PresentationError::WorkerStopped)?
            .send(Work::Present(job))
            .map_err(|_| PresentationError::WorkerStopped)?;
        self.slots[self.next_slot].pending = Some(pending);
        self.next_slot = (self.next_slot + 1) % self.slots.len();
        if let Some(e) = generation_error {
            return Err(e);
        }
        Ok(())
    }

    fn retire_slot(&mut self, index: usize) -> Result<()> {
        if let Some(pending) = self.slots[index].pending.take() {
            let report = pending
                .recv()
                .map_err(|_| PresentationError::WorkerStopped)??;
            if self.reports.len() == self.slots.len() {
                self.reports.remove(0);
            }
            self.reports.push(report);
        }
        Ok(())
    }
    pub fn wait_for_presents(&mut self) -> Result<()> {
        let mut error = None;
        for index in 0..self.slots.len() {
            if let Err(e) = self.retire_slot(index) {
                error.get_or_insert(e);
            }
        }
        // Composition can have been submitted even if a callback or surface
        // fails before a presentation job is acknowledged.
        // Retired workers have submitted their final surface copies, but no
        // longer CPU-wait for them. A queue marker covers those reads as well
        // as caller/composition work, including failed presentation attempts.
        if self.last_submission.take().is_some()
            && let Err(e) = wait_gpu(&self.device, self.queue.submit([]), &self.stop)
        {
            error.get_or_insert(e);
        }
        error.map_or(Ok(()), Err)
    }
    /// Drain the latest two retired reports. Older unread reports are replaced.
    pub fn take_reports(&mut self) -> Vec<PresentationReport> {
        self.reports
            .sort_by_key(|report| report.present_calls.last().copied());
        std::mem::take(&mut self.reports)
    }
    /// Drain acquisitions and GPU reads before reconfiguring the surface.
    pub fn resize(&mut self, config: &wgpu::SurfaceConfiguration) -> Result<()> {
        // A recoverable surface error is consumed here; reconfiguration is its recovery.
        let prior = self.wait_for_presents();
        if let Err(e) = prior
            && !matches!(e, PresentationError::Surface(_))
        {
            return Err(e);
        }
        let (send, receive) = mpsc::channel();
        self.sender
            .as_ref()
            .ok_or(PresentationError::WorkerStopped)?
            .send(Work::Configure(config.clone(), send))
            .map_err(|_| PresentationError::WorkerStopped)?;
        receive
            .recv()
            .map_err(|_| PresentationError::WorkerStopped)??;
        *self.fault.lock().unwrap() = None;
        self.surface_config = config.clone();
        self.slots = make_slots(&self.device, config);
        self.next_slot = 0;
        self.reset = true;
        Ok(())
    }
    pub fn shutdown(mut self) -> Result<()> {
        let result = self.wait_for_presents();
        self.sender.take();
        let mut panicked = false;
        for worker in self.workers.drain(..) {
            panicked |= worker.join().is_err();
        }
        if panicked {
            Err(PresentationError::WorkerPanicked)
        } else {
            result
        }
    }
}
impl Drop for FrameInterpolationSwapchain {
    fn drop(&mut self) {
        self.stop.store(true, Ordering::Release);
        self.sender.take();
        for worker in self.workers.drain(..) {
            let _ = worker.join();
        }
    }
}

fn make_slots(device: &wgpu::Device, config: &wgpu::SurfaceConfiguration) -> Vec<Slot> {
    let format = match config.format.remove_srgb_suffix() {
        wgpu::TextureFormat::Bgra8Unorm => wgpu::TextureFormat::Rgba8Unorm,
        x => x,
    };
    (0..2)
        .map(|_| {
            let texture = |label, storage| {
                device.create_texture(&wgpu::TextureDescriptor {
                    label: Some(label),
                    size: wgpu::Extent3d {
                        width: config.width,
                        height: config.height,
                        depth_or_array_layers: 1,
                    },
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format,
                    usage: wgpu::TextureUsages::TEXTURE_BINDING
                        | wgpu::TextureUsages::COPY_SRC
                        | wgpu::TextureUsages::COPY_DST
                        | wgpu::TextureUsages::RENDER_ATTACHMENT
                        | if storage {
                            wgpu::TextureUsages::STORAGE_BINDING
                        } else {
                            wgpu::TextureUsages::empty()
                        },
                    view_formats: &[],
                })
            };
            Slot {
                interpolated: texture("FSR interpolation output", true),
                composed: [
                    texture("FSR prepared presentation", false),
                    texture("FSR prepared presentation", false),
                ],
                pending: None,
            }
        })
        .collect()
}

fn wait_gpu(device: &wgpu::Device, index: wgpu::SubmissionIndex, stop: &AtomicBool) -> Result<()> {
    loop {
        if stop.load(Ordering::Acquire) {
            return Err(PresentationError::WorkerStopped);
        }
        match device.poll(wgpu::PollType::Wait {
            submission_index: Some(index.clone()),
            timeout: Some(Duration::from_millis(50)),
        }) {
            Ok(_) => return Ok(()),
            Err(wgpu::PollError::Timeout) => {}
            Err(e) => return Err(PresentationError::Gpu(e.to_string())),
        }
    }
}
fn pace(
    device: wgpu::Device,
    receive: mpsc::Receiver<Work>,
    send: mpsc::SyncSender<Work>,
    stop: Arc<AtomicBool>,
    fault: Arc<Mutex<Option<PresentationError>>>,
) {
    let epoch = Instant::now();
    let mut estimator = FramePacing::new(1_000_000_000);
    while let Ok(work) = receive.recv() {
        let work = match work {
            Work::Present(mut job) => {
                if !job.generated || job.reset {
                    estimator = FramePacing::new(1_000_000_000);
                }
                let error = fault.lock().unwrap().clone();
                let result = error.map_or_else(|| wait_gpu(&device, job.ready.clone(), &stop), Err);
                if let Err(e) = result {
                    *fault.lock().unwrap() = Some(e.clone());
                    let _ = job.done.send(Err(e));
                    continue;
                }
                let now = Instant::now();
                job.report.interpolation_complete = Some(now);
                if job.generated {
                    job.report.pacing_interval = Duration::from_nanos(estimator.sample(
                        now.duration_since(epoch).as_nanos() as i64 + 1,
                        job.reset,
                        job.tuning,
                    ) as u64);
                }
                Work::Present(job)
            }
            other => other,
        };
        if send.send(work).is_err() {
            break;
        }
    }
}
fn present_loop(
    device: wgpu::Device,
    queue: wgpu::Queue,
    target: Arc<Mutex<Box<dyn PresentationTarget>>>,
    receive: mpsc::Receiver<Work>,
    stop: Arc<AtomicBool>,
    fault: Arc<Mutex<Option<PresentationError>>>,
) {
    let mut composition = Composition::new(&device);
    let mut previous = None::<Instant>;
    let mut debug_index = 0;
    while let Ok(work) = receive.recv() {
        match work {
            Work::Configure(config, done) => {
                let result = target.lock().unwrap().configure(&device, &config);
                previous = None;
                let _ = done.send(result);
            }
            Work::Present(mut job) => {
                let result = (|| {
                    if let Some(e) = fault.lock().unwrap().clone() {
                        return Err(e);
                    }
                    for output in job.frames {
                        if stop.load(Ordering::Acquire) {
                            return Err(PresentationError::WorkerStopped);
                        }
                        let acquired = target.lock().unwrap().acquire()?;
                        let mut encoder = device.create_command_encoder(&Default::default());
                        composition.encode(
                            &device,
                            &mut encoder,
                            &output.texture,
                            None,
                            &acquired.texture,
                            false,
                            job.debug.then_some(debug_index),
                        );
                        if job.debug {
                            debug_index = (debug_index + 1) % 6;
                        }
                        // Queue ordering guarantees the surface copy finishes
                        // before presentation; CPU completion waits serialize
                        // the single wgpu queue and can sit behind newer scenes.
                        queue.submit([encoder.finish()]);
                        if let Some(previous) = previous {
                            wait_deadline(
                                previous + job.report.pacing_interval,
                                job.tuning,
                                &stop,
                            )?;
                        }
                        let now = Instant::now();
                        previous = Some(now);
                        (acquired.present)(&queue, output.info)?;
                        job.report.present_calls.push(now);
                    }
                    Ok(job.report)
                })();
                if let Err(e) = &result
                    && !matches!(e, PresentationError::Surface("occluded" | "timeout"))
                {
                    *fault.lock().unwrap() = Some(e.clone());
                }
                let _ = job.done.send(result);
            }
        }
    }
}
fn wait_deadline(deadline: Instant, tuning: FramePacingTuning, stop: &AtomicBool) -> Result<()> {
    while let Some(left) = deadline.checked_duration_since(Instant::now()) {
        if stop.load(Ordering::Acquire) {
            return Err(PresentationError::WorkerStopped);
        }
        let spin = Duration::from_millis(u64::from(tuning.hybrid_spin_ms));
        if tuning.allow_hybrid_spin && left > spin {
            thread::sleep((left - spin).min(Duration::from_millis(1)));
        } else {
            std::hint::spin_loop();
        }
    }
    Ok(())
}
