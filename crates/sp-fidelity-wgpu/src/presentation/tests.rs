use super::{composition::Composition, native::*};
use crate::{ffx_get_interface_wgpu, readback::Readback};
use sp_fidelity::interface::*;
use std::{
    rc::Rc,
    sync::{Arc, Mutex, mpsc},
};

fn gpu() -> Option<(wgpu::Device, wgpu::Queue)> {
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
    let adapter = pollster::block_on(instance.request_adapter(&Default::default())).ok();
    let Some(adapter) = adapter else {
        assert_ne!(
            std::env::var("SP_FIDELITY_REQUIRE_GPU").as_deref(),
            Ok("1"),
            "GPU required"
        );
        return None;
    };
    Some(pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor::default())).unwrap())
}
fn texture(device: &wgpu::Device, usage: wgpu::TextureUsages) -> wgpu::Texture {
    device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: 64,
            height: 4,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8Unorm,
        usage: usage
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::RENDER_ATTACHMENT,
        view_formats: &[],
    })
}
fn upload(queue: &wgpu::Queue, texture: &wgpu::Texture, pixel: [u8; 4]) {
    queue.write_texture(
        texture.as_image_copy(),
        &pixel.repeat((texture.width() * texture.height()) as usize),
        wgpu::TexelCopyBufferLayout {
            offset: 0,
            bytes_per_row: Some(texture.width() * 4),
            rows_per_image: Some(texture.height()),
        },
        texture.size(),
    );
}
fn pixels(device: &wgpu::Device, queue: &wgpu::Queue, texture: &wgpu::Texture) -> Vec<u8> {
    let mut encoder = device.create_command_encoder(&Default::default());
    let read = Readback::texture(device, &mut encoder, texture, 0);
    queue.submit([encoder.finish()]);
    Readback::read_all(device, vec![read]).remove(0)
}

#[test]
fn composition_preserves_copy_alpha_and_blends_straight_and_premultiplied_ui() {
    let Some((device, queue)) = gpu() else {
        return;
    };
    let scene = texture(&device, wgpu::TextureUsages::empty());
    let ui = texture(&device, wgpu::TextureUsages::empty());
    let output = texture(&device, wgpu::TextureUsages::empty());
    let mut compose = Composition::new(&device);
    // Independent pixel requirements: a copy keeps alpha; half-alpha red over
    // blue produces equal red/blue, for either representation of the UI.
    for (ui_pixel, premul, expected) in [
        (None, false, [0, 0, 255, 37]),
        (Some([255, 0, 0, 128]), false, [128, 0, 127, 255]),
        (Some([128, 0, 0, 128]), true, [128, 0, 127, 255]),
        (Some([255, 0, 0, 0]), false, [0, 0, 255, 255]),
    ] {
        upload(&queue, &scene, [0, 0, 255, 37]);
        if let Some(pixel) = ui_pixel {
            upload(&queue, &ui, pixel);
        }
        let mut encoder = device.create_command_encoder(&Default::default());
        compose.encode(
            &device,
            &mut encoder,
            &scene,
            ui_pixel.map(|_| &ui),
            &output,
            premul,
            None,
        );
        queue.submit([encoder.finish()]);
        let bytes = pixels(&device, &queue, &output);
        for pixel in bytes.chunks_exact(4) {
            assert_eq!(pixel, expected);
        }
    }
}

type Observed = Arc<Mutex<Vec<(PresentInfo, Vec<u8>)>>>;
struct Target {
    device: wgpu::Device,
    observed: Observed,
    first: Option<mpsc::Receiver<()>>,
    failure: Arc<Mutex<Option<&'static str>>>,
}
impl PresentationTarget for Target {
    fn configure(
        &mut self,
        _: &wgpu::Device,
        _: &wgpu::SurfaceConfiguration,
    ) -> Result<(), PresentationError> {
        Ok(())
    }
    fn acquire(&mut self) -> Result<PresentFrame, PresentationError> {
        if let Some(reason) = *self.failure.lock().unwrap() {
            return Err(PresentationError::Surface(reason));
        }
        let target = texture(&self.device, wgpu::TextureUsages::empty());
        let read = target.clone();
        let device = self.device.clone();
        let observed = self.observed.clone();
        let block = self.first.take();
        Ok(PresentFrame::new(target, move |queue, info| {
            if let Some(block) = block {
                block.recv().unwrap();
            }
            let data = pixels(&device, queue, &read);
            observed.lock().unwrap().push((info, data));
            Ok(())
        }))
    }
}
fn config() -> wgpu::SurfaceConfiguration {
    wgpu::SurfaceConfiguration {
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format: wgpu::TextureFormat::Rgba8Unorm,
        width: 64,
        height: 4,
        present_mode: wgpu::PresentMode::Fifo,
        desired_maximum_frame_latency: 2,
        alpha_mode: wgpu::CompositeAlphaMode::Opaque,
        view_formats: vec![],
        color_space: wgpu::SurfaceColorSpace::Auto,
    }
}

