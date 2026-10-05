//! wgpu backend for the [`sp_fidelity`] port: an implementation of the SDK's
//! backend function table, [`FfxInterface`], as AMD's DX12 and Vulkan backends
//! (`sdk/src/backends/{dx12,vk}`) implement `FfxInterface` for their APIs.
//!
//! Resources and pipelines come from the SDK's resource and pipeline
//! descriptions and shader blobs: pipeline layouts follow each blob's binding
//! tables (registers `tN`, `uN`, `bN`, `sN` at the port's WGSL binding
//! offsets), with each binding's type reflected from the port's WGSL for that
//! blob. GPU jobs are recorded into the caller's `wgpu::CommandEncoder`.
//!
//! Where the SDK's DX12 backend takes pointers, this backend takes ownership
//! for the duration of a scope:
//!
//! - `FfxCommandList`: [`FfxWgpuBackend::ffx_get_command_list_wgpu`] moves the
//!   caller's encoder into the backend and returns its handle (the analogue of
//!   `ffxGetCommandListDX12`); [`FfxWgpuBackend::ffx_take_command_list_wgpu`]
//!   returns the encoder with the executed jobs recorded.
//! - `FfxResource::resource`: [`FfxWgpuBackend::ffx_get_resource_wgpu`] (the
//!   analogue of `ffxGetResourceDX12`) returns a handle to the caller's texture
//!   that stays valid until the next `ffx_take_command_list_wgpu`.
//!
//! Platform workarounds live here and only here: the bounded indirect dispatch
//! grid (SDK-P10, `dispatch_grid.rs`), the missing forced-wave64 mode
//! (SDK-P6: the reported shader model stays below 6.6, so the SDK never
//! selects a wave64 permutation), `R32G32_FLOAT` UAVs allocated as
//! `Rgba32Float` (Metal has no read-write `Rg32Float` storage texture) and a
//! storage buffer backing a texture that a pipeline binds as a buffer (WGSL
//! texture atomics return nothing; see `FfxWgpuBackend::back_buffer_bindings`)
//! and a job that fails before it records when wgpu rejects its views or bind
//! group (SDK-P28: wgpu would invalidate the caller's whole encoder; see
//! [`FfxWgpuBackend::take_job_error`]). Nothing else differs from the SDK.
use sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index;
use sp_fidelity::error::*;
use sp_fidelity::interface::*;
use sp_fidelity::shaders::*;
use sp_fidelity::types::*;
use std::cell::RefCell;
use std::collections::HashMap;
use std::num::NonZeroU32;
use std::rc::Rc;
use wgpu::util::DeviceExt;

mod dispatch_grid;
pub mod readback;

/// The wgpu features every SDK pass needs; request them when creating the
/// device. [`optional_features`] adds the FP16 permutations.
///
/// Derived from the FSR2 WGSL (`fsr2/ffx_fsr2_callbacks.wgsl`) and the
/// resources `ffx_fsr2.cpp` creates:
///
/// - `SUBGROUP`: SPD's wave operations in the luminance pyramid.
/// - `TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES`: UAVs in formats outside
///   WebGPU's core storage set (`R16G16_FLOAT`, `R16_FLOAT`, `R8_UNORM`,
///   `R8G8_UNORM`, `R11G11B10_FLOAT`) and read-write UAVs (`R8_UNORM` new
///   locks, `R16_FLOAT` exposure mips, the `R32G32_FLOAT` auto exposure
///   allocated as `Rgba32Float`).
/// - `TEXTURE_ATOMIC`: `InterlockedMin`/`InterlockedMax` on the `R32_UINT`
///   reconstructed previous depth.
/// - `TEXTURE_FORMAT_16BIT_NORM`: the `R16_SNORM` Lanczos and maximum-bias
///   lookup textures.
/// - `FLOAT32_FILTERABLE`: linear sampling of 32-bit float application inputs
///   (`SampleInputColor`).
pub fn required_features() -> wgpu::Features {
    wgpu::Features::SUBGROUP
        | wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES
        | wgpu::Features::TEXTURE_ATOMIC
        | wgpu::Features::TEXTURE_FORMAT_16BIT_NORM
        | wgpu::Features::FLOAT32_FILTERABLE
}

/// Optional features: with `SHADER_F16` the backend reports `fp16Supported`,
/// and the SDK selects its FP16 permutations.
pub fn optional_features() -> wgpu::Features {
    wgpu::Features::SHADER_F16
}

/// A resource bound by a job, as seen by a [`FfxWgpuJobObserver`].
#[derive(Clone, Copy, Debug)]
pub enum FfxWgpuObject<'a> {
    Texture(&'a wgpu::Texture),
    Buffer(&'a wgpu::Buffer),
}

/// One resource of a job.
#[derive(Clone, Copy, Debug)]
pub struct FfxWgpuObservedResource<'a> {
    /// The SDK binding name (`"r_input_color"`), or `"cmdArgument"`, `"src"`,
    /// `"dst"` or `"target"` for indirect arguments, copies and clears.
    pub binding: &'a str,
    /// The name the resource was created or registered with.
    pub name: &'a str,
    /// Its SDK description, whose type and format the object's can differ
    /// from: an `R32G32_FLOAT` UAV is an `Rgba32Float` texture, and a
    /// texture a pipeline binds as a buffer is a buffer of its texels.
    pub description: FfxResourceDescription,
    pub object: FfxWgpuObject<'a>,
    /// The bound mip of a UAV texture; 0 otherwise.
    pub mip: u32,
    /// Whether the job may write the resource.
    pub writable: bool,
}

/// A job about to be recorded (`after == false`) or just recorded.
pub struct FfxWgpuJobObservation<'a> {
    pub device: &'a wgpu::Device,
    pub encoder: &'a mut wgpu::CommandEncoder,
    pub job: &'a FfxGpuJobDescription,
    /// The effect and pass of a compute job's pipeline.
    pub pass: Option<(FfxEffect, FfxPass)>,
    pub after: bool,
    pub resources: Vec<FfxWgpuObservedResource<'a>>,
}

/// Called around every GPU job in `execute_gpu_jobs`, for captures and
/// fidelity tests. It may record into the encoder.
pub type FfxWgpuJobObserver = Box<dyn FnMut(&mut FfxWgpuJobObservation<'_>)>;

#[derive(Clone, Debug, PartialEq)]
enum Object {
    Texture(wgpu::Texture),
    Buffer(wgpu::Buffer),
}

impl Object {
    fn observed(&self) -> FfxWgpuObject<'_> {
        match self {
            Self::Texture(texture) => FfxWgpuObject::Texture(texture),
            Self::Buffer(buffer) => FfxWgpuObject::Buffer(buffer),
        }
    }

    /// The mip a UAV binding of `mip` views: a mip the texture lacks is its
    /// last, as AMD's Vulkan backend binds it (`executeGpuJobCompute`,
    /// `sdk/src/backends/vk/ffx_vk.cpp:3769-3771`). FSR2's luminance pyramid
    /// binds mips 4 and 5 of a texture that has them only from a 64-pixel
    /// maximum render size (`ffx_fsr2.cpp:669-678, 998-1004`).
    fn uav_mip(&self, mip: u32) -> u32 {
        match self {
            Self::Texture(texture) => mip.min(texture.mip_level_count().saturating_sub(1)),
            Self::Buffer(_) => mip,
        }
    }
}

/// What an `FfxResource::resource` handle refers to.
#[derive(Clone, Debug)]
struct Handle {
    object: Object,
    description: FfxResourceDescription,
    name: String,
}

struct Resource {
    handle: Handle,
    state: FfxResourceStates,
    effect_context_id: u32,
    /// Registered by `fpRegisterResource`; released by `fpUnregisterResources`.
    dynamic: bool,
    /// The `FfxResource::resource` that `fpGetResource` returns.
    handle_id: usize,
    /// Row pitch of an upload buffer that initializes a texture.
    upload_row_pitch: Option<u32>,
    bytes: u64,
}

struct Pipeline {
    effect: FfxEffect,
    pass: FfxPass,
    pipeline: wgpu::ComputePipeline,
    layout: wgpu::BindGroupLayout,
    /// Layout entries by WGSL binding.
    entries: HashMap<u32, wgpu::BindGroupLayoutEntry>,
    /// Constant buffer sizes by WGSL binding, from the WGSL declaration.
    constant_sizes: HashMap<u32, u64>,
    /// One uniform buffer per constant buffer binding, which each job's
    /// constants are copied into before it runs.
    constants: Vec<(u32, wgpu::Buffer)>,
    samplers: Vec<(u32, wgpu::Sampler)>,
    grid_group: Option<wgpu::BindGroup>,
    /// The groups of the latest jobs with what each binds, most recent
    /// first. FSR2's passes bind one of two resource sets, alternating by
    /// frame (`ffx_fsr2.cpp:1056-1069`), so two are kept.
    groups: RefCell<Vec<(Vec<JobBinding>, wgpu::BindGroup)>>,
}

/// Groups each pipeline keeps (`Pipeline::groups`).
const KEPT_GROUPS: usize = 2;

/// What a compute job binds at one WGSL binding and array index: a texture,
/// whole for an SRV or one mip for a UAV, or a buffer range.
#[derive(Debug, PartialEq)]
struct JobBinding {
    binding: u32,
    array_index: u32,
    object: Object,
    /// The UAV mip of a texture.
    mip: Option<u32>,
    offset: u64,
    size: Option<u64>,
}

/// A job's constant buffer in the upload buffer of `stage_constants`.
struct StagedConstants {
    /// Its WGSL binding.
    binding: u32,
    offset: u64,
    size: u64,
}

#[derive(Default)]
struct EffectContext {
    dynamic: Vec<usize>,
}

/// The wgpu `FfxInterface`. Share it with the SDK components as an
/// [`FfxInterfaceRef`] (see [`ffx_get_interface_wgpu`]).
pub struct FfxWgpuBackend {
    device: wgpu::Device,
    fp16: bool,
    /// By `FfxResourceInternal::internalIndex`; index 0 is the null resource.
    resources: Vec<Option<Resource>>,
    free_dynamic: Vec<usize>,
    handles: HashMap<usize, Handle>,
    next_handle: usize,
    external_handles: Vec<usize>,
    contexts: Vec<Option<EffectContext>>,
    /// By `FfxPipelineState::pipeline - 1`.
    pipelines: Vec<Option<Pipeline>>,
    jobs: Vec<FfxGpuJobDescription>,
    /// By `FfxCommandList - 1`.
    command_lists: Vec<Option<wgpu::CommandEncoder>>,
    grid: dispatch_grid::DispatchGrid,
    clears: HashMap<wgpu::TextureFormat, wgpu::ComputePipeline>,
    observer: Option<FfxWgpuJobObserver>,
    pass_timestamps: Option<FfxWgpuPassTimestamps>,
    /// The error of the first job that stopped `execute_gpu_jobs` since
    /// `take_job_error`, whose result the SDK's dispatch ignores.
    job_error: Option<FfxErrorCode>,
}

/// Timestamp query pairs for the compute passes `execute_gpu_jobs` begins, in
/// order from `first`; passes beyond `count` pairs are untimed. The SDK's
/// backends have no pass timing; this lets the application time its dispatch.
pub struct FfxWgpuPassTimestamps {
    pub query_set: wgpu::QuerySet,
    /// Query index of the first pass's beginning.
    pub first: u32,
    /// Pairs available.
    pub count: u32,
    /// Pairs written so far.
    pub used: std::cell::Cell<u32>,
}

/// Whether wgpu rejected an object created inside `scope`, which a job then
/// must not record (SDK-P28): wgpu reports a rejected object at once but the
/// error of recording it only at the encoder's `finish`, where it invalidates
/// the caller's whole encoder. Native wgpu resolves the pop at once; WebGPU
/// resolves it later, so there this sees nothing and the error stays
/// deferred to `finish`.
fn rejected(scope: wgpu::ErrorScopeGuard) -> bool {
    let mut future = std::pin::pin!(scope.pop());
    matches!(
        future
            .as_mut()
            .poll(&mut std::task::Context::from_waker(std::task::Waker::noop())),
        std::task::Poll::Ready(Some(_))
    )
}

/// `ffxGetInterfaceDX12` for wgpu: a backend for `device`, and the same
/// backend as the components' `backendInterface`. Keep the concrete reference
/// for the command-list and resource functions.
pub fn ffx_get_interface_wgpu(
    device: &wgpu::Device,
) -> (Rc<RefCell<FfxWgpuBackend>>, FfxInterfaceRef) {
    let backend = Rc::new(RefCell::new(FfxWgpuBackend::new(device)));
    let interface: FfxInterfaceRef = backend.clone();
    (backend, interface)
}

