//! Headless FSR 3.1.4: upscale a static scene, prepare frame generation, and
//!
//! Frame generation is unsupported because of unresolved motion artifacts.
//! Its code is retained for diagnostics; use standalone FSR2/FSR3 upscaling
//! for supported application integration.
//! interpolate through the same callback a presentation integration receives.
//! Run with `cargo run -p sp-fidelity-wgpu --features frame-generation --example fsr3`.
use sp_fidelity::fsr3::*;
use sp_fidelity::interface::FfxFrameGenerationConfig;
use sp_fidelity::types::*;
use sp_fidelity_wgpu::ffx_get_interface_wgpu;
use sp_fidelity_wgpu::readback::Readback;
use std::cell::RefCell;
use std::rc::Rc;

fn texture(
    device: &wgpu::Device,
    size: FfxDimensions2D,
    format: wgpu::TextureFormat,
    storage: bool,
) -> wgpu::Texture {
    device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: size.width,
            height: size.height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage: wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST
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
            bytes_per_row: Some(texture.width() * texture.format().block_copy_size(None).unwrap()),
            rows_per_image: Some(texture.height()),
        },
        texture.size(),
    );
}

fn main() {
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
    let adapter =
        pollster::block_on(instance.request_adapter(&Default::default())).expect("GPU adapter");
    let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
        required_features: sp_fidelity_wgpu::required_features(),
        required_limits: adapter.limits(),
        ..Default::default()
    }))
    .expect("FidelityFX-capable GPU");
    let (backend, interface) = ffx_get_interface_wgpu(&device);
    let configured = Rc::new(RefCell::new(None::<FfxFrameGenerationConfig>));
    let presentation = configured.clone();
    // A real application routes this configuration into its presentation
    // integration. This example retains it and drives its callback directly.
    backend
        .borrow_mut()
        .set_frame_generation_configurator(Some(Box::new(move |config| {
            *presentation.borrow_mut() = Some(config.clone());
            Ok(())
        })));
    let render = FfxDimensions2D {
        width: 128,
        height: 72,
    };
    let display = FfxDimensions2D {
        width: 192,
        height: 108,
    };
    let color = texture(&device, render, wgpu::TextureFormat::Rgba16Float, false);
    let depth = texture(&device, render, wgpu::TextureFormat::R32Float, false);
    let motion = texture(&device, render, wgpu::TextureFormat::Rg16Float, false);
    let upscaled = texture(&device, display, wgpu::TextureFormat::Rgba16Float, true);
    let interpolated = texture(&device, display, wgpu::TextureFormat::Rgba8Unorm, true);
    // A constant scene has the same independently known color before and
    // after interpolation; zero motion and unchanged depth isolate scheduling.
    let pixel: [u16; 4] = [0x3400, 0x3800, 0x3a00, 0x3c00]; // [0.25,0.5,0.75,1]
    let color_bytes: Vec<u8> = (0..render.width * render.height)
        .flat_map(|_| pixel.into_iter().flat_map(u16::to_le_bytes))
        .collect();
    upload(&queue, &color, &color_bytes);
    upload(
        &queue,
        &depth,
        &(0..render.width * render.height)
            .flat_map(|_| 0.5f32.to_le_bytes())
            .collect::<Vec<_>>(),
    );
    upload(
        &queue,
        &motion,
        &vec![0; render.width as usize * render.height as usize * 4],
    );
    let mut context = FfxFsr3Context::default();
    ffx_fsr3_context_create(
        &mut context,
        &FfxFsr3ContextDescription {
            flags: 0,
            max_render_size: render,
            max_upscale_size: display,
            display_size: display,
            backend_interface_shared_resources: interface.clone(),
            backend_interface_upscaling: interface.clone(),
            backend_interface_frame_interpolation: interface,
            fp_message: None,
            back_buffer_format: FfxSurfaceFormat::R16G16B16A16Float,
        },
    )
    .expect("create composite FSR3");
    let callback = ffx_fsr3_get_frame_generation_callback(&context).unwrap();
    let config = FfxFrameGenerationConfig {
        frame_generation_enabled: true,
        frame_generation_callback: Some(callback),
        ..Default::default()
    };
    ffx_fsr3_configure_frame_generation(&mut context, &config)
        .expect("configure presentation integration");
    let mut final_readback = None;
    for frame_id in 0..4 {
        let encoder = device.create_command_encoder(&Default::default());
        let command_list = backend.borrow_mut().ffx_get_command_list_wgpu(encoder);
        let resource = |texture, name, state| {
            backend
                .borrow_mut()
                .ffx_get_resource_wgpu(texture, name, state)
        };
        let input_color = resource(&color, "color", FFX_RESOURCE_STATE_COMPUTE_READ);
        let input_depth = resource(&depth, "depth", FFX_RESOURCE_STATE_COMPUTE_READ);
        let input_motion = resource(&motion, "motion-vectors", FFX_RESOURCE_STATE_COMPUTE_READ);
        let output = resource(&upscaled, "upscaled", FFX_RESOURCE_STATE_UNORDERED_ACCESS);
        let generated = resource(
            &interpolated,
            "interpolated",
            FFX_RESOURCE_STATE_UNORDERED_ACCESS,
        );
        let jitter = ffx_fsr3_get_jitter_offset(
            frame_id as i32,
            ffx_fsr3_get_jitter_phase_count(render.width as i32, display.width as i32),
        )
        .unwrap();
        let jitter_offset = FfxFloatCoords2D {
            x: jitter.0,
            y: jitter.1,
        };
        let motion_vector_scale = FfxFloatCoords2D {
            x: render.width as f32,
            y: render.height as f32,
        };
        ffx_fsr3_context_dispatch_upscale(
            &mut context,
            &FfxFsr3DispatchUpscaleDescription {
                frame_id,
                command_list,
                color: input_color,
                depth: input_depth.clone(),
                motion_vectors: input_motion.clone(),
                upscale_output: output.clone(),
                render_size: render,
                jitter_offset,
                motion_vector_scale,
                frame_time_delta: 16.67,
                pre_exposure: 1.0,
                reset: frame_id == 0,
                camera_near: 0.1,
                camera_far: 1000.0,
                camera_fov_angle_vertical: 1.0,
                view_space_to_meters_factor: 1.0,
                ..Default::default()
            },
        )
        .expect("upscale");
        ffx_fsr3_context_dispatch_frame_generation_prepare(
            &mut context,
            &FfxFsr3DispatchFrameGenerationPrepareDescription {
                frame_id,
                command_list,
                depth: input_depth,
                motion_vectors: input_motion,
                render_size: render,
                jitter_offset,
                motion_vector_scale,
                frame_time_delta: 16.67,
                camera_near: 0.1,
                camera_far: 1000.0,
                camera_fov_angle_vertical: 1.0,
                view_space_to_meters_factor: 1.0,
            },
        )
        .expect("prepare frame generation");
        let callback = configured
            .borrow()
            .as_ref()
            .unwrap()
            .frame_generation_callback
            .clone()
            .unwrap();
        callback(&FfxFrameGenerationDispatchDescription {
            frame_id,
            command_list,
            present_color: output,
            outputs: [
                generated,
                FfxResource::default(),
                FfxResource::default(),
                FfxResource::default(),
            ],
            num_interpolated_frames: 1,
            reset: frame_id == 0,
            back_buffer_transfer_function: FfxBackbufferTransferFunction::Scrgb,
            min_max_luminance: [0.0, 1000.0],
            interpolation_rect: FfxRect2D {
                left: 0,
                top: 0,
                width: display.width as i32,
                height: display.height as i32,
            },
        })
        .expect("interpolate");
        let mut encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        if let Some(error) = backend.borrow_mut().take_job_error() {
            panic!("GPU job failed: {error:?}");
        }
        if frame_id == 3 {
            final_readback = Some(Readback::texture(&device, &mut encoder, &interpolated, 0));
        }
        queue.submit([encoder.finish()]);
    }
    let bytes = Readback::read_all(&device, vec![final_readback.unwrap()])
        .pop()
        .unwrap();
    let center = ((display.height / 2 * display.width + display.width / 2) * 4) as usize;
    let rgba: [f32; 4] = std::array::from_fn(|channel| f32::from(bytes[center + channel]) / 255.0);
    // The SDK interpolation output is RGB; its alpha is not scene opacity.
    for (actual, expected) in rgba.into_iter().zip([0.25, 0.5, 0.75]) {
        assert!(
            actual.is_finite() && (actual - expected).abs() < 0.03,
            "constant scene changed: {rgba:?}"
        );
    }
    ffx_fsr3_configure_frame_generation(
        &mut context,
        &FfxFrameGenerationConfig {
            frame_generation_enabled: false,
            ..Default::default()
        },
    )
    .unwrap();
    ffx_fsr3_context_destroy(&mut context).expect("destroy composite FSR3");
    println!(
        "{}: four composite FSR3 frames, interpolated center {rgba:?}",
        adapter.get_info().name
    );
}