#[test]
fn generated_then_real_survive_source_overwrite_and_mode_changes() {
    let Some((device, queue)) = gpu() else {
        return;
    };
    let (backend, _) = ffx_get_interface_wgpu(&device);
    let observed = Arc::new(Mutex::new(Vec::new()));
    let (unblock, block) = mpsc::channel();
    let failure = Arc::new(Mutex::new(None));
    let target = Target {
        device: device.clone(),
        observed: observed.clone(),
        first: Some(block),
        failure,
    };
    let mut presentation =
        FrameInterpolationSwapchain::new(backend.clone(), &queue, target, &config()).unwrap();
    let source = texture(&device, wgpu::TextureUsages::empty());
    let ui = texture(&device, wgpu::TextureUsages::empty());
    let weak = Rc::downgrade(&backend);
    let callback_thread = std::thread::current().id();
    let calls = Rc::new(std::cell::RefCell::new(Vec::new()));
    let calls_copy = calls.clone();
    let callback: FfxFrameGenerationDispatchFunc = Rc::new(move |desc| {
        assert_eq!(std::thread::current().id(), callback_thread);
        calls_copy.borrow_mut().push((desc.frame_id, desc.reset));
        let backend = weak.upgrade().unwrap();
        let mut backend = backend.borrow_mut();
        let output = backend.ffx_texture_wgpu(&desc.outputs[0]).unwrap();
        let view = output.create_view(&Default::default());
        let encoder = backend.ffx_command_encoder_wgpu(desc.command_list).unwrap();
        let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: &view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color::GREEN),
                    store: wgpu::StoreOp::Store,
                },
            })],
            ..Default::default()
        });
        Ok(())
    });
    for frame in 0..2 {
        presentation
            .configure_frame_generation(&FfxFrameGenerationConfig {
                frame_generation_enabled: true,
                frame_generation_callback: Some(callback.clone()),
                frame_id: frame,
                ..Default::default()
            })
            .unwrap();
        upload(
            &queue,
            &source,
            if frame == 0 {
                [255, 0, 0, 37]
            } else {
                [0, 0, 255, 43]
            },
        );
        upload(&queue, &ui, [0, 0, 0, 0]);
        presentation.register_ui_resource(Some(&ui), UI_INTERNAL_DOUBLE_BUFFERING);
        let list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        presentation.present(list, &source).unwrap();
        // All input reads were submitted. Overwriting the same allocation must
        // not mutate the queued real image or UI on the worker.
        upload(&queue, &source, [255, 255, 255, 255]);
        upload(&queue, &ui, [255, 255, 255, 255]);
        queue.submit([]);
    }
    unblock.send(()).unwrap();
    presentation.wait_for_presents().unwrap();
    let data = observed.lock().unwrap();
    assert_eq!(data.len(), 4);
    for (index, (info, bytes)) in data.iter().enumerate() {
        assert_eq!(info.interpolated, index % 2 == 0);
        assert_eq!(info.frame_id, (index / 2) as u64);
        let expected = match index {
            0 | 2 => [0, 255, 0, 255],
            1 => [255, 0, 0, 255],
            _ => [0, 0, 255, 255],
        };
        assert_eq!(&bytes[..4], expected);
    }
    drop(data);
    assert_eq!(&*calls.borrow(), &[(0, true), (1, false)]);
    presentation
        .configure_frame_generation(&FfxFrameGenerationConfig {
            frame_id: 2,
            ..Default::default()
        })
        .unwrap();
    presentation.register_ui_resource(None, 0);
    upload(&queue, &source, [7, 11, 13, 17]);
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    presentation.present(list, &source).unwrap();
    presentation.shutdown().unwrap();
    let data = observed.lock().unwrap();
    assert_eq!(data.len(), 5);
    assert!(!data[4].0.interpolated);
    assert_eq!(&data[4].1[..4], [7, 11, 13, 17]);
}