impl FfxWgpuBackend {
    /// A backend for `device`, which must have [`required_features`].
    pub fn new(device: &wgpu::Device) -> Self {
        Self {
            device: device.clone(),
            fp16: device.features().contains(wgpu::Features::SHADER_F16),
            resources: vec![None],
            free_dynamic: Vec::new(),
            handles: HashMap::new(),
            next_handle: 1,
            external_handles: Vec::new(),
            contexts: Vec::new(),
            pipelines: Vec::new(),
            jobs: Vec::new(),
            command_lists: Vec::new(),
            grid: dispatch_grid::DispatchGrid::new(device),
            clears: HashMap::new(),
            observer: None,
            pass_timestamps: None,
            job_error: None,
        }
    }

    /// Report `fp16Supported` as `enabled` (and the device has `SHADER_F16`),
    /// as a device without 16-bit shader support would. Contexts created
    /// afterwards select FP32 permutations when `false`.
    pub fn set_fp16_supported(&mut self, enabled: bool) {
        self.fp16 = enabled && self.device.features().contains(wgpu::Features::SHADER_F16);
    }

    /// `ffxGetCommandListDX12`: moves `encoder` into the backend and returns
    /// the `FfxCommandList` that dispatch descriptions carry.
    pub fn ffx_get_command_list_wgpu(&mut self, encoder: wgpu::CommandEncoder) -> FfxCommandList {
        if let Some(index) = self.command_lists.iter().position(Option::is_none) {
            self.command_lists[index] = Some(encoder);
            index + 1
        } else {
            self.command_lists.push(Some(encoder));
            self.command_lists.len()
        }
    }

    /// Returns the encoder of `command_list`, with every executed job recorded,
    /// and releases the handles of [`Self::ffx_get_resource_wgpu`].
    pub fn ffx_take_command_list_wgpu(
        &mut self,
        command_list: FfxCommandList,
    ) -> Option<wgpu::CommandEncoder> {
        for handle in self.external_handles.drain(..) {
            self.handles.remove(&handle);
        }
        self.command_lists
            .get_mut(command_list.checked_sub(1)?)
            .and_then(Option::take)
    }

    /// `ffxGetResourceDX12`: an `FfxResource` for a caller texture, described
    /// by [`ffx_get_resource_description_wgpu`]. Valid until the next
    /// [`Self::ffx_take_command_list_wgpu`]. Each pass views the texture as its
    /// binding declares, e.g. as a cube for the environment map. Captures and
    /// copy sources need `COPY_SRC`; the output needs `COPY_DST`.
    pub fn ffx_get_resource_wgpu(
        &mut self,
        texture: &wgpu::Texture,
        name: &str,
        state: FfxResourceStates,
    ) -> FfxResource {
        let description = ffx_get_resource_description_wgpu(texture);
        let handle = self.insert_handle(Handle {
            object: Object::Texture(texture.clone()),
            description,
            name: name.to_owned(),
        });
        self.external_handles.push(handle);
        FfxResource {
            resource: handle,
            description,
            state,
            name: name.to_owned(),
        }
    }

    /// The error of the first job that stopped `execute_gpu_jobs` since the
    /// last call, if any. A failed job stops before its dispatch, clear or
    /// copy, and the jobs after it are not executed, so the encoder stays
    /// valid, holding the jobs before it; a job whose views or bind group wgpu
    /// rejects fails with `FFX_ERROR_BACKEND_API_ERROR` (SDK-P28). The SDK's dispatch (for
    /// example `ffxFsr2ContextDispatch`) ignores `fpExecuteGpuJobs`'s result,
    /// so check this after taking the command list back: the effect's output
    /// is undefined for the frame.
    pub fn take_job_error(&mut self) -> Option<FfxErrorCode> {
        self.job_error.take()
    }

    /// Observe every job that `execute_gpu_jobs` records, or stop with `None`.
    pub fn set_job_observer(&mut self, observer: Option<FfxWgpuJobObserver>) {
        self.observer = observer;
    }

    /// Time the compute passes that later dispatches record, or stop with
    /// `None`; returns the previous pool with its `used` count.
    pub fn set_pass_timestamps(
        &mut self,
        timestamps: Option<FfxWgpuPassTimestamps>,
    ) -> Option<FfxWgpuPassTimestamps> {
        std::mem::replace(&mut self.pass_timestamps, timestamps)
    }

