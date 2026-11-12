//! Windowed AMD FSR3 upscaling, interpolation and paced presentation.
//!
//! Frame generation is unsupported because of unresolved motion artifacts.
//! Its code is retained for diagnostics; use standalone FSR2/FSR3 upscaling
//! for supported application integration.
//! `cargo run -p sp-fidelity-wgpu --features frame-generation --example fsr3_present -- --frames 120`
//! The finite run also exercises disable/enable, resize and joined shutdown.
#[cfg(target_arch = "wasm32")]
fn main() {}
#[cfg(not(target_arch = "wasm32"))]
fn main() {
    native::run();
}

#[cfg(not(target_arch = "wasm32"))]
mod native {
    use sp_fidelity::{fsr3::*, interface::*, types::*};
    use sp_fidelity_wgpu::{FfxWgpuBackend, ffx_get_interface_wgpu, presentation::*};
    use std::{
        cell::RefCell,
        rc::Rc,
        sync::Arc,
        time::{Duration, Instant},
    };
    use winit::{
        application::ApplicationHandler,
        event::WindowEvent,
        event_loop::{ActiveEventLoop, ControlFlow, EventLoop},
        window::{Window, WindowId},
    };

    const WIDTH: u32 = 128;
    const HEIGHT: u32 = 72;
    fn texture(
        device: &wgpu::Device,
        size: [u32; 2],
        format: wgpu::TextureFormat,
        storage: bool,
    ) -> wgpu::Texture {
        device.create_texture(&wgpu::TextureDescriptor {
            label: None,
            size: wgpu::Extent3d {
                width: size[0],
                height: size[1],
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
    }
    fn upload(queue: &wgpu::Queue, texture: &wgpu::Texture, bytes: &[u8]) {
        queue.write_texture(
            texture.as_image_copy(),
            bytes,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(
                    texture.width() * texture.format().block_copy_size(None).unwrap(),
                ),
                rows_per_image: Some(texture.height()),
            },
            texture.size(),
        );
    }
    struct Demo {
        window: Arc<Window>,
        device: wgpu::Device,
        queue: wgpu::Queue,
        backend: Rc<RefCell<FfxWgpuBackend>>,
        context: FfxFsr3Context,
        callback: FfxFrameGenerationDispatchFunc,
        presentation: Option<FrameInterpolationSwapchain>,
        config: wgpu::SurfaceConfiguration,
        color: wgpu::Texture,
        depth: wgpu::Texture,
        motion: wgpu::Texture,
        upscaled: wgpu::Texture,
        display: wgpu::Texture,
        ui: wgpu::Texture,
        blit: wgpu::RenderPipeline,
        blit_layout: wgpu::BindGroupLayout,
        frame: u64,
        enabled: bool,
        reset: bool,
        presented: usize,
        start: Instant,
    }
    impl Demo {
        fn new(events: &ActiveEventLoop) -> Self {
            let window = Arc::new(
                events
                    .create_window(
                        Window::default_attributes()
                            .with_title("FSR3 presentation")
                            .with_inner_size(winit::dpi::PhysicalSize::new(640, 360)),
                    )
                    .unwrap(),
            );
            let instance =
                wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
            let surface = Arc::new(instance.create_surface(window.clone()).unwrap());
            let adapter =
                pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
                    compatible_surface: Some(&surface),
                    ..Default::default()
                }))
                .unwrap();
            let (device, queue) =
                pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
                    required_features: sp_fidelity_wgpu::required_features(),
                    required_limits: adapter.limits(),
                    ..Default::default()
                }))
                .unwrap();
            let size = window.inner_size();
            let config = surface
                .get_default_config(&adapter, size.width, size.height)
                .unwrap();
            let (backend, _) = ffx_get_interface_wgpu(&device);
            let presentation = FrameInterpolationSwapchain::new(
                backend.clone(),
                &queue,
                SurfaceTarget::new(surface),
                &config,
            )
            .unwrap();
            let (context, upscaled, display, ui) = Self::outputs(&device, &backend, &config);
            let color = texture(
                &device,
                [WIDTH, HEIGHT],
                wgpu::TextureFormat::Rgba16Float,
                false,
            );
            let depth = texture(
                &device,
                [WIDTH, HEIGHT],
                wgpu::TextureFormat::R32Float,
                false,
            );
            let motion = texture(
                &device,
                [WIDTH, HEIGHT],
                wgpu::TextureFormat::Rg32Float,
                false,
            );
            upload(
                &queue,
                &depth,
                &0.5f32.to_le_bytes().repeat((WIDTH * HEIGHT) as usize),
            );
            let shader=device.create_shader_module(wgpu::ShaderModuleDescriptor {label:Some("example output transfer"),source:wgpu::ShaderSource::Wgsl(r#"
                @group(0) @binding(0) var image:texture_2d<f32>;
                @vertex fn vs(@builtin(vertex_index) i:u32)->@builtin(position) vec4<f32>{return vec4<f32>(f32(i32(i&1u)*4-1),f32(i32(i&2u)*(-2)+1),0.,1.);}
                @fragment fn fs(@builtin(position) p:vec4<f32>)->@location(0) vec4<f32>{let c=textureLoad(image,vec2<i32>(p.xy),0).rgb;return vec4<f32>(select(1.055*pow(max(c,vec3<f32>(0.)),vec3<f32>(1./2.4))-0.055,c*12.92,c<=vec3<f32>(0.0031308)),1.);}
            "#.into())});
            let blit_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: None,
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: false },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                }],
            });
            let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: None,
                bind_group_layouts: &[Some(&blit_layout)],
                immediate_size: 0,
            });
            let blit = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: None,
                layout: Some(&layout),
                vertex: wgpu::VertexState {
                    module: &shader,
                    entry_point: Some("vs"),
                    compilation_options: Default::default(),
                    buffers: &[],
                },
                fragment: Some(wgpu::FragmentState {
                    module: &shader,
                    entry_point: Some("fs"),
                    compilation_options: Default::default(),
                    targets: &[Some(wgpu::ColorTargetState {
                        format: wgpu::TextureFormat::Rgba8Unorm,
                        blend: None,
                        write_mask: wgpu::ColorWrites::ALL,
                    })],
                }),
                primitive: Default::default(),
                depth_stencil: None,
                multisample: Default::default(),
                multiview_mask: None,
                cache: None,
            });
            println!(
                "adapter: {} ({:?})",
                adapter.get_info().name,
                adapter.get_info().backend
            );
            Self {
                window,
                device,
                queue,
                backend,
                callback: ffx_fsr3_get_frame_generation_callback(&context).unwrap(),
                context,
                presentation: Some(presentation),
                config,
                color,
                depth,
                motion,
                upscaled,
                display,
                ui,
                blit,
                blit_layout,
                frame: 0,
                enabled: true,
                reset: true,
                presented: 0,
                start: Instant::now(),
            }
        }
        fn outputs(
            device: &wgpu::Device,
            backend: &Rc<RefCell<FfxWgpuBackend>>,
            config: &wgpu::SurfaceConfiguration,
        ) -> (FfxFsr3Context, wgpu::Texture, wgpu::Texture, wgpu::Texture) {
            let display = FfxDimensions2D {
                width: config.width,
                height: config.height,
            };
            let interface: FfxInterfaceRef = backend.clone();
            let mut context = FfxFsr3Context::default();
            ffx_fsr3_context_create(
                &mut context,
                &FfxFsr3ContextDescription {
                    flags: 0,
                    max_render_size: FfxDimensions2D {
                        width: WIDTH,
                        height: HEIGHT,
                    },
                    max_upscale_size: display,
                    display_size: display,
                    backend_interface_shared_resources: interface.clone(),
                    backend_interface_upscaling: interface.clone(),
                    backend_interface_frame_interpolation: interface,
                    fp_message: None,
                    back_buffer_format: FfxSurfaceFormat::R8G8B8A8Unorm,
                },
            )
            .unwrap();
            (
                context,
                texture(
                    device,
                    [config.width, config.height],
                    wgpu::TextureFormat::Rgba16Float,
                    true,
                ),
                texture(
                    device,
                    [config.width, config.height],
                    wgpu::TextureFormat::Rgba8Unorm,
                    false,
                ),
                texture(
                    device,
                    [config.width, config.height],
                    wgpu::TextureFormat::Rgba8Unorm,
                    false,
                ),
            )
        }
        fn resize(&mut self, width: u32, height: u32) {
            if width == 0
                || height == 0
                || [width, height] == [self.config.width, self.config.height]
            {
                return;
            }
            let presentation = self.presentation.as_mut().unwrap();
            if let Err(error) = presentation.wait_for_presents()
                && !matches!(error, PresentationError::Surface(_))
            {
                panic!("presentation drain: {error}");
            }
            self.device
                .poll(wgpu::PollType::Wait {
                    submission_index: None,
                    timeout: None,
                })
                .unwrap();
            ffx_fsr3_context_destroy(&mut self.context).unwrap();
            self.config.width = width;
            self.config.height = height;
            presentation.resize(&self.config).unwrap();
            (self.context, self.upscaled, self.display, self.ui) =
                Self::outputs(&self.device, &self.backend, &self.config);
            self.callback = ffx_fsr3_get_frame_generation_callback(&self.context).unwrap();
            self.reset = true;
            println!("resize: {width}x{height}");
        }
        fn render(&mut self) {
            let phase = (self.frame % 96) as u32;
            let mut colors = Vec::with_capacity((WIDTH * HEIGHT * 8) as usize);
            let mut motions = Vec::with_capacity((WIDTH * HEIGHT * 8) as usize);
            for y in 0..HEIGHT {
                for x in 0..WIDTH {
                    let inside = (phase..phase + 24).contains(&x) && (20..52).contains(&y);
                    let pixel: [u16; 4] = if inside {
                        [0x3a00, 0x3000, 0x2800, 0x3c00]
                    } else {
                        [0x2800, 0x3000, 0x3400, 0x3c00]
                    };
                    colors.extend(pixel.into_iter().flat_map(u16::to_le_bytes));
                    motions.extend(
                        [if inside { -1. / WIDTH as f32 } else { 0. }, 0.]
                            .into_iter()
                            .flat_map(f32::to_le_bytes),
                    );
                }
            }
            upload(&self.queue, &self.color, &colors);
            upload(&self.queue, &self.motion, &motions);
            // A small translucent UI bar is composed after interpolation.
            let mut ui = vec![0u8; (self.config.width * self.config.height * 4) as usize];
            for y in 8..24.min(self.config.height) {
                for x in 8..(16 + (self.frame % 200) as u32).min(self.config.width) {
                    let i = ((y * self.config.width + x) * 4) as usize;
                    ui[i..i + 4].copy_from_slice(&[255, 255, 255, 192]);
                }
            }
            upload(&self.queue, &self.ui, &ui);
            let list = self
                .backend
                .borrow_mut()
                .ffx_get_command_list_wgpu(self.device.create_command_encoder(&Default::default()));
            let mut backend = self.backend.borrow_mut();
            let color = backend.ffx_get_resource_wgpu(
                &self.color,
                "scene",
                FFX_RESOURCE_STATE_COMPUTE_READ,
            );
            let depth = backend.ffx_get_resource_wgpu(
                &self.depth,
                "depth",
                FFX_RESOURCE_STATE_COMPUTE_READ,
            );
            let motion = backend.ffx_get_resource_wgpu(
                &self.motion,
                "motion",
                FFX_RESOURCE_STATE_COMPUTE_READ,
            );
            let output = backend.ffx_get_resource_wgpu(
                &self.upscaled,
                "upscaled",
                FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            );
            drop(backend);
            let jitter = ffx_fsr3_get_jitter_offset(
                self.frame as i32,
                ffx_fsr3_get_jitter_phase_count(WIDTH as i32, self.config.width as i32),
            )
            .unwrap();
            let jitter = FfxFloatCoords2D {
                x: jitter.0,
                y: jitter.1,
            };
            let scale = FfxFloatCoords2D {
                x: WIDTH as f32,
                y: HEIGHT as f32,
            };
            let enabled = self.frame % 90 < 60;
            self.reset |= enabled != self.enabled;
            self.enabled = enabled;
            let callback = self.callback.clone();
            ffx_fsr3_configure_frame_generation(
                &mut self.context,
                &FfxFrameGenerationConfig {
                    frame_generation_enabled: enabled,
                    frame_generation_callback: Some(callback),
                    frame_id: self.frame,
                    interpolation_rect: FfxRect2D {
                        left: 0,
                        top: 0,
                        width: self.config.width as i32,
                        height: self.config.height as i32,
                    },
                    ..Default::default()
                },
            )
            .unwrap();
            ffx_fsr3_context_dispatch_upscale(
                &mut self.context,
                &FfxFsr3DispatchUpscaleDescription {
                    frame_id: self.frame,
                    command_list: list,
                    color,
                    depth: depth.clone(),
                    motion_vectors: motion.clone(),
                    upscale_output: output,
                    render_size: FfxDimensions2D {
                        width: WIDTH,
                        height: HEIGHT,
                    },
                    jitter_offset: jitter,
                    motion_vector_scale: scale,
                    frame_time_delta: 16.67,
                    pre_exposure: 1.,
                    reset: self.reset,
                    camera_near: 0.1,
                    camera_far: 1000.,
                    camera_fov_angle_vertical: 1.,
                    view_space_to_meters_factor: 1.,
                    ..Default::default()
                },
            )
            .unwrap();
            if enabled {
                ffx_fsr3_context_dispatch_frame_generation_prepare(
                    &mut self.context,
                    &FfxFsr3DispatchFrameGenerationPrepareDescription {
                        frame_id: self.frame,
                        command_list: list,
                        depth,
                        motion_vectors: motion,
                        render_size: FfxDimensions2D {
                            width: WIDTH,
                            height: HEIGHT,
                        },
                        jitter_offset: jitter,
                        motion_vector_scale: scale,
                        frame_time_delta: 16.67,
                        camera_near: 0.1,
                        camera_far: 1000.,
                        camera_fov_angle_vertical: 1.,
                        view_space_to_meters_factor: 1.,
                    },
                )
                .unwrap();
            }
            let group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &self.blit_layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(
                        &self.upscaled.create_view(&Default::default()),
                    ),
                }],
            });
            let mut backend = self.backend.borrow_mut();
            let encoder = backend.ffx_command_encoder_wgpu(list).unwrap();
            let view = self.display.create_view(&Default::default());
            {
                let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                        view: &view,
                        depth_slice: None,
                        resolve_target: None,
                        ops: wgpu::Operations {
                            load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                            store: wgpu::StoreOp::Store,
                        },
                    })],
                    ..Default::default()
                });
                pass.set_pipeline(&self.blit);
                pass.set_bind_group(0, &group, &[]);
                pass.draw(0..3, 0..1);
            }
            drop(backend);
            let presentation = self.presentation.as_mut().unwrap();
            presentation.register_ui_resource(Some(&self.ui), UI_INTERNAL_DOUBLE_BUFFERING);
            if self.reset {
                presentation.reset_history();
            }
            match presentation.present(list, &self.display) {
                Ok(()) => {}
                Err(PresentationError::Surface(reason)) => {
                    if let Some(encoder) =
                        self.backend.borrow_mut().ffx_take_command_list_wgpu(list)
                    {
                        self.queue.submit([encoder.finish()]);
                    }
                    let _ = presentation.wait_for_presents();
                    if !matches!(reason, "occluded" | "timeout") {
                        presentation.resize(&self.config).unwrap();
                    }
                    self.reset = true;
                    self.window.focus_window();
                    return;
                }
                Err(error) => panic!("presentation: {error}"),
            }
            for report in presentation.take_reports() {
                self.presented += report.present_calls.len();
            }
            self.reset = false;
            self.frame += 1;
            if self.frame == 40 {
                let _ = self
                    .window
                    .request_inner_size(winit::dpi::PhysicalSize::new(800, 450));
            }
        }
        fn shutdown(&mut self) {
            if let Some(mut presentation) = self.presentation.take() {
                if let Err(error) = presentation.wait_for_presents()
                    && !matches!(error, PresentationError::Surface(_))
                {
                    panic!("presentation drain: {error}");
                }
                self.device
                    .poll(wgpu::PollType::Wait {
                        submission_index: None,
                        timeout: None,
                    })
                    .unwrap();
                for report in presentation.take_reports() {
                    self.presented += report.present_calls.len();
                }
                presentation.shutdown().unwrap();
                ffx_fsr3_context_destroy(&mut self.context).unwrap();
                println!(
                    "{} real frames, {} completed presentation calls, {:.3}s; generation toggles, resize and shutdown completed",
                    self.frame,
                    self.presented,
                    self.start.elapsed().as_secs_f64()
                );
            }
        }
    }
    struct App {
        demo: Option<Demo>,
        limit: u64,
        next: Instant,
    }
    impl ApplicationHandler for App {
        fn resumed(&mut self, events: &ActiveEventLoop) {
            if self.demo.is_none() {
                self.demo = Some(Demo::new(events));
            }
        }
        fn window_event(&mut self, events: &ActiveEventLoop, _: WindowId, event: WindowEvent) {
            let Some(demo) = &mut self.demo else {
                return;
            };
            if demo.presentation.is_none() {
                return;
            }
            match event {
                WindowEvent::CloseRequested => {
                    demo.shutdown();
                    events.exit();
                }
                WindowEvent::Resized(size) => demo.resize(size.width, size.height),
                WindowEvent::RedrawRequested => {
                    demo.render();
                    if self.limit > 0 && demo.frame >= self.limit {
                        demo.shutdown();
                        events.exit();
                    }
                }
                _ => {}
            }
        }
        fn about_to_wait(&mut self, events: &ActiveEventLoop) {
            let now = Instant::now();
            if now >= self.next {
                if let Some(demo) = &self.demo {
                    demo.window.request_redraw();
                }
                self.next = now + Duration::from_micros(16_667);
            }
            events.set_control_flow(ControlFlow::WaitUntil(self.next));
        }
    }
    pub fn run() {
        let args: Vec<_> = std::env::args().collect();
        let limit = args
            .iter()
            .position(|x| x == "--frames")
            .map(|i| args[i + 1].parse().unwrap())
            .unwrap_or(0);
        let events = EventLoop::new().unwrap();
        let mut app = App {
            demo: None,
            limit,
            next: Instant::now(),
        };
        events.run_app(&mut app).unwrap();
        if limit > 0 {
            assert!(
                app.demo.as_ref().is_some_and(|demo| demo.presented > 0),
                "No surface presentations completed; run with the window visible on an active display"
            );
        }
    }
}