#[test]
fn failed_generation_presents_real_and_surface_error_can_be_reconfigured() {
    let Some((device, queue)) = gpu() else {
        return;
    };
    let (backend, _) = ffx_get_interface_wgpu(&device);
    let observed = Arc::new(Mutex::new(Vec::new()));
    let failure = Arc::new(Mutex::new(None));
    let target = Target {
        device: device.clone(),
        observed: observed.clone(),
        first: None,
        failure: failure.clone(),
    };
    let mut presentation =
        FrameInterpolationSwapchain::new(backend.clone(), &queue, target, &config()).unwrap();
    let source = texture(&device, wgpu::TextureUsages::empty());
    upload(&queue, &source, [3, 5, 7, 9]);
    presentation
        .configure_frame_generation(&FfxFrameGenerationConfig {
            frame_generation_enabled: true,
            only_present_interpolated: true,
            frame_generation_callback: Some(Rc::new(|_| {
                Err(sp_fidelity::error::FFX_ERROR_BACKEND_API_ERROR)
            })),
            ..Default::default()
        })
        .unwrap();
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    assert!(matches!(
        presentation.present(list, &source),
        Err(PresentationError::Sdk(_))
    ));
    presentation.wait_for_presents().unwrap();
    assert_eq!(&observed.lock().unwrap()[0].1[..4], [3, 5, 7, 9]);
    presentation
        .configure_frame_generation(&Default::default())
        .unwrap();
    *failure.lock().unwrap() = Some("outdated");
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    assert!(matches!(
        presentation.present(list, &source),
        Err(PresentationError::Surface("outdated"))
    ));
    assert!(
        backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(list)
            .is_some()
    );
    *failure.lock().unwrap() = None;
    presentation.resize(&config()).unwrap();
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    presentation.present(list, &source).unwrap();
    presentation.shutdown().unwrap();
    assert_eq!(observed.lock().unwrap().len(), 2);
}

#[test]
fn transient_surface_recovers_and_external_interpolation_uses_owner_callback() {
    let Some((device, queue)) = gpu() else { return };
    let (backend, _) = ffx_get_interface_wgpu(&device);
    let observed = Arc::new(Mutex::new(Vec::new()));
    let failure = Arc::new(Mutex::new(Some("occluded")));
    let target = Target {
        device: device.clone(),
        observed: observed.clone(),
        first: None,
        failure: failure.clone(),
    };
    let mut presentation =
        FrameInterpolationSwapchain::new(backend.clone(), &queue, target, &config()).unwrap();
    let source = texture(&device, wgpu::TextureUsages::empty());
    let interpolated = texture(&device, wgpu::TextureUsages::empty());
    upload(&queue, &source, [255, 0, 0, 255]);
    upload(&queue, &interpolated, [0, 255, 0, 37]);
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    assert!(matches!(
        presentation.present(list, &source),
        Err(PresentationError::Surface("occluded"))
    ));
    *failure.lock().unwrap() = None;
    // Failed acquisition did not consume the live encoder: retry it, then
    // observe the real target's pixels before changing generation mode.
    presentation.present(list, &source).unwrap();
    assert_eq!(&observed.lock().unwrap()[0].1[..4], [255, 0, 0, 255]);
    observed.lock().unwrap().clear();
    let owner = std::thread::current().id();
    let weak = Rc::downgrade(&backend);
    let callback: FfxPresentCallbackFunc = Rc::new(move |desc| {
        assert_eq!(std::thread::current().id(), owner);
        assert!(desc.is_interpolated_frame);
        let backend = weak.upgrade().unwrap();
        let mut backend = backend.borrow_mut();
        let source = backend.ffx_texture_wgpu(&desc.current_back_buffer).unwrap();
        let output = backend
            .ffx_texture_wgpu(&desc.output_swap_chain_buffer)
            .unwrap();
        backend
            .ffx_command_encoder_wgpu(desc.command_list)
            .unwrap()
            .copy_texture_to_texture(
                source.as_image_copy(),
                output.as_image_copy(),
                source.size(),
            );
        Ok(())
    });
    presentation
        .configure_frame_generation(&FfxFrameGenerationConfig {
            frame_generation_enabled: true,
            only_present_interpolated: true,
            present_callback: Some(callback),
            ..Default::default()
        })
        .unwrap();
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    presentation
        .present_with_interpolation(list, &source, Some(&interpolated))
        .unwrap();
    presentation.shutdown().unwrap();
    let actual = observed.lock().unwrap();
    assert_eq!(actual.len(), 1);
    assert!(actual[0].0.interpolated);
    assert_eq!(&actual[0].1[..4], [0, 255, 0, 37]);
}