    fn timestamp_writes(&self) -> Option<wgpu::ComputePassTimestampWrites<'_>> {
        let pool = self.pass_timestamps.as_ref()?;
        let used = pool.used.get();
        (used < pool.count).then(|| {
            pool.used.set(used + 1);
            let index = pool.first + used * 2;
            wgpu::ComputePassTimestampWrites {
                query_set: &pool.query_set,
                beginning_of_pass_write_index: Some(index),
                end_of_pass_write_index: Some(index + 1),
            }
        })
    }

    fn insert_handle(&mut self, handle: Handle) -> usize {
        let id = self.next_handle;
        self.next_handle += 1;
        self.handles.insert(id, handle);
        id
    }

    fn resource(&self, resource: FfxResourceInternal) -> Result<&Resource, FfxErrorCode> {
        usize::try_from(resource.internal_index)
            .ok()
            .and_then(|index| self.resources.get(index))
            .and_then(Option::as_ref)
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)
    }

    fn insert_static(&mut self, resource: Resource) -> FfxResourceInternal {
        self.resources.push(Some(resource));
        FfxResourceInternal {
            internal_index: i32::try_from(self.resources.len() - 1).unwrap(),
        }
    }

    fn texture(&self, resource: FfxResourceInternal) -> Result<&wgpu::Texture, FfxErrorCode> {
        match &self.resource(resource)?.handle.object {
            Object::Texture(texture) => Ok(texture),
            Object::Buffer(_) => Err(FFX_ERROR_INVALID_ARGUMENT),
        }
    }

    fn pipeline(&self, state: &FfxPipelineState) -> Result<&Pipeline, FfxErrorCode> {
        state
            .pipeline
            .checked_sub(1)
            .and_then(|index| self.pipelines.get(index))
            .and_then(Option::as_ref)
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)
    }

    fn clear_pipeline(
        &mut self,
        format: wgpu::TextureFormat,
    ) -> Result<wgpu::ComputePipeline, FfxErrorCode> {
        if let Some(pipeline) = self.clears.get(&format) {
            return Ok(pipeline.clone());
        }
        let storage = storage_format_name(format).ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
        let module = self
            .device
            .create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("FFX_GPU_JOB_CLEAR_FLOAT"),
                source: wgpu::ShaderSource::Wgsl(
                    format!(
                        "@group(0) @binding(0) var cleared: texture_storage_2d<{storage}, write>;
@group(0) @binding(1) var<uniform> color: vec4<f32>;
@compute @workgroup_size(8, 8) fn main(@builtin(global_invocation_id) id: vec3<u32>) {{
    let size = textureDimensions(cleared);
    if (id.x < size.x && id.y < size.y) {{ textureStore(cleared, id.xy, color); }}
}}"
                    )
                    .into(),
                ),
            });
        let pipeline = self
            .device
            .create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
                label: Some("FFX_GPU_JOB_CLEAR_FLOAT"),
                layout: None,
                module: &module,
                entry_point: Some("main"),
                compilation_options: wgpu::PipelineCompilationOptions::default(),
                cache: None,
            });
        self.clears.insert(format, pipeline.clone());
        Ok(pipeline)
    }

    /// `ClearUnorderedAccessViewFloat` on the target's UAV (mip 0), as a
    /// storage write of `color`.
    fn execute_clear(
        &mut self,
        encoder: &mut wgpu::CommandEncoder,
        clear: &FfxClearFloatJobDescription,
    ) -> Result<(), FfxErrorCode> {
        if let Object::Buffer(buffer) = &self.resource(clear.target)?.handle.object {
            // A texture backed by a buffer (`back_buffer_bindings`): zero is
            // zero in every format; other colours would need the format's
            // conversion, which no SDK recipe clears such a texture with.
            if clear.color != [0.0; 4] {
                return Err(FFX_ERROR_INVALID_ARGUMENT);
            }
            encoder.clear_buffer(buffer, 0, None);
            return Ok(());
        }
        let texture = self.texture(clear.target)?.clone();
        let pipeline = self.clear_pipeline(texture.format())?;
        let scope = self.device.push_error_scope(wgpu::ErrorFilter::Validation);
        let view = texture.create_view(&wgpu::TextureViewDescriptor {
            dimension: Some(wgpu::TextureViewDimension::D2),
            mip_level_count: Some(1),
            array_layer_count: Some(1),
            ..Default::default()
        });
        let color = self
            .device
            .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                label: Some("FfxClearFloatJobDescription::color"),
                contents: bytemuck::cast_slice(&clear.color),
                usage: wgpu::BufferUsages::UNIFORM,
            });
        let group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("FFX_GPU_JOB_CLEAR_FLOAT"),
            layout: &pipeline.get_bind_group_layout(0),
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(&view),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: color.as_entire_binding(),
                },
            ],
        });
        if rejected(scope) {
            return Err(FFX_ERROR_BACKEND_API_ERROR);
        }
        let mut pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
            label: Some("FFX_GPU_JOB_CLEAR_FLOAT"),
            timestamp_writes: self.timestamp_writes(),
        });
        pass.set_pipeline(&pipeline);
        pass.set_bind_group(0, &group, &[]);
        pass.dispatch_workgroups(texture.width().div_ceil(8), texture.height().div_ceil(8), 1);
        Ok(())
    }

    fn execute_copy(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        copy: &FfxCopyJobDescription,
    ) -> Result<(), FfxErrorCode> {
        let src = self.resource(copy.src)?;
        let dst = self.resource(copy.dst)?;
        match (&src.handle.object, &dst.handle.object) {
            (Object::Buffer(from), Object::Buffer(to)) => {
                let size = if copy.size == 0 {
                    from.size() - u64::from(copy.src_offset)
                } else {
                    u64::from(copy.size)
                };
                encoder.copy_buffer_to_buffer(
                    from,
                    u64::from(copy.src_offset),
                    to,
                    u64::from(copy.dst_offset),
                    size,
                );
            }
            (Object::Buffer(from), Object::Texture(to)) => {
                let row_pitch = src.upload_row_pitch.ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
                encoder.copy_buffer_to_texture(
                    wgpu::TexelCopyBufferInfo {
                        buffer: from,
                        layout: wgpu::TexelCopyBufferLayout {
                            offset: u64::from(copy.src_offset),
                            bytes_per_row: Some(row_pitch),
                            rows_per_image: Some(to.height()),
                        },
                    },
                    to.as_image_copy(),
                    to.size(),
                );
            }
            (Object::Texture(from), Object::Texture(to)) => {
                // The whole source subresource, which may be smaller than the
                // destination (SDK-P8).
                encoder.copy_texture_to_texture(
                    from.as_image_copy(),
                    to.as_image_copy(),
                    wgpu::Extent3d {
                        width: from.width(),
                        height: from.height(),
                        depth_or_array_layers: from.depth_or_array_layers(),
                    },
                );
            }
            (Object::Texture(_), Object::Buffer(_)) => return Err(FFX_ERROR_INVALID_ARGUMENT),
        }
        Ok(())
    }

    /// What `job` binds, in its pipeline's binding order.
    fn job_bindings(
        &self,
        pipeline: &Pipeline,
        job: &FfxComputeJobDescription,
    ) -> Result<Vec<JobBinding>, FfxErrorCode> {
        let state = &job.pipeline;
        let mut bindings = Vec::new();
        let mut bind = |binding: u32, array_index, object, mip, offset, size| {
            bindings.push(JobBinding {
                binding,
                array_index,
                object,
                mip,
                offset,
                size,
            });
        };
        for (binding, srv) in state.srv_texture_bindings.iter().zip(&job.srv_textures) {
            let texture = Object::Texture(self.texture(srv.resource)?.clone());
            let wgsl = FFX_WGSL_BINDING_OFFSET_SRV + binding.slot_index;
            bind(wgsl, binding.array_index, texture, None, 0, None);
        }
        for (binding, uav) in state.uav_texture_bindings.iter().zip(&job.uav_textures) {
            let wgsl = FFX_WGSL_BINDING_OFFSET_UAV + binding.slot_index;
            let entry = pipeline
                .entries
                .get(&wgsl)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
            let object = self.resource(uav.resource)?.handle.object.clone();
            // A texture the pipeline binds as a buffer was converted by
            // `back_buffer_bindings` before the job.
            let as_buffer = matches!(entry.ty, wgpu::BindingType::Buffer { .. });
            let mip = match (&object, as_buffer) {
                (Object::Buffer(_), true) => None,
                (Object::Texture(_), false) => Some(object.uav_mip(uav.mip)),
                _ => return Err(FFX_ERROR_INVALID_ARGUMENT),
            };
            bind(wgsl, binding.array_index, object, mip, 0, None);
        }
        let srv_buffers = state.srv_buffer_bindings.iter().zip(
            job.srv_buffers
                .iter()
                .map(|b| (b.resource, b.offset, b.size)),
        );
        let uav_buffers = state.uav_buffer_bindings.iter().zip(
            job.uav_buffers
                .iter()
                .map(|b| (b.resource, b.offset, b.size)),
        );
        for (offset, (binding, (resource, start, size))) in srv_buffers
            .map(|b| (FFX_WGSL_BINDING_OFFSET_SRV, b))
            .chain(uav_buffers.map(|b| (FFX_WGSL_BINDING_OFFSET_UAV, b)))
        {
            let object = self.resource(resource)?.handle.object.clone();
            if !matches!(object, Object::Buffer(_)) {
                return Err(FFX_ERROR_INVALID_ARGUMENT);
            }
            bind(
                offset + binding.slot_index,
                binding.array_index,
                object,
                None,
                u64::from(start),
                (size != 0).then_some(u64::from(size)),
            );
        }
        Ok(bindings)
    }

    /// A group of `pipeline` binding `bindings`, its constant buffers and its
    /// samplers.
    fn bind_group(
        &self,
        pipeline: &Pipeline,
        label: &str,
        bindings: &[JobBinding],
    ) -> Result<wgpu::BindGroup, FfxErrorCode> {
        let entry = |binding: u32| {
            pipeline
                .entries
                .get(&binding)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)
        };
        // Texture views by WGSL binding and array index, and buffers by WGSL
        // binding: SRV/UAV buffer ranges, textures backed by buffers and the
        // constants.
        let mut views: Vec<(u32, Vec<Option<wgpu::TextureView>>)> = Vec::new();
        let mut buffers: Vec<(u32, &wgpu::Buffer, u64, Option<u64>)> = Vec::new();
        for b in bindings {
            let texture = match &b.object {
                Object::Buffer(buffer) => {
                    buffers.push((b.binding, buffer, b.offset, b.size));
                    continue;
                }
                Object::Texture(texture) => texture,
            };
            let view = if let Some(mip) = b.mip {
                texture.create_view(&wgpu::TextureViewDescriptor {
                    dimension: Some(wgpu::TextureViewDimension::D2),
                    base_mip_level: mip,
                    mip_level_count: Some(1),
                    array_layer_count: Some(1),
                    ..Default::default()
                })
            } else {
                let wgpu::BindingType::Texture { view_dimension, .. } = entry(b.binding)?.ty else {
                    return Err(FFX_ERROR_INVALID_ARGUMENT);
                };
                texture.create_view(&wgpu::TextureViewDescriptor {
                    dimension: Some(view_dimension),
                    aspect: if texture.format().is_depth_stencil_format() {
                        wgpu::TextureAspect::DepthOnly
                    } else {
                        wgpu::TextureAspect::All
                    },
                    ..Default::default()
                })
            };
            let count = entry(b.binding)?.count.map_or(1, NonZeroU32::get) as usize;
            let index = if let Some(index) = views.iter().position(|(w, _)| *w == b.binding) {
                index
            } else {
                views.push((b.binding, vec![None; count]));
                views.len() - 1
            };
            *views[index]
                .1
                .get_mut(b.array_index as usize)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)? = Some(view);
        }
        let views = views
            .into_iter()
            .map(|(binding, views)| {
                let views: Option<Vec<_>> = views.into_iter().collect();
                views
                    .map(|views| (binding, views))
                    .ok_or(FFX_ERROR_INVALID_ARGUMENT)
            })
            .collect::<Result<Vec<_>, _>>()?;
        let view_refs: Vec<(u32, Vec<&wgpu::TextureView>)> = views
            .iter()
            .map(|(binding, views)| (*binding, views.iter().collect()))
            .collect();
        for (binding, buffer) in &pipeline.constants {
            buffers.push((*binding, buffer, 0, None));
        }

        let mut entries: Vec<wgpu::BindGroupEntry> = Vec::new();
        for (binding, views) in &view_refs {
            entries.push(wgpu::BindGroupEntry {
                binding: *binding,
                resource: if entry(*binding)?.count.is_some() {
                    wgpu::BindingResource::TextureViewArray(views)
                } else {
                    wgpu::BindingResource::TextureView(views[0])
                },
            });
        }
        for (binding, buffer, offset, size) in buffers {
            entries.push(wgpu::BindGroupEntry {
                binding,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding {
                    buffer,
                    offset,
                    size: size.and_then(std::num::NonZeroU64::new),
                }),
            });
        }
        for (binding, sampler) in &pipeline.samplers {
            entries.push(wgpu::BindGroupEntry {
                binding: *binding,
                resource: wgpu::BindingResource::Sampler(sampler),
            });
        }
        Ok(self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some(label),
            layout: &pipeline.layout,
            entries: &entries,
        }))
    }

    /// Every compute job's constant buffers in one upload buffer, as the
    /// SDK's DX12 backend copies them into its upload ring
    /// (`FallbackConstantAllocator` in `ffx_dx12.cpp`): each zero-padded or
    /// cut to its WGSL struct, which the shader reads no further than. Per
    /// job, each constant buffer's WGSL binding, offset and size; a job whose
    /// pipeline is invalid stages nothing and fails when it executes.
    fn stage_constants(
        &self,
        jobs: &[FfxGpuJobDescription],
    ) -> (Option<wgpu::Buffer>, Vec<Vec<StagedConstants>>) {
        let mut words: Vec<u32> = Vec::new();
        let mut ranges = Vec::with_capacity(jobs.len());
        for job in jobs {
            let mut job_ranges = Vec::new();
            if let FfxGpuJobDescriptor::Compute(compute) = &job.descriptor
                && let Ok(pipeline) = self.pipeline(&compute.pipeline)
            {
                let cbs = compute.pipeline.constant_buffer_bindings.iter();
                for (binding, cb) in cbs.zip(&compute.cbs) {
                    let wgsl = FFX_WGSL_BINDING_OFFSET_CBV + binding.slot_index;
                    let Some(size) = pipeline.constant_sizes.get(&wgsl) else {
                        continue;
                    };
                    let start = words.len();
                    words.extend_from_slice(&cb.data[..cb.num_32bit_entries as usize]);
                    words.resize(start + size.div_ceil(4) as usize, 0);
                    job_ranges.push(StagedConstants {
                        binding: wgsl,
                        offset: start as u64 * 4,
                        size: (words.len() - start) as u64 * 4,
                    });
                }
            }
            ranges.push(job_ranges);
        }
        let upload = (!words.is_empty()).then(|| {
            self.device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("FfxConstantBuffer upload"),
                    contents: bytemuck::cast_slice(&words),
                    usage: wgpu::BufferUsages::COPY_SRC,
                })
        });
        (upload, ranges)
    }

    /// Records `job` with the constants `stage_constants` staged for it in
    /// `upload`. Its pipeline keeps the group it binds while later jobs bind
    /// the same resources (`Pipeline::groups`).
    fn execute_compute(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        job: &FfxComputeJobDescription,
        upload: Option<&wgpu::Buffer>,
        constants: &[StagedConstants],
    ) -> Result<(), FfxErrorCode> {
        let pipeline = self.pipeline(&job.pipeline)?;
        let state = &job.pipeline;
        let bindings = self.job_bindings(pipeline, job)?;
        let group = {
            let mut groups = pipeline.groups.borrow_mut();
            if let Some(index) = groups.iter().position(|(bound, _)| *bound == bindings) {
                let kept = groups.remove(index);
                groups.insert(0, kept);
            } else {
                let scope = self.device.push_error_scope(wgpu::ErrorFilter::Validation);
                let group = self.bind_group(pipeline, &state.name, &bindings)?;
                if rejected(scope) {
                    return Err(FFX_ERROR_BACKEND_API_ERROR);
                }
                groups.insert(0, (bindings, group));
                groups.truncate(KEPT_GROUPS);
            }
            groups[0].1.clone()
        };
        for binding in &state.constant_buffer_bindings {
            let wgsl = FFX_WGSL_BINDING_OFFSET_CBV + binding.slot_index;
            let staged = constants
                .iter()
                .find(|staged| staged.binding == wgsl)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
            let (_, buffer) = pipeline
                .constants
                .iter()
                .find(|(constant, _)| *constant == wgsl)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
            let upload = upload.ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
            encoder.copy_buffer_to_buffer(upload, staged.offset, buffer, 0, staged.size);
        }

        if let Some(grid_group) = &pipeline.grid_group {
            let Object::Buffer(arguments) = &self.resource(job.cmd_argument)?.handle.object else {
                return Err(FFX_ERROR_INVALID_ARGUMENT);
            };
            self.grid
                .prepare(&self.device, encoder, arguments, job.cmd_argument_offset);
            let mut pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some(&state.name),
                timestamp_writes: self.timestamp_writes(),
            });
            pass.set_pipeline(&pipeline.pipeline);
            pass.set_bind_group(0, &group, &[]);
            pass.set_bind_group(1, grid_group, &[]);
            pass.dispatch_workgroups_indirect(&self.grid.arguments, 0);
        } else {
            let mut pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some(&state.name),
                timestamp_writes: self.timestamp_writes(),
            });
            pass.set_pipeline(&pipeline.pipeline);
            pass.set_bind_group(0, &group, &[]);
            let [x, y, z] = job.dimensions;
            pass.dispatch_workgroups(x, y, z);
        }
        Ok(())
    }

    /// Back each texture that `job`'s pipeline binds as a storage buffer
    /// with a buffer of its texels, from the first such job on.
    ///
    /// FSR2 creates `FSR2_SpdAtomicCounter` as a 1x1 `R32_UINT` UAV texture
    /// (`ffx_fsr2.cpp:702-711`), whose `InterlockedAdd` returns the previous
    /// value (`ffx_fsr2_callbacks_hlsl.h:949`); WGSL texture atomics return
    /// nothing, so the port binds it as a storage buffer. The texture's
    /// contents so far (its initial data, clears) are copied into the buffer,
    /// which then replaces it. Only a single-row texture the effect created
    /// can be converted: its texels are the buffer's layout.
    fn back_buffer_bindings(
        &mut self,
        encoder: &mut wgpu::CommandEncoder,
        job: &FfxComputeJobDescription,
    ) -> Result<(), FfxErrorCode> {
        let pipeline = self.pipeline(&job.pipeline)?;
        let resources: Vec<FfxResourceInternal> = job
            .pipeline
            .uav_texture_bindings
            .iter()
            .zip(&job.uav_textures)
            .filter(|(binding, _)| {
                pipeline
                    .entries
                    .get(&(FFX_WGSL_BINDING_OFFSET_UAV + binding.slot_index))
                    .is_some_and(|e| matches!(e.ty, wgpu::BindingType::Buffer { .. }))
            })
            .map(|(_, uav)| uav.resource)
            .collect();
        for resource in resources {
            let device = self.device.clone();
            let r = usize::try_from(resource.internal_index)
                .ok()
                .and_then(|index| self.resources.get_mut(index))
                .and_then(Option::as_mut)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
            let Object::Texture(texture) = &r.handle.object else {
                continue;
            };
            if r.dynamic
                || texture.height() != 1
                || texture.mip_level_count() != 1
                || texture.depth_or_array_layers() != 1
            {
                return Err(FFX_ERROR_INVALID_ARGUMENT);
            }
            let block = texture
                .format()
                .block_copy_size(None)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
            let size = u64::from(texture.width() * block).next_multiple_of(4);
            let buffer = device.create_buffer(&wgpu::BufferDescriptor {
                label: Some(&r.handle.name),
                size,
                usage: wgpu::BufferUsages::STORAGE
                    | wgpu::BufferUsages::COPY_SRC
                    | wgpu::BufferUsages::COPY_DST,
                mapped_at_creation: false,
            });
            encoder.copy_texture_to_buffer(
                texture.as_image_copy(),
                wgpu::TexelCopyBufferInfo {
                    buffer: &buffer,
                    layout: wgpu::TexelCopyBufferLayout::default(),
                },
                texture.size(),
            );
            r.handle.object = Object::Buffer(buffer);
            r.bytes = size;
            let (handle_id, object) = (r.handle_id, r.handle.object.clone());
            if let Some(handle) = self.handles.get_mut(&handle_id) {
                handle.object = object;
            }
        }
        Ok(())
    }

    fn observed_resources<'a>(
        &'a self,
        job: &'a FfxGpuJobDescription,
    ) -> Vec<FfxWgpuObservedResource<'a>> {
        let mut out = Vec::new();
        let mut add = |binding: &'a str, resource: FfxResourceInternal, mip: u32, writable| {
            if let Ok(r) = self.resource(resource) {
                out.push(FfxWgpuObservedResource {
                    binding,
                    name: &r.handle.name,
                    description: r.handle.description,
                    object: r.handle.object.observed(),
                    mip: r.handle.object.uav_mip(mip),
                    writable,
                });
            }
        };
        match &job.descriptor {
            FfxGpuJobDescriptor::ClearFloat(clear) => add("target", clear.target, 0, true),
            FfxGpuJobDescriptor::Copy(copy) => {
                add("src", copy.src, 0, false);
                add("dst", copy.dst, 0, true);
            }
            FfxGpuJobDescriptor::Compute(compute) => {
                let state = &compute.pipeline;
                for (b, r) in state.srv_texture_bindings.iter().zip(&compute.srv_textures) {
                    add(&b.name, r.resource, 0, false);
                }
                for (b, r) in state.uav_texture_bindings.iter().zip(&compute.uav_textures) {
                    add(&b.name, r.resource, r.mip, true);
                }
                for (b, r) in state.srv_buffer_bindings.iter().zip(&compute.srv_buffers) {
                    add(&b.name, r.resource, 0, false);
                }
                for (b, r) in state.uav_buffer_bindings.iter().zip(&compute.uav_buffers) {
                    add(&b.name, r.resource, 0, true);
                }
                if state.cmd_signature != 0 {
                    add("cmdArgument", compute.cmd_argument, 0, false);
                }
            }
        }
        out
    }

    fn observe(
        &self,
        observer: &mut Option<FfxWgpuJobObserver>,
        encoder: &mut wgpu::CommandEncoder,
        job: &FfxGpuJobDescription,
        after: bool,
    ) {
        let Some(observer) = observer else {
            return;
        };
        let pass = match &job.descriptor {
            FfxGpuJobDescriptor::Compute(compute) => self
                .pipeline(&compute.pipeline)
                .ok()
                .map(|p| (p.effect, p.pass)),
            _ => None,
        };
        observer(&mut FfxWgpuJobObservation {
            device: &self.device,
            encoder,
            job,
            pass,
            after,
            resources: self.observed_resources(job),
        });
    }
}