#[test]
fn external_interpolation_without_copy_source_usage_is_presented() {
    let Some((device, queue)) = gpu() else { return };
    let (backend, _) = ffx_get_interface_wgpu(&device);
    let observed = Arc::new(Mutex::new(Vec::new()));
    let target = Target {
        device: device.clone(),
        observed: observed.clone(),
        first: None,
        failure: Arc::new(Mutex::new(None)),
    };
    let mut presentation =
        FrameInterpolationSwapchain::new(backend.clone(), &queue, target, &config()).unwrap();
    let source = texture(&device, wgpu::TextureUsages::empty());
    let external = device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: source.size(),
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8Unorm,
        usage: wgpu::TextureUsages::STORAGE_BINDING
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    upload(&queue, &external, [13, 29, 47, 61]);
    presentation
        .configure_frame_generation(&FfxFrameGenerationConfig {
            frame_generation_enabled: true,
            only_present_interpolated: true,
            ..Default::default()
        })
        .unwrap();
    let list = backend
        .borrow_mut()
        .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    presentation
        .present_with_interpolation(list, &source, Some(&external))
        .unwrap();
    presentation.shutdown().unwrap();
    let actual = observed.lock().unwrap();
    assert_eq!(actual.len(), 1);
    for pixel in actual[0].1.chunks_exact(4) {
        assert_eq!(pixel, [13, 29, 47, 61]);
    }
}

#[test]
fn failed_generation_and_failed_fallback_reset_the_next_dispatch() {
    let Some((device, queue)) = gpu() else { return };
    let (backend, _) = ffx_get_interface_wgpu(&device);
    let failure = Arc::new(Mutex::new(None));
    let target = Target {
        device: device.clone(),
        observed: Arc::default(),
        first: None,
        failure: failure.clone(),
    };
    let mut presentation =
        FrameInterpolationSwapchain::new(backend.clone(), &queue, target, &config()).unwrap();
    let source = texture(&device, wgpu::TextureUsages::empty());
    let resets = Rc::new(std::cell::RefCell::new(Vec::new()));
    let calls = resets.clone();
    let weak = Rc::downgrade(&backend);
    let callback: FfxFrameGenerationDispatchFunc = Rc::new(move |desc| {
        calls.borrow_mut().push(desc.reset);
        if desc.frame_id == 1 {
            return Err(sp_fidelity::error::FFX_ERROR_INVALID_ARGUMENT);
        }
        let backend = weak.upgrade().unwrap();
        let mut backend = backend.borrow_mut();
        let output = backend.ffx_texture_wgpu(&desc.outputs[0]).unwrap();
        let view = output.create_view(&Default::default());
        let encoder = backend.ffx_command_encoder_wgpu(desc.command_list).unwrap();
        let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: &view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color::GREEN),
                    store: wgpu::StoreOp::Store,
                },
            })],
            ..Default::default()
        });
        Ok(())
    });
    for frame_id in 0..3 {
        presentation
            .configure_frame_generation(&FfxFrameGenerationConfig {
                frame_generation_enabled: true,
                frame_generation_callback: Some(callback.clone()),
                frame_id,
                ..Default::default()
            })
            .unwrap();
        *failure.lock().unwrap() = (frame_id == 1).then_some("occluded");
        let list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        let result = presentation.present(list, &source);
        if frame_id == 1 {
            assert!(matches!(
                result,
                Err(PresentationError::Surface("occluded"))
            ));
            assert!(
                backend
                    .borrow_mut()
                    .ffx_take_command_list_wgpu(list)
                    .is_some()
            );
        } else {
            result.unwrap();
            presentation.wait_for_presents().unwrap();
        }
    }
    // The uninterrupted dispatch keeps history; after the failed generated
    // frame and failed real fallback, the next dispatch must reset it.
    assert_eq!(&*resets.borrow(), &[true, false, true]);
    presentation.shutdown().unwrap();
}