impl FfxInterface for FfxWgpuBackend {
    fn device(&self) -> FfxDevice {
        1
    }

    fn get_sdk_version(&mut self) -> FfxVersionNumber {
        ffx_sdk_make_version(
            FFX_SDK_VERSION_MAJOR,
            FFX_SDK_VERSION_MINOR,
            FFX_SDK_VERSION_PATCH,
        )
    }

    fn get_effect_gpu_memory_usage(
        &mut self,
        effect_context_id: u32,
    ) -> Result<FfxEffectMemoryUsage, FfxErrorCode> {
        let mut usage = FfxEffectMemoryUsage::default();
        for resource in self.resources.iter().flatten() {
            if resource.effect_context_id == effect_context_id && !resource.dynamic {
                usage.total_usage_in_bytes += resource.bytes;
                if resource.handle.description.flags & FFX_RESOURCE_FLAGS_ALIASABLE != 0 {
                    usage.aliasable_usage_in_bytes += resource.bytes;
                }
            }
        }
        Ok(usage)
    }

    fn create_backend_context(
        &mut self,
        _effect: FfxEffect,
        _bindless_config: Option<&FfxEffectBindlessConfig>,
    ) -> Result<u32, FfxErrorCode> {
        let index = if let Some(index) = self.contexts.iter().position(Option::is_none) {
            self.contexts[index] = Some(EffectContext::default());
            index
        } else {
            self.contexts.push(Some(EffectContext::default()));
            self.contexts.len() - 1
        };
        u32::try_from(index).map_err(|_| FFX_ERROR_OUT_OF_RANGE)
    }

    fn get_device_capabilities(&mut self) -> Result<FfxDeviceCapabilities, FfxErrorCode> {
        let info = self.device.adapter_info();
        Ok(FfxDeviceCapabilities {
            // SDK-P6: wgpu cannot force a subgroup size, so do not report the
            // SM6.6 with which the SDK selects wave64 permutations.
            maximum_supported_shader_model: FfxShaderModel::ShaderModel6_2,
            wave_lane_count_min: info.subgroup_min_size,
            wave_lane_count_max: info.subgroup_max_size,
            fp16_supported: self.fp16,
            ..Default::default()
        })
    }

    fn destroy_backend_context(&mut self, effect_context_id: u32) -> Result<(), FfxErrorCode> {
        let context = self
            .contexts
            .get_mut(effect_context_id as usize)
            .and_then(Option::take)
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
        for index in context.dynamic {
            self.resources[index] = None;
            self.free_dynamic.push(index);
        }
        // Resources the effect did not destroy.
        for slot in &mut self.resources {
            if slot
                .as_ref()
                .is_some_and(|r| r.effect_context_id == effect_context_id)
                && let Some(resource) = slot.take()
            {
                self.handles.remove(&resource.handle_id);
            }
        }
        Ok(())
    }

    fn create_resource(
        &mut self,
        create_resource_description: &FfxCreateResourceDescription,
        effect_context_id: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode> {
        let d = create_resource_description;
        let description = d.resource_description;
        let (object, bytes) = create_object(&self.device, d)?;
        let handle = Handle {
            object,
            description,
            name: d.name.to_owned(),
        };
        let handle_id = self.insert_handle(handle.clone());
        let resource = self.insert_static(Resource {
            handle,
            state: d.initial_state,
            effect_context_id,
            dynamic: false,
            handle_id,
            upload_row_pitch: None,
            bytes,
        });

        // Initial data: an upload resource at the next index (which
        // ffxSafeReleaseCopyResource releases) and a scheduled copy job.
        let init = d.init_data;
        let data = match init.r#type {
            FfxResourceInitDataType::Buffer => init.buffer[..init.size].to_vec(),
            FfxResourceInitDataType::Value => vec![init.value; init.size],
            FfxResourceInitDataType::Invalid | FfxResourceInitDataType::Uninitialized => {
                return Ok(resource);
            }
        };
        let (contents, row_pitch) = match &self.resource(resource)?.handle.object {
            Object::Buffer(buffer) => {
                let mut contents = data;
                contents.resize(usize::try_from(buffer.size()).unwrap(), 0);
                (contents, None)
            }
            Object::Texture(texture) => {
                // An R32G32_FLOAT UAV's texels gain zero .zw (`storage_texture_format`).
                let data = if texture.format() == wgpu::TextureFormat::Rgba32Float
                    && description.format == FfxSurfaceFormat::R32G32Float
                {
                    data.chunks(8)
                        .flat_map(|texel| texel.iter().copied().chain([0; 8]))
                        .collect()
                } else {
                    data
                };
                let block = texture.format().block_copy_size(None).unwrap_or(0);
                let row = (texture.width() * block) as usize;
                let pitch =
                    (texture.width() * block).next_multiple_of(wgpu::COPY_BYTES_PER_ROW_ALIGNMENT);
                let rows = (texture.height() * texture.depth_or_array_layers()) as usize;
                let mut contents = vec![0; pitch as usize * rows];
                for (y, source) in data.chunks(row).take(rows).enumerate() {
                    let start = y * pitch as usize;
                    contents[start..start + source.len()].copy_from_slice(source);
                }
                (contents, Some(pitch))
            }
        };
        let name = format!("{} upload", d.name);
        let upload = self
            .device
            .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                label: Some(&name),
                contents: &contents,
                usage: wgpu::BufferUsages::COPY_SRC,
            });
        let upload = Handle {
            object: Object::Buffer(upload),
            description,
            name,
        };
        let upload_handle_id = self.insert_handle(upload.clone());
        let src = self.insert_static(Resource {
            handle: upload,
            state: FFX_RESOURCE_STATE_COPY_SRC,
            effect_context_id,
            dynamic: false,
            handle_id: upload_handle_id,
            upload_row_pitch: row_pitch,
            bytes: contents.len() as u64,
        });
        self.schedule_gpu_job(&FfxGpuJobDescription {
            job_label: "Resource initialization".into(),
            descriptor: FfxGpuJobDescriptor::Copy(FfxCopyJobDescription {
                src,
                src_offset: 0,
                dst: resource,
                dst_offset: 0,
                size: 0,
            }),
        })?;
        Ok(resource)
    }

    fn register_resource(
        &mut self,
        in_resource: &FfxResource,
        effect_context_id: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode> {
        if in_resource.resource == 0 {
            return Ok(FfxResourceInternal { internal_index: 0 });
        }
        let handle = self
            .handles
            .get(&in_resource.resource)
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
        let resource = Resource {
            handle: Handle {
                object: handle.object.clone(),
                description: in_resource.description,
                name: if in_resource.name.is_empty() {
                    handle.name.clone()
                } else {
                    in_resource.name.clone()
                },
            },
            state: in_resource.state,
            effect_context_id,
            dynamic: true,
            handle_id: in_resource.resource,
            upload_row_pitch: None,
            bytes: 0,
        };
        let context = self
            .contexts
            .get_mut(effect_context_id as usize)
            .and_then(Option::as_mut)
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
        let index = if let Some(index) = self.free_dynamic.pop() {
            self.resources[index] = Some(resource);
            index
        } else {
            self.resources.push(Some(resource));
            self.resources.len() - 1
        };
        context.dynamic.push(index);
        Ok(FfxResourceInternal {
            internal_index: i32::try_from(index).map_err(|_| FFX_ERROR_OUT_OF_RANGE)?,
        })
    }

    fn get_resource(&mut self, resource: FfxResourceInternal) -> FfxResource {
        match self.resource(resource) {
            Ok(r) => FfxResource {
                resource: r.handle_id,
                description: r.handle.description,
                state: r.state,
                name: r.handle.name.clone(),
            },
            Err(_) => FfxResource::default(),
        }
    }

    fn unregister_resources(
        &mut self,
        _command_list: FfxCommandList,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        let context = self
            .contexts
            .get_mut(effect_context_id as usize)
            .and_then(Option::as_mut)
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
        for index in context.dynamic.drain(..) {
            self.resources[index] = None;
            self.free_dynamic.push(index);
        }
        Ok(())
    }

    fn get_resource_description(
        &mut self,
        resource: FfxResourceInternal,
    ) -> FfxResourceDescription {
        self.resource(resource)
            .map(|r| r.handle.description)
            .unwrap_or_default()
    }

    fn destroy_resource(
        &mut self,
        resource: FfxResourceInternal,
        _effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        if let Some(slot) = usize::try_from(resource.internal_index)
            .ok()
            .and_then(|index| self.resources.get_mut(index))
            && slot.as_ref().is_some_and(|r| !r.dynamic)
            && let Some(r) = slot.take()
        {
            self.handles.remove(&r.handle_id);
        }
        Ok(())
    }

    fn stage_constant_buffer_data_func(
        &mut self,
        data: &[u32],
        constant_buffer: &mut FfxConstantBuffer,
    ) -> Result<(), FfxErrorCode> {
        constant_buffer.data = data.to_vec();
        constant_buffer.num_32bit_entries =
            u32::try_from(data.len()).map_err(|_| FFX_ERROR_INVALID_SIZE)?;
        Ok(())
    }

    fn create_pipeline(
        &mut self,
        effect: FfxEffect,
        pass: FfxPass,
        permutation_options: u32,
        pipeline_description: &FfxPipelineDescription<'_>,
        _effect_context_id: u32,
    ) -> Result<FfxPipelineState, FfxErrorCode> {
        let blob = self.get_permutation_blob_by_index(
            effect,
            pass,
            pipeline_description.stage,
            permutation_options,
        )?;
        if blob.permutation.wave64 {
            // SDK-P6: not selected, because the backend reports SM6.2.
            return Err(FFX_ERROR_BACKEND_API_ERROR);
        }
        let source = ffx_get_wgsl_source(&blob).ok_or(FFX_ERROR_BACKEND_API_ERROR)?;
        let reflection = Reflection::new(&source)?;

        let tables: [(&[FfxShaderBlobBinding], u32); 6] = [
            (blob.bound_constant_buffers, FFX_WGSL_BINDING_OFFSET_CBV),
            (blob.bound_srv_textures, FFX_WGSL_BINDING_OFFSET_SRV),
            (blob.bound_uav_textures, FFX_WGSL_BINDING_OFFSET_UAV),
            (blob.bound_srv_buffers, FFX_WGSL_BINDING_OFFSET_SRV),
            (blob.bound_uav_buffers, FFX_WGSL_BINDING_OFFSET_UAV),
            (blob.bound_samplers, FFX_WGSL_BINDING_OFFSET_SAMPLER),
        ];
        let mut entries = HashMap::new();
        let mut constant_sizes = HashMap::new();
        for (table, offset) in tables {
            for b in table {
                let binding = offset + b.binding;
                let (ty, count, size) = reflection.binding(binding)?;
                if count.map_or(1, NonZeroU32::get) != b.count {
                    return Err(FFX_ERROR_BACKEND_API_ERROR);
                }
                if let Some(size) = size {
                    constant_sizes.insert(binding, size);
                }
                entries.insert(
                    binding,
                    wgpu::BindGroupLayoutEntry {
                        binding,
                        visibility: wgpu::ShaderStages::COMPUTE,
                        ty,
                        count,
                    },
                );
            }
        }
        let label = Some(pipeline_description.name.as_str());
        let mut layout_entries: Vec<_> = entries.values().copied().collect();
        layout_entries.sort_by_key(|e| e.binding);
        let layout = self
            .device
            .create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label,
                entries: &layout_entries,
            });
        let indirect = pipeline_description.indirect_workload != 0;
        let mut groups = vec![Some(&layout)];
        if indirect {
            groups.push(Some(&self.grid.layout));
        }
        let pipeline_layout = self
            .device
            .create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label,
                bind_group_layouts: &groups,
                immediate_size: 0,
            });
        let module = self
            .device
            .create_shader_module(wgpu::ShaderModuleDescriptor {
                label,
                source: wgpu::ShaderSource::Wgsl(
                    if indirect {
                        dispatch_grid::wgsl_entry(&source)
                    } else {
                        source
                    }
                    .into(),
                ),
            });
        let pipeline = self
            .device
            .create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
                label,
                layout: Some(&pipeline_layout),
                module: &module,
                entry_point: Some(FFX_WGSL_ENTRY_POINT),
                compilation_options: wgpu::PipelineCompilationOptions::default(),
                cache: None,
            });
        // Static samplers: register sN is the description's Nth sampler.
        let samplers = blob
            .bound_samplers
            .iter()
            .map(|b| {
                let description = pipeline_description
                    .samplers
                    .get(b.binding as usize)
                    .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
                Ok((
                    FFX_WGSL_BINDING_OFFSET_SAMPLER + b.binding,
                    self.device.create_sampler(&sampler(description)?),
                ))
            })
            .collect::<Result<Vec<_>, FfxErrorCode>>()?;
        let grid_group = indirect.then(|| {
            self.device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("SDK-P10 dispatch grid"),
                layout: &self.grid.layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: self.grid.arguments.as_entire_binding(),
                }],
            })
        });
        let constants = blob
            .bound_constant_buffers
            .iter()
            .map(|b| {
                let binding = FFX_WGSL_BINDING_OFFSET_CBV + b.binding;
                let size = constant_sizes
                    .get(&binding)
                    .ok_or(FFX_ERROR_BACKEND_API_ERROR)?;
                let buffer = self.device.create_buffer(&wgpu::BufferDescriptor {
                    label: Some(b.name),
                    size: size.div_ceil(4) * 4,
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    mapped_at_creation: false,
                });
                Ok((binding, buffer))
            })
            .collect::<Result<Vec<_>, FfxErrorCode>>()?;
        let record = Pipeline {
            effect,
            pass,
            pipeline,
            layout,
            entries,
            constant_sizes,
            constants,
            samplers,
            grid_group,
            groups: RefCell::new(Vec::new()),
        };
        let handle = if let Some(index) = self.pipelines.iter().position(Option::is_none) {
            self.pipelines[index] = Some(record);
            index + 1
        } else {
            self.pipelines.push(Some(record));
            self.pipelines.len()
        };
        // One binding per register and array index, as the DX12 backend
        // expands the blob's binding counts.
        let expand = |table: &[FfxShaderBlobBinding]| {
            table
                .iter()
                .flat_map(|b| {
                    (0..b.count).map(|array_index| FfxResourceBinding {
                        slot_index: b.binding,
                        array_index,
                        resource_identifier: 0,
                        name: b.name.into(),
                    })
                })
                .collect::<Vec<_>>()
        };
        Ok(FfxPipelineState {
            root_signature: handle,
            pass_id: pass,
            cmd_signature: if indirect { handle } else { 0 },
            pipeline: handle,
            uav_texture_bindings: expand(blob.bound_uav_textures),
            srv_texture_bindings: expand(blob.bound_srv_textures),
            srv_buffer_bindings: expand(blob.bound_srv_buffers),
            uav_buffer_bindings: expand(blob.bound_uav_buffers),
            constant_buffer_bindings: expand(blob.bound_constant_buffers),
            name: pipeline_description.name.clone(),
            ..Default::default()
        })
    }

    fn get_permutation_blob_by_index(
        &self,
        effect_id: FfxEffect,
        pass_id: FfxPass,
        bind_stage: FfxBindStage,
        permutation_options: u32,
    ) -> Result<FfxShaderBlob, FfxErrorCode> {
        ffx_get_permutation_blob_by_index(effect_id, pass_id, bind_stage, permutation_options)
    }

    fn destroy_pipeline(
        &mut self,
        pipeline: &mut FfxPipelineState,
        _effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        if let Some(slot) = pipeline
            .pipeline
            .checked_sub(1)
            .and_then(|index| self.pipelines.get_mut(index))
        {
            *slot = None;
        }
        pipeline.pipeline = 0;
        pipeline.root_signature = 0;
        pipeline.cmd_signature = 0;
        Ok(())
    }

    fn schedule_gpu_job(&mut self, job: &FfxGpuJobDescription) -> Result<(), FfxErrorCode> {
        self.jobs.push(job.clone());
        Ok(())
    }

    fn execute_gpu_jobs(
        &mut self,
        command_list: FfxCommandList,
        _effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        let slot = command_list
            .checked_sub(1)
            .filter(|index| self.command_lists.get(*index).is_some_and(Option::is_some))
            .ok_or(FFX_ERROR_INVALID_ARGUMENT)?;
        let mut encoder = self.command_lists[slot].take().unwrap();
        let mut observer = self.observer.take();
        let jobs = std::mem::take(&mut self.jobs);
        let (upload, constants) = self.stage_constants(&jobs);
        let mut result = Ok(());
        for (job, constants) in jobs.iter().zip(&constants) {
            if let FfxGpuJobDescriptor::Compute(compute) = &job.descriptor
                && let Err(error) = self.back_buffer_bindings(&mut encoder, compute)
            {
                result = Err(error);
                break;
            }
            self.observe(&mut observer, &mut encoder, job, false);
            result = match &job.descriptor {
                FfxGpuJobDescriptor::ClearFloat(clear) => self.execute_clear(&mut encoder, clear),
                FfxGpuJobDescriptor::Copy(copy) => self.execute_copy(&mut encoder, copy),
                FfxGpuJobDescriptor::Compute(compute) => {
                    self.execute_compute(&mut encoder, compute, upload.as_ref(), constants)
                }
            };
            if result.is_err() {
                break;
            }
            self.observe(&mut observer, &mut encoder, job, true);
        }
        self.observer = observer;
        self.command_lists[slot] = Some(encoder);
        if let Err(error) = result {
            self.job_error.get_or_insert(error);
        }
        result
    }
}

/// `GetFfxResourceDescriptionDX12` for a wgpu texture.
pub fn ffx_get_resource_description_wgpu(texture: &wgpu::Texture) -> FfxResourceDescription {
    let usage = texture.usage();
    let mut ffx_usage = FFX_RESOURCE_USAGE_READ_ONLY;
    if usage.contains(wgpu::TextureUsages::STORAGE_BINDING) {
        ffx_usage |= FFX_RESOURCE_USAGE_UAV;
    }
    if usage.contains(wgpu::TextureUsages::RENDER_ATTACHMENT) {
        ffx_usage |= if texture.format().is_depth_stencil_format() {
            FFX_RESOURCE_USAGE_DEPTHTARGET
        } else {
            FFX_RESOURCE_USAGE_RENDERTARGET
        };
    }
    FfxResourceDescription {
        r#type: match texture.dimension() {
            wgpu::TextureDimension::D1 => FfxResourceType::Texture1D,
            wgpu::TextureDimension::D2 => FfxResourceType::Texture2D,
            wgpu::TextureDimension::D3 => FfxResourceType::Texture3D,
        },
        format: surface_format(texture.format()),
        width: texture.width(),
        height: texture.height(),
        depth: texture.depth_or_array_layers(),
        mip_count: texture.mip_level_count(),
        flags: FFX_RESOURCE_FLAGS_NONE,
        usage: ffx_usage,
    }
}

/// The wgpu object for a resource description, and its size in bytes.
fn create_object(
    device: &wgpu::Device,
    d: &FfxCreateResourceDescription,
) -> Result<(Object, u64), FfxErrorCode> {
    let description = d.resource_description;
    if description.r#type == FfxResourceType::Buffer {
        // `width` is the buffer size; storage buffers are whole words.
        let size = u64::from(description.width.max(1)).next_multiple_of(4);
        let mut usage = wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_SRC
            | wgpu::BufferUsages::COPY_DST;
        if description.usage & FFX_RESOURCE_USAGE_INDIRECT != 0 {
            usage |= wgpu::BufferUsages::INDIRECT;
        }
        let buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some(d.name),
            size,
            usage,
            mapped_at_creation: false,
        });
        return Ok((Object::Buffer(buffer), size));
    }
    let format = storage_texture_format(&description)?;
    let (dimension, layers) = match description.r#type {
        FfxResourceType::Texture1D => (wgpu::TextureDimension::D1, 1),
        FfxResourceType::Texture2D => (wgpu::TextureDimension::D2, 1),
        FfxResourceType::TextureCube => (wgpu::TextureDimension::D2, 6),
        FfxResourceType::Texture3D => (wgpu::TextureDimension::D3, description.depth.max(1)),
        FfxResourceType::Buffer => unreachable!(),
    };
    let size = wgpu::Extent3d {
        width: description.width,
        height: description.height,
        depth_or_array_layers: layers,
    };
    let mip_level_count = if description.mip_count == 0 {
        size.max_mips(dimension)
    } else {
        description.mip_count
    };
    let mut usage = wgpu::TextureUsages::TEXTURE_BINDING
        | wgpu::TextureUsages::COPY_SRC
        | wgpu::TextureUsages::COPY_DST;
    if description.usage & FFX_RESOURCE_USAGE_UAV != 0 {
        usage |= wgpu::TextureUsages::STORAGE_BINDING;
        // The SDK's `Interlocked*` on 32-bit integer UAVs (FSR2's
        // reconstructed depth) are WGSL texture atomics, which wgpu's Metal
        // backend only performs on a texture created for them.
        if matches!(
            format,
            wgpu::TextureFormat::R32Uint | wgpu::TextureFormat::R32Sint
        ) {
            usage |= wgpu::TextureUsages::STORAGE_ATOMIC;
        }
    }
    if description.usage & (FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_DEPTHTARGET) != 0 {
        usage |= wgpu::TextureUsages::RENDER_ATTACHMENT;
    }
    let texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some(d.name),
        size,
        mip_level_count,
        sample_count: 1,
        dimension,
        format,
        usage,
        view_formats: &[],
    });
    let block = u64::from(format.block_copy_size(None).unwrap_or(0));
    let bytes = (0..mip_level_count)
        .map(|mip| {
            let level = size.mip_level_size(mip, dimension);
            u64::from(level.width)
                * u64::from(level.height)
                * u64::from(level.depth_or_array_layers)
                * block
        })
        .sum();
    Ok((Object::Texture(texture), bytes))
}

/// Binding types of the port's WGSL, reflected with naga.
struct Reflection {
    module: naga::Module,
    /// Textures that the entry point samples with a filtering sampler.
    filtered: Vec<naga::Handle<naga::GlobalVariable>>,
}

impl Reflection {
    fn new(source: &str) -> Result<Self, FfxErrorCode> {
        let module =
            naga::front::wgsl::parse_str(source).map_err(|_| FFX_ERROR_BACKEND_API_ERROR)?;
        let info = naga::valid::Validator::new(
            naga::valid::ValidationFlags::all(),
            naga::valid::Capabilities::all(),
        )
        .validate(&module)
        .map_err(|_| FFX_ERROR_BACKEND_API_ERROR)?;
        let entry = module
            .entry_points
            .iter()
            .position(|e| e.name == FFX_WGSL_ENTRY_POINT)
            .ok_or(FFX_ERROR_BACKEND_API_ERROR)?;
        let filtered = info
            .get_entry_point(entry)
            .sampling_set
            .iter()
            .filter(|key| {
                !matches!(
                    module.types[module.global_variables[key.sampler].ty].inner,
                    naga::TypeInner::Sampler { comparison: true }
                )
            })
            .map(|key| key.image)
            .collect();
        Ok(Self { module, filtered })
    }

    /// The layout type, array count and (for a uniform) size of group 0's
    /// `binding`.
    fn binding(
        &self,
        binding: u32,
    ) -> Result<(wgpu::BindingType, Option<NonZeroU32>, Option<u64>), FfxErrorCode> {
        let (handle, global) = self
            .module
            .global_variables
            .iter()
            .find(|(_, g)| {
                g.binding
                    .as_ref()
                    .is_some_and(|b| b.group == 0 && b.binding == binding)
            })
            .ok_or(FFX_ERROR_BACKEND_API_ERROR)?;
        let mut ty = &self.module.types[global.ty].inner;
        let mut count = None;
        if let naga::TypeInner::BindingArray { base, size } = ty {
            let naga::ArraySize::Constant(size) = size else {
                return Err(FFX_ERROR_BACKEND_API_ERROR);
            };
            count = Some(*size);
            ty = &self.module.types[*base].inner;
        }
        let buffer = |ty| wgpu::BindingType::Buffer {
            ty,
            has_dynamic_offset: false,
            min_binding_size: None,
        };
        let binding_type = match (global.space, ty) {
            (naga::AddressSpace::Uniform, _) => {
                let size = u64::from(ty.size(self.module.to_ctx()));
                return Ok((buffer(wgpu::BufferBindingType::Uniform), count, Some(size)));
            }
            (naga::AddressSpace::Storage { access }, _) => {
                buffer(wgpu::BufferBindingType::Storage {
                    read_only: !access.contains(naga::StorageAccess::STORE),
                })
            }
            (_, naga::TypeInner::Sampler { comparison }) => {
                wgpu::BindingType::Sampler(if *comparison {
                    wgpu::SamplerBindingType::Comparison
                } else {
                    wgpu::SamplerBindingType::Filtering
                })
            }
            (
                _,
                naga::TypeInner::Image {
                    dim,
                    arrayed,
                    class,
                },
            ) => {
                let view_dimension = match (dim, arrayed) {
                    (naga::ImageDimension::D1, _) => wgpu::TextureViewDimension::D1,
                    (naga::ImageDimension::D2, false) => wgpu::TextureViewDimension::D2,
                    (naga::ImageDimension::D2, true) => wgpu::TextureViewDimension::D2Array,
                    (naga::ImageDimension::D3, _) => wgpu::TextureViewDimension::D3,
                    (naga::ImageDimension::Cube, false) => wgpu::TextureViewDimension::Cube,
                    (naga::ImageDimension::Cube, true) => wgpu::TextureViewDimension::CubeArray,
                };
                match class {
                    naga::ImageClass::Sampled { kind, multi } => wgpu::BindingType::Texture {
                        sample_type: match kind {
                            naga::ScalarKind::Uint => wgpu::TextureSampleType::Uint,
                            naga::ScalarKind::Sint => wgpu::TextureSampleType::Sint,
                            _ => wgpu::TextureSampleType::Float {
                                filterable: self.filtered.contains(&handle),
                            },
                        },
                        view_dimension,
                        multisampled: *multi,
                    },
                    naga::ImageClass::Depth { multi } => wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Depth,
                        view_dimension,
                        multisampled: *multi,
                    },
                    naga::ImageClass::Storage { format, access } => {
                        let load = access.contains(naga::StorageAccess::LOAD);
                        let store = access.contains(naga::StorageAccess::STORE);
                        let atomic = access.contains(naga::StorageAccess::ATOMIC);
                        wgpu::BindingType::StorageTexture {
                            access: match (atomic, load, store) {
                                (true, _, _) => wgpu::StorageTextureAccess::Atomic,
                                (false, true, true) => wgpu::StorageTextureAccess::ReadWrite,
                                (false, false, true) => wgpu::StorageTextureAccess::WriteOnly,
                                _ => wgpu::StorageTextureAccess::ReadOnly,
                            },
                            format: wgpu_naga_bridge::map_storage_format_from_naga(*format),
                            view_dimension,
                        }
                    }
                    naga::ImageClass::External => return Err(FFX_ERROR_BACKEND_API_ERROR),
                }
            }
            _ => return Err(FFX_ERROR_BACKEND_API_ERROR),
        };
        Ok((binding_type, count, None))
    }
}

fn sampler(
    description: &FfxSamplerDescription,
) -> Result<wgpu::SamplerDescriptor<'static>, FfxErrorCode> {
    let address = |mode| match mode {
        FfxAddressMode::Wrap => Ok(wgpu::AddressMode::Repeat),
        FfxAddressMode::Mirror => Ok(wgpu::AddressMode::MirrorRepeat),
        FfxAddressMode::Clamp => Ok(wgpu::AddressMode::ClampToEdge),
        FfxAddressMode::Border => Ok(wgpu::AddressMode::ClampToBorder),
        FfxAddressMode::MirrorOnce => Err(FFX_ERROR_INVALID_ENUM),
    };
    let (filter, mipmap_filter) = match description.filter {
        FfxFilterType::MinMagMipPoint => {
            (wgpu::FilterMode::Nearest, wgpu::MipmapFilterMode::Nearest)
        }
        FfxFilterType::MinMagMipLinear => {
            (wgpu::FilterMode::Linear, wgpu::MipmapFilterMode::Linear)
        }
        FfxFilterType::MinMagLinearMipPoint => {
            (wgpu::FilterMode::Linear, wgpu::MipmapFilterMode::Nearest)
        }
    };
    Ok(wgpu::SamplerDescriptor {
        label: Some("FfxSamplerDescription"),
        address_mode_u: address(description.address_mode_u)?,
        address_mode_v: address(description.address_mode_v)?,
        address_mode_w: address(description.address_mode_w)?,
        mag_filter: filter,
        min_filter: filter,
        mipmap_filter,
        ..Default::default()
    })
}

/// The WGSL storage format of a clear target.
fn storage_format_name(format: wgpu::TextureFormat) -> Option<&'static str> {
    use wgpu::TextureFormat as T;
    Some(match format {
        T::Rgba32Float => "rgba32float",
        T::Rgba16Float => "rgba16float",
        T::Rg32Float => "rg32float",
        T::Rg16Float => "rg16float",
        T::R32Float => "r32float",
        T::R16Float => "r16float",
        T::Rg11b10Ufloat => "rg11b10ufloat",
        T::Rgb10a2Unorm => "rgb10a2unorm",
        T::Rgba8Unorm => "rgba8unorm",
        T::Rgba8Snorm => "rgba8snorm",
        T::Bgra8Unorm => "bgra8unorm",
        T::Rg8Unorm => "rg8unorm",
        T::R8Unorm => "r8unorm",
        T::R16Unorm => "r16unorm",
        T::R16Snorm => "r16snorm",
        _ => return None,
    })
}

/// The wgpu format of a texture the effect creates: an `R32G32_FLOAT` UAV is
/// `Rgba32Float`, whose `.xy` the port reads and writes, because Metal has no
/// read-write `Rg32Float` storage texture and FSR2 reads and writes
/// `FSR2_AutoExposure` (`ffx_fsr2_callbacks_hlsl.h:467`, `:898`, `:907`).
/// SRV readers of the texture use its `.xy` as well.
fn storage_texture_format(
    description: &FfxResourceDescription,
) -> Result<wgpu::TextureFormat, FfxErrorCode> {
    if description.format == FfxSurfaceFormat::R32G32Float
        && description.usage & FFX_RESOURCE_USAGE_UAV != 0
    {
        return Ok(wgpu::TextureFormat::Rgba32Float);
    }
    texture_format(description.format).ok_or(FFX_ERROR_INVALID_ENUM)
}

/// `FfxSurfaceFormat` to wgpu. The typeless formats and `Unknown` have no
/// wgpu equivalent.
fn texture_format(format: FfxSurfaceFormat) -> Option<wgpu::TextureFormat> {
    use FfxSurfaceFormat as F;
    use wgpu::TextureFormat as T;
    Some(match format {
        F::R32G32B32A32Uint => T::Rgba32Uint,
        F::R32G32B32A32Float => T::Rgba32Float,
        F::R16G16B16A16Float => T::Rgba16Float,
        F::R32G32Float => T::Rg32Float,
        F::R8Uint => T::R8Uint,
        F::R32Uint => T::R32Uint,
        F::R8G8B8A8Unorm => T::Rgba8Unorm,
        F::R8G8B8A8Snorm => T::Rgba8Snorm,
        F::R8G8B8A8Srgb => T::Rgba8UnormSrgb,
        F::B8G8R8A8Unorm => T::Bgra8Unorm,
        F::B8G8R8A8Srgb => T::Bgra8UnormSrgb,
        F::R11G11B10Float => T::Rg11b10Ufloat,
        F::R10G10B10A2Unorm => T::Rgb10a2Unorm,
        F::R16G16Float => T::Rg16Float,
        F::R16G16Uint => T::Rg16Uint,
        F::R16G16Sint => T::Rg16Sint,
        F::R16Float => T::R16Float,
        F::R16Uint => T::R16Uint,
        F::R16Unorm => T::R16Unorm,
        F::R16Snorm => T::R16Snorm,
        F::R8Unorm => T::R8Unorm,
        F::R8G8Unorm => T::Rg8Unorm,
        F::R8G8Uint => T::Rg8Uint,
        F::R32Float => T::R32Float,
        F::R9G9B9E5Sharedexp => T::Rgb9e5Ufloat,
        _ => return None,
    })
}

/// wgpu to `FfxSurfaceFormat`; `Unknown` where the SDK has no equivalent.
fn surface_format(format: wgpu::TextureFormat) -> FfxSurfaceFormat {
    use FfxSurfaceFormat as F;
    use wgpu::TextureFormat as T;
    match format {
        T::Rgba32Uint => F::R32G32B32A32Uint,
        T::Rgba32Float => F::R32G32B32A32Float,
        T::Rgba16Float => F::R16G16B16A16Float,
        T::Rg32Float => F::R32G32Float,
        T::R8Uint => F::R8Uint,
        T::R32Uint => F::R32Uint,
        T::Rgba8Unorm => F::R8G8B8A8Unorm,
        T::Rgba8Snorm => F::R8G8B8A8Snorm,
        T::Rgba8UnormSrgb => F::R8G8B8A8Srgb,
        T::Bgra8Unorm => F::B8G8R8A8Unorm,
        T::Bgra8UnormSrgb => F::B8G8R8A8Srgb,
        T::Rg11b10Ufloat => F::R11G11B10Float,
        T::Rgb10a2Unorm => F::R10G10B10A2Unorm,
        T::Rg16Float => F::R16G16Float,
        T::Rg16Uint => F::R16G16Uint,
        T::Rg16Sint => F::R16G16Sint,
        T::R16Float => F::R16Float,
        T::R16Uint => F::R16Uint,
        T::R16Unorm => F::R16Unorm,
        T::R16Snorm => F::R16Snorm,
        T::R8Unorm => F::R8Unorm,
        T::Rg8Unorm => F::R8G8Unorm,
        T::Rg8Uint => F::R8G8Uint,
        T::R32Float | T::Depth32Float => F::R32Float,
        T::Rgb9e5Ufloat => F::R9G9B9E5Sharedexp,
        _ => F::Unknown,
    }
}

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::*;

    /// A device with the required features, or `None` after printing why.
    /// `SP_FIDELITY_REQUIRE_GPU` turns the skip into a failure.
    pub(crate) fn device() -> Option<(wgpu::Device, wgpu::Queue)> {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
        let result = pollster::block_on(instance.request_adapter(&Default::default()))
            .map_err(|e| e.to_string())
            .and_then(|adapter| {
                pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
                    required_features: required_features(),
                    required_limits: adapter.limits(),
                    ..Default::default()
                }))
                .map_err(|e| e.to_string())
            });
        match result {
            Ok(device) => Some(device),
            Err(error) => {
                let required = std::env::var("SP_FIDELITY_REQUIRE_GPU")
                    .is_ok_and(|v| !v.is_empty() && v != "0");
                assert!(
                    !required,
                    "GPU test cannot run but SP_FIDELITY_REQUIRE_GPU is set: {error}"
                );
                eprintln!("skipping GPU test: {error}");
                None
            }
        }
    }

    #[test]
    fn clear_float_job_writes_its_color_to_each_cleared_sdk_format() {
        // Defect: a skipped, mis-targeted or format-mangled ClearFloat job. The
        // SDK clears these UAV formats; the colour is exactly representable in
        // each, and differs from wgpu's zero initialization.
        let Some((device, queue)) = device() else {
            return;
        };
        let color = [0.25f32, 0.5, 0.75, 1.];
        let (backend, _) = ffx_get_interface_wgpu(&device);
        let mut backend = backend.borrow_mut();
        let context = backend
            .create_backend_context(FfxEffect::Fsr2, None)
            .unwrap();
        let formats = [
            (FfxSurfaceFormat::R16G16B16A16Float, &color[..]),
            (FfxSurfaceFormat::R16Float, &color[..1]),
            (FfxSurfaceFormat::R11G11B10Float, &color[..3]),
        ];
        for (format, _) in formats {
            let target = backend
                .create_resource(
                    &FfxCreateResourceDescription {
                        heap_type: FfxHeapType::Default,
                        resource_description: FfxResourceDescription {
                            r#type: FfxResourceType::Texture2D,
                            format,
                            width: 13,
                            height: 9,
                            depth: 1,
                            mip_count: 1,
                            flags: FFX_RESOURCE_FLAGS_NONE,
                            usage: FFX_RESOURCE_USAGE_UAV,
                        },
                        initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                        name: "cleared",
                        id: 0,
                        init_data: FfxResourceInitData::default(),
                    },
                    context,
                )
                .unwrap();
            backend
                .schedule_gpu_job(&FfxGpuJobDescription {
                    job_label: "Zero initialize resource".into(),
                    descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                        color,
                        target,
                    }),
                })
                .unwrap();
        }
        let readbacks = Rc::new(RefCell::new(Vec::new()));
        let sink = readbacks.clone();
        backend.set_job_observer(Some(Box::new(move |o: &mut FfxWgpuJobObservation<'_>| {
            if let (true, Some(FfxWgpuObject::Texture(texture))) =
                (o.after, o.resources.first().map(|r| r.object))
            {
                sink.borrow_mut()
                    .push(readback::Readback::texture(o.device, o.encoder, texture, 0));
            }
        })));
        let command_list =
            backend.ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        backend.execute_gpu_jobs(command_list, context).unwrap();
        let encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
        queue.submit([encoder.finish()]);
        let bytes = readback::Readback::read_all(&device, readbacks.take());
        assert_eq!(bytes.len(), formats.len());
        // Unsigned small floats with a 5-bit exponent (no infinities occur).
        let small = |value: u32, mantissa_bits: u32| {
            let exponent = i32::try_from(value >> mantissa_bits).unwrap();
            let mantissa =
                (value & ((1 << mantissa_bits) - 1)) as f32 / (1 << mantissa_bits) as f32;
            if exponent == 0 {
                mantissa * 2f32.powi(-14)
            } else {
                (1. + mantissa) * 2f32.powi(exponent - 15)
            }
        };
        let half = |bits: u16| small(u32::from(bits), 10);
        for ((format, expected), texels) in formats.iter().zip(bytes) {
            let decoded: Vec<Vec<f32>> = match format {
                FfxSurfaceFormat::R11G11B10Float => texels
                    .chunks_exact(4)
                    .map(|c| {
                        let v = u32::from_le_bytes(c.try_into().unwrap());
                        vec![
                            small(v & 0x7ff, 6),
                            small(v >> 11 & 0x7ff, 6),
                            small(v >> 22, 5),
                        ]
                    })
                    .collect(),
                _ => texels
                    .chunks_exact(2 * expected.len())
                    .map(|c| {
                        c.chunks_exact(2)
                            .map(|h| half(u16::from_le_bytes([h[0], h[1]])))
                            .collect()
                    })
                    .collect(),
            };
            assert_eq!(decoded.len(), 13 * 9, "{format:?}");
            assert!(
                decoded.iter().all(|texel| texel == expected),
                "{format:?} was not cleared to {expected:?}: {:?}",
                decoded[0]
            );
        }
    }

    #[test]
    fn buffer_backing_and_rgba_allocation_keep_initial_data() {
        // Defects: a buffer backing that drops the texture's contents (the SPD
        // counter's initial data), or an R32G32_FLOAT UAV whose initial
        // texels land at RGBA32Float's stride unwidened. Expected: the bytes
        // given to create_resource, in the resources the luminance pyramid
        // binds just before it runs.
        let Some((device, queue)) = device() else {
            return;
        };
        let (backend, _) = ffx_get_interface_wgpu(&device);
        let mut backend = backend.borrow_mut();
        let context = backend
            .create_backend_context(FfxEffect::Fsr2, None)
            .unwrap();
        let counter_data = 0x0102_0304u32.to_le_bytes();
        let exposure_data: Vec<u8> = [1.5f32, -2.25, 3.0, 0.125]
            .iter()
            .flat_map(|v| v.to_le_bytes())
            .collect();
        let mut create = |name, format, width, height, mip_count, usage, init_data| {
            backend
                .create_resource(
                    &FfxCreateResourceDescription {
                        heap_type: FfxHeapType::Default,
                        resource_description: FfxResourceDescription {
                            r#type: FfxResourceType::Texture2D,
                            format,
                            width,
                            height,
                            depth: 1,
                            mip_count,
                            flags: FFX_RESOURCE_FLAGS_NONE,
                            usage,
                        },
                        initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                        name,
                        id: 0,
                        init_data,
                    },
                    context,
                )
                .unwrap()
        };
        let uninitialized = FfxResourceInitData {
            r#type: FfxResourceInitDataType::Uninitialized,
            ..Default::default()
        };
        let color = create(
            "color",
            FfxSurfaceFormat::R16G16B16A16Float,
            128,
            64,
            1,
            FFX_RESOURCE_USAGE_READ_ONLY,
            uninitialized,
        );
        let counter = create(
            "counter",
            FfxSurfaceFormat::R32Uint,
            1,
            1,
            1,
            FFX_RESOURCE_USAGE_UAV,
            FfxResourceInitData::ffx_resource_init_buffer(4, &counter_data),
        );
        let mips = create(
            "mips",
            FfxSurfaceFormat::R16Float,
            64,
            32,
            0,
            FFX_RESOURCE_USAGE_UAV,
            uninitialized,
        );
        let exposure = create(
            "exposure",
            FfxSurfaceFormat::R32G32Float,
            2,
            1,
            1,
            FFX_RESOURCE_USAGE_UAV,
            FfxResourceInitData::ffx_resource_init_buffer(16, &exposure_data),
        );
        let samplers = [
            FfxFilterType::MinMagMipPoint,
            FfxFilterType::MinMagMipLinear,
        ]
        .map(|filter| FfxSamplerDescription {
            filter,
            address_mode_u: FfxAddressMode::Clamp,
            address_mode_v: FfxAddressMode::Clamp,
            address_mode_w: FfxAddressMode::Clamp,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        });
        let root_constants = [31, 6].map(|size| FfxRootConstantDescription {
            size,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        });
        let pipeline = backend
            .create_pipeline(
                FfxEffect::Fsr2,
                sp_fidelity::fsr2::FfxFsr2Pass::ComputeLuminancePyramid as u32,
                0,
                &FfxPipelineDescription {
                    context_flags: 0,
                    samplers: &samplers,
                    root_constants: &root_constants,
                    name: "FSR2-LUM_PYRAMID".into(),
                    stage: FFX_BIND_COMPUTE_SHADER_STAGE,
                    indirect_workload: 0,
                    backbuffer_format: FfxSurfaceFormat::Unknown,
                },
                context,
            )
            .unwrap();
        let resource = |name: &str| match name {
            "r_input_color_jittered" => (color, 0),
            "rw_spd_global_atomic" => (counter, 0),
            "rw_img_mip_shading_change" => (mips, 4),
            "rw_img_mip_5" => (mips, 5),
            _ => (exposure, 0),
        };
        let compute = FfxComputeJobDescription {
            // No groups: only the bound resources matter here.
            dimensions: [0, 1, 1],
            srv_textures: pipeline
                .srv_texture_bindings
                .iter()
                .map(|b| FfxTextureSRV {
                    resource: resource(&b.name).0,
                })
                .collect(),
            uav_textures: pipeline
                .uav_texture_bindings
                .iter()
                .map(|b| FfxTextureUAV {
                    resource: resource(&b.name).0,
                    mip: resource(&b.name).1,
                })
                .collect(),
            cbs: [31, 6]
                .map(|words| FfxConstantBuffer {
                    num_32bit_entries: words,
                    data: vec![0; words as usize],
                })
                .to_vec(),
            pipeline,
            ..Default::default()
        };
        backend
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: "FSR2-LUM_PYRAMID".into(),
                descriptor: FfxGpuJobDescriptor::Compute(Box::new(compute)),
            })
            .unwrap();
        let readbacks = Rc::new(RefCell::new(Vec::new()));
        let sink = readbacks.clone();
        backend.set_job_observer(Some(Box::new(move |o: &mut FfxWgpuJobObservation<'_>| {
            if o.after || !matches!(o.job.descriptor, FfxGpuJobDescriptor::Compute(_)) {
                return;
            }
            for r in &o.resources {
                let readback = match (r.name, r.object) {
                    ("counter", FfxWgpuObject::Buffer(buffer)) => {
                        readback::Readback::buffer(o.device, o.encoder, buffer)
                    }
                    ("exposure", FfxWgpuObject::Texture(texture)) => {
                        readback::Readback::texture(o.device, o.encoder, texture, 0)
                    }
                    _ => continue,
                };
                sink.borrow_mut().push((r.name.to_owned(), readback));
            }
        })));
        let command_list =
            backend.ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        backend.execute_gpu_jobs(command_list, context).unwrap();
        let encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
        queue.submit([encoder.finish()]);
        let (names, pending): (Vec<_>, Vec<_>) = readbacks.take().into_iter().unzip();
        let bytes: HashMap<_, _> = names
            .into_iter()
            .zip(readback::Readback::read_all(&device, pending))
            .collect();
        assert_eq!(
            bytes.get("counter"),
            Some(&counter_data.to_vec()),
            "buffer backing"
        );
        let widened: Vec<u8> = exposure_data
            .chunks(8)
            .flat_map(|texel| texel.iter().copied().chain([0; 8]))
            .collect();
        assert_eq!(
            bytes.get("exposure"),
            Some(&widened),
            "RGBA32Float allocation"
        );
    }

    #[test]
    fn each_job_binds_its_own_resources_and_constants() {
        // Defects: a job runs with a group its pipeline made for another job
        // (another output, or an earlier frame's inputs), or with another
        // job's constants, including when two frames share one submission.
        // Expected: the generate-reactive pass's output for each job's own
        // inputs and scale, max(|color - opaque|) * scale with
        // FFX_FSR2_AUTOREACTIVEFLAGS_USE_COMPONENTS_MAX
        // (`ffx_fsr2_autogen_reactive_pass.wgsl`), as R8Unorm codes.
        let Some((device, queue)) = device() else {
            return;
        };
        let (backend, _) = ffx_get_interface_wgpu(&device);
        let mut backend = backend.borrow_mut();
        let context = backend
            .create_backend_context(FfxEffect::Fsr2, None)
            .unwrap();
        // Binary16 RGBA texels: black; a red of 0.25; a green of 0.5.
        let texels = |rgba: [u16; 4]| -> Vec<u8> {
            rgba.iter()
                .flat_map(|c| c.to_le_bytes())
                .cycle()
                .take(8 * 8 * 8)
                .collect()
        };
        let black = texels([0, 0, 0, 0x3c00]);
        let red = texels([0x3400, 0, 0, 0x3c00]);
        let green = texels([0, 0x3800, 0, 0x3c00]);
        let mut create = |name, format, usage, init_data| {
            backend
                .create_resource(
                    &FfxCreateResourceDescription {
                        heap_type: FfxHeapType::Default,
                        resource_description: FfxResourceDescription {
                            r#type: FfxResourceType::Texture2D,
                            format,
                            width: 8,
                            height: 8,
                            depth: 1,
                            mip_count: 1,
                            flags: FFX_RESOURCE_FLAGS_NONE,
                            usage,
                        },
                        initial_state: FFX_RESOURCE_STATE_COMPUTE_READ,
                        name,
                        id: 0,
                        init_data,
                    },
                    context,
                )
                .unwrap()
        };
        fn input(data: &[u8]) -> FfxResourceInitData<'_> {
            FfxResourceInitData::ffx_resource_init_buffer(data.len(), data)
        }
        let opaque = create(
            "opaque",
            FfxSurfaceFormat::R16G16B16A16Float,
            FFX_RESOURCE_USAGE_READ_ONLY,
            input(&black),
        );
        let red = create(
            "red",
            FfxSurfaceFormat::R16G16B16A16Float,
            FFX_RESOURCE_USAGE_READ_ONLY,
            input(&red),
        );
        let green = create(
            "green",
            FfxSurfaceFormat::R16G16B16A16Float,
            FFX_RESOURCE_USAGE_READ_ONLY,
            input(&green),
        );
        let uninitialized = FfxResourceInitData {
            r#type: FfxResourceInitDataType::Uninitialized,
            ..Default::default()
        };
        let outputs = ["x", "y"].map(|name| {
            create(
                name,
                FfxSurfaceFormat::R8Unorm,
                FFX_RESOURCE_USAGE_UAV,
                uninitialized,
            )
        });
        let samplers = [
            FfxFilterType::MinMagMipPoint,
            FfxFilterType::MinMagMipLinear,
        ]
        .map(|filter| FfxSamplerDescription {
            filter,
            address_mode_u: FfxAddressMode::Clamp,
            address_mode_v: FfxAddressMode::Clamp,
            address_mode_w: FfxAddressMode::Clamp,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        });
        let root_constants = [31, 6].map(|size| FfxRootConstantDescription {
            size,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        });
        let pipeline = backend
            .create_pipeline(
                FfxEffect::Fsr2,
                sp_fidelity::fsr2::FfxFsr2Pass::GenerateReactive as u32,
                0,
                &FfxPipelineDescription {
                    context_flags: 0,
                    samplers: &samplers,
                    root_constants: &root_constants,
                    name: "FSR2-GEN_REACTIVE".into(),
                    stage: FFX_BIND_COMPUTE_SHADER_STAGE,
                    indirect_workload: 0,
                    backbuffer_format: FfxSurfaceFormat::Unknown,
                },
                context,
            )
            .unwrap();
        let use_components_max =
            sp_fidelity::fsr2::resources::FFX_FSR2_AUTOREACTIVEFLAGS_USE_COMPONENTS_MAX;
        let job = |color, output, scale: f32| {
            let compute = FfxComputeJobDescription {
                dimensions: [1, 1, 1],
                srv_textures: pipeline
                    .srv_texture_bindings
                    .iter()
                    .map(|b| FfxTextureSRV {
                        resource: if b.name == "r_input_opaque_only" {
                            opaque
                        } else {
                            color
                        },
                    })
                    .collect(),
                uav_textures: vec![
                    FfxTextureUAV {
                        resource: output,
                        mip: 0,
                    };
                    pipeline.uav_texture_bindings.len()
                ],
                cbs: pipeline
                    .constant_buffer_bindings
                    .iter()
                    .map(|b| {
                        let data = if b.name == "cbGenerateReactive" {
                            vec![scale.to_bits(), 0, 0, use_components_max]
                        } else {
                            vec![0; 64]
                        };
                        FfxConstantBuffer {
                            num_32bit_entries: data.len() as u32,
                            data,
                        }
                    })
                    .collect(),
                pipeline: pipeline.clone(),
                ..Default::default()
            };
            FfxGpuJobDescription {
                job_label: "FSR2-GEN_REACTIVE".into(),
                descriptor: FfxGpuJobDescriptor::Compute(Box::new(compute)),
            }
        };
        let readbacks = Rc::new(RefCell::new(Vec::new()));
        let sink = readbacks.clone();
        backend.set_job_observer(Some(Box::new(move |o: &mut FfxWgpuJobObservation<'_>| {
            if !o.after || !matches!(o.job.descriptor, FfxGpuJobDescriptor::Compute(_)) {
                return;
            }
            for r in &o.resources {
                if let (true, FfxWgpuObject::Texture(texture)) = (r.writable, r.object) {
                    sink.borrow_mut()
                        .push(readback::Readback::texture(o.device, o.encoder, texture, 0));
                }
            }
        })));
        // Two frames into one encoder, the second swapping inputs and scales.
        let [x, y] = outputs;
        let mut encoder = device.create_command_encoder(&Default::default());
        for frame in [
            [(red, x, 1.), (green, y, 0.8)],
            [(green, x, 0.3), (red, y, 2.4)],
        ] {
            for (color, output, scale) in frame {
                backend
                    .schedule_gpu_job(&job(color, output, scale))
                    .unwrap();
            }
            let command_list = backend.ffx_get_command_list_wgpu(encoder);
            backend.execute_gpu_jobs(command_list, context).unwrap();
            encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
        }
        queue.submit([encoder.finish()]);
        let codes: Vec<Vec<u8>> = readback::Readback::read_all(&device, readbacks.take());
        // 0.25 x 1, 0.5 x 0.8, 0.5 x 0.3 and 0.25 x 2.4 as R8Unorm codes.
        let expected = [0.25f32, 0.4, 0.15, 0.6].map(|v| (v * 255.).round() as i32);
        assert_eq!(codes.len(), expected.len());
        for (job, (texels, expected)) in codes.iter().zip(expected).enumerate() {
            assert_eq!(texels.len(), 64);
            assert!(
                texels
                    .iter()
                    .all(|&code| (i32::from(code) - expected).abs() <= 1),
                "job {job}: {texels:?}, expected {expected}"
            );
        }
    }

    #[test]
    fn fsr2_runs_below_a_64_pixel_maximum_render_size() {
        // Defect: a UAV view of a mip the texture lacks. FSR2's luminance
        // pyramid binds FSR2_ExposureMips (half the maximum render size, full
        // chain) at mips 4 and 5 whatever its size (ffx_fsr2.cpp:669-678,
        // 998-1004); below 64 pixels the texture lacks mip 5, and below 32
        // mip 4 too. Expected: wgpu's validation accepts the context and a
        // frame at each size.
        use sp_fidelity::fsr2::*;
        let Some((device, queue)) = device() else {
            return;
        };
        for size in [2, 31, 32, 63] {
            let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
            let (backend, interface) = ffx_get_interface_wgpu(&device);
            let extent = FfxDimensions2D {
                width: size,
                height: size,
            };
            let mut context = FfxFsr2Context::default();
            ffx_fsr2_context_create(
                &mut context,
                &FfxFsr2ContextDescription {
                    flags: 0,
                    max_render_size: extent,
                    display_size: extent,
                    fp_message: None,
                    backend_interface: interface,
                },
            )
            .unwrap();
            let texture = |format, usage| {
                device.create_texture(&wgpu::TextureDescriptor {
                    label: None,
                    size: wgpu::Extent3d {
                        width: size,
                        height: size,
                        depth_or_array_layers: 1,
                    },
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format,
                    usage,
                    view_formats: &[],
                })
            };
            let read = wgpu::TextureUsages::TEXTURE_BINDING;
            let color = texture(wgpu::TextureFormat::Rgba16Float, read);
            let depth = texture(wgpu::TextureFormat::R32Float, read);
            let motion = texture(wgpu::TextureFormat::Rg16Float, read);
            let output = texture(
                wgpu::TextureFormat::Rgba16Float,
                wgpu::TextureUsages::STORAGE_BINDING,
            );
            let mut description = FfxFsr2DispatchDescription {
                motion_vector_scale: FfxFloatCoords2D {
                    x: size as f32,
                    y: size as f32,
                },
                render_size: extent,
                frame_time_delta: 16.6,
                pre_exposure: 1.,
                reset: true,
                camera_near: 0.1,
                camera_far: 100.,
                camera_fov_angle_vertical: 1.,
                view_space_to_meters_factor: 1.,
                ..Default::default()
            };
            {
                let mut backend = backend.borrow_mut();
                let state = FFX_RESOURCE_STATE_COMPUTE_READ;
                description.command_list = backend
                    .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
                description.color = backend.ffx_get_resource_wgpu(&color, "color", state);
                description.depth = backend.ffx_get_resource_wgpu(&depth, "depth", state);
                description.motion_vectors =
                    backend.ffx_get_resource_wgpu(&motion, "motion", state);
                description.output = backend.ffx_get_resource_wgpu(
                    &output,
                    "output",
                    FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                );
            }
            ffx_fsr2_context_dispatch(&mut context, &description).unwrap();
            let encoder = backend
                .borrow_mut()
                .ffx_take_command_list_wgpu(description.command_list)
                .unwrap();
            queue.submit([encoder.finish()]);
            ffx_fsr2_context_destroy(&mut context).unwrap();
            if let Some(error) = pollster::block_on(scope.pop()) {
                panic!("{size}x{size}: {error}");
            }
        }
    }

    #[test]
    fn a_clear_job_wgpu_rejects_fails_before_it_records() {
        // Defect: a job whose view or bind group wgpu rejects is recorded
        // anyway, which wgpu reports only when the caller finishes the
        // encoder, invalidating the caller's whole encoder, while execution
        // reports success (SDK-P28). Forced by clearing a destroyed texture
        // after a valid clear. Expected, from wgpu's validation and the
        // texels: execution fails with FFX_ERROR_BACKEND_API_ERROR,
        // `take_job_error` reports it once, the encoder finishes and runs
        // without a validation error, and the clear before the failure landed
        // (0.25, 0.5, 0.75, 1 as IEEE binary16: 3400, 3800, 3a00, 3c00).
        let Some((device, queue)) = device() else {
            return;
        };
        let (backend, _) = ffx_get_interface_wgpu(&device);
        let mut backend = backend.borrow_mut();
        let context = backend
            .create_backend_context(FfxEffect::Fsr2, None)
            .unwrap();
        let [kept, rejected] = ["kept", "rejected"].map(|name| {
            backend
                .create_resource(
                    &FfxCreateResourceDescription {
                        heap_type: FfxHeapType::Default,
                        resource_description: FfxResourceDescription {
                            r#type: FfxResourceType::Texture2D,
                            format: FfxSurfaceFormat::R16G16B16A16Float,
                            width: 13,
                            height: 9,
                            depth: 1,
                            mip_count: 1,
                            flags: FFX_RESOURCE_FLAGS_NONE,
                            usage: FFX_RESOURCE_USAGE_UAV,
                        },
                        initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                        name,
                        id: 0,
                        init_data: FfxResourceInitData::default(),
                    },
                    context,
                )
                .unwrap()
        });
        backend.texture(rejected).unwrap().destroy();
        for target in [kept, rejected] {
            backend
                .schedule_gpu_job(&FfxGpuJobDescription {
                    job_label: "Clear".into(),
                    descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                        color: [0.25, 0.5, 0.75, 1.],
                        target,
                    }),
                })
                .unwrap();
        }
        let validation = device.push_error_scope(wgpu::ErrorFilter::Validation);
        let command_list =
            backend.ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        assert_eq!(
            backend.execute_gpu_jobs(command_list, context),
            Err(FFX_ERROR_BACKEND_API_ERROR)
        );
        assert_eq!(backend.take_job_error(), Some(FFX_ERROR_BACKEND_API_ERROR));
        assert_eq!(backend.take_job_error(), None);
        let mut encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
        let readback =
            readback::Readback::texture(&device, &mut encoder, backend.texture(kept).unwrap(), 0);
        queue.submit([encoder.finish()]);
        let texels = readback::Readback::read_all(&device, vec![readback]).remove(0);
        if let Some(error) = pollster::block_on(validation.pop()) {
            panic!("{error}");
        }
        let cleared = [0x00, 0x34, 0x00, 0x38, 0x00, 0x3a, 0x00, 0x3c];
        assert_eq!(texels.len(), 13 * 9 * 8);
        assert!(texels.chunks_exact(8).all(|texel| texel == cleared));
    }

    #[test]
    fn an_fsr2_dispatch_whose_output_wgpu_rejects_leaves_the_encoder_valid() {
        // Defect: as for a clear job, for FSR2's compute jobs (SDK-P28): the
        // pass that writes the application's output binds a view wgpu
        // rejects, forced by destroying the output before the dispatch.
        // `ffxFsr2ContextDispatch` ignores `fpExecuteGpuJobs`'s result
        // (`ffx_fsr2.cpp:1321`), so `take_job_error` is how the application
        // learns. Expected, from wgpu's validation: the job error is
        // FFX_ERROR_BACKEND_API_ERROR and the encoder finishes and runs
        // without a validation error.
        use sp_fidelity::fsr2::*;
        let Some((device, queue)) = device() else {
            return;
        };
        let size = 64;
        let extent = FfxDimensions2D {
            width: size,
            height: size,
        };
        let (backend, interface) = ffx_get_interface_wgpu(&device);
        let mut context = FfxFsr2Context::default();
        ffx_fsr2_context_create(
            &mut context,
            &FfxFsr2ContextDescription {
                flags: 0,
                max_render_size: extent,
                display_size: extent,
                fp_message: None,
                backend_interface: interface,
            },
        )
        .unwrap();
        let texture = |format, usage| {
            device.create_texture(&wgpu::TextureDescriptor {
                label: None,
                size: wgpu::Extent3d {
                    width: size,
                    height: size,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format,
                usage,
                view_formats: &[],
            })
        };
        let read = wgpu::TextureUsages::TEXTURE_BINDING;
        let color = texture(wgpu::TextureFormat::Rgba16Float, read);
        let depth = texture(wgpu::TextureFormat::R32Float, read);
        let motion = texture(wgpu::TextureFormat::Rg16Float, read);
        let output = texture(
            wgpu::TextureFormat::Rgba16Float,
            wgpu::TextureUsages::STORAGE_BINDING,
        );
        output.destroy();
        let mut description = FfxFsr2DispatchDescription {
            motion_vector_scale: FfxFloatCoords2D {
                x: size as f32,
                y: size as f32,
            },
            render_size: extent,
            frame_time_delta: 16.6,
            pre_exposure: 1.,
            reset: true,
            camera_near: 0.1,
            camera_far: 100.,
            camera_fov_angle_vertical: 1.,
            view_space_to_meters_factor: 1.,
            ..Default::default()
        };
        let validation = device.push_error_scope(wgpu::ErrorFilter::Validation);
        {
            let mut backend = backend.borrow_mut();
            let state = FFX_RESOURCE_STATE_COMPUTE_READ;
            description.command_list = backend
                .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
            description.color = backend.ffx_get_resource_wgpu(&color, "color", state);
            description.depth = backend.ffx_get_resource_wgpu(&depth, "depth", state);
            description.motion_vectors = backend.ffx_get_resource_wgpu(&motion, "motion", state);
            description.output = backend.ffx_get_resource_wgpu(
                &output,
                "output",
                FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            );
        }
        ffx_fsr2_context_dispatch(&mut context, &description).unwrap();
        let mut backend = backend.borrow_mut();
        let encoder = backend
            .ffx_take_command_list_wgpu(description.command_list)
            .unwrap();
        assert_eq!(backend.take_job_error(), Some(FFX_ERROR_BACKEND_API_ERROR));
        drop(backend);
        queue.submit([encoder.finish()]);
        device.poll(wgpu::PollType::wait_indefinitely()).unwrap();
        if let Some(error) = pollster::block_on(validation.pop()) {
            panic!("{error}");
        }
        ffx_fsr2_context_destroy(&mut context).unwrap();
    }
}
