#![cfg(target_os = "macos")]
use sp_fidelity_wgpu::{ffx_get_interface_wgpu, presentation::*, readback::Readback};
use std::{
    path::PathBuf,
    process::Command,
    sync::{Arc, Mutex},
};
struct Target {
    device: wgpu::Device,
    bytes: Arc<Mutex<Vec<Vec<u8>>>>,
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
        let output = texture(&self.device);
        let read = output.clone();
        let device = self.device.clone();
        let bytes = self.bytes.clone();
        Ok(PresentFrame::new(output, move |queue, _| {
            let mut encoder = device.create_command_encoder(&Default::default());
            let read = Readback::texture(&device, &mut encoder, &read, 0);
            queue.submit([encoder.finish()]);
            bytes
                .lock()
                .unwrap()
                .push(Readback::read_all(&device, vec![read]).remove(0));
            Ok(())
        }))
    }
}
fn texture(device: &wgpu::Device) -> wgpu::Texture {
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
        usage: wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::RENDER_ATTACHMENT,
        view_formats: &[],
    })
}
#[test]
fn presentation_pixels_match_original_amd_hlsl_on_metal() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let directory = root.join("../../target/presentation-composition-oracle");
    std::fs::create_dir_all(&directory).unwrap();
    let scene: Vec<u8> = (0..256)
        .flat_map(|i| {
            [
                i as u8,
                (255 - i) as u8,
                ((i * 31) % 256) as u8,
                ((i * 13) % 256) as u8,
            ]
        })
        .collect();
    let ui: Vec<u8> = (0..256)
        .flat_map(|i| {
            [
                ((i * 7) % 256) as u8,
                ((i * 17) % 256) as u8,
                ((i * 23) % 256) as u8,
                i as u8,
            ]
        })
        .collect();
    std::fs::write(directory.join("scene.bin"), &scene).unwrap();
    std::fs::write(directory.join("ui.bin"), &ui).unwrap();
    let executable = directory.join("presentation-oracle");
    let compile = Command::new("clang++")
        .args(["-std=c++17", "-fobjc-arc", "-Wno-deprecated-declarations"])
        .arg(root.join("oracle/presentation.mm"))
        .args(["-framework", "Foundation", "-framework", "Metal", "-o"])
        .arg(&executable)
        .output()
        .unwrap();
    assert!(
        compile.status.success(),
        "{}",
        String::from_utf8_lossy(&compile.stderr)
    );
    let original = Command::new(executable)
        .arg(root.join("shaders/presentation"))
        .arg(&directory)
        .output()
        .unwrap();
    assert!(
        original.status.success(),
        "{}",
        String::from_utf8_lossy(&original.stderr)
    );
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
    let adapter = pollster::block_on(instance.request_adapter(&Default::default())).unwrap();
    let (device, queue) = pollster::block_on(adapter.request_device(&Default::default())).unwrap();
    let source = texture(&device);
    let ui_texture = texture(&device);
    for (texture, bytes) in [(&source, &scene), (&ui_texture, &ui)] {
        queue.write_texture(
            texture.as_image_copy(),
            bytes,
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(256),
                rows_per_image: Some(4),
            },
            texture.size(),
        );
    }
    let bytes = Arc::new(Mutex::new(Vec::new()));
    let (backend, _) = ffx_get_interface_wgpu(&device);
    let target = Target {
        device: device.clone(),
        bytes: bytes.clone(),
    };
    let config = wgpu::SurfaceConfiguration {
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format: wgpu::TextureFormat::Rgba8Unorm,
        width: 64,
        height: 4,
        present_mode: wgpu::PresentMode::Fifo,
        desired_maximum_frame_latency: 2,
        alpha_mode: wgpu::CompositeAlphaMode::Opaque,
        view_formats: vec![],
        color_space: wgpu::SurfaceColorSpace::Auto,
    };
    let mut presentation =
        FrameInterpolationSwapchain::new(backend.clone(), &queue, target, &config).unwrap();
    for (name, ui, flags) in [
        ("straight", Some(&ui_texture), 0),
        ("premultiplied", Some(&ui_texture), UI_PREMULTIPLIED_ALPHA),
        ("copy", None, 0),
    ] {
        presentation.register_ui_resource(ui, flags);
        let list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        presentation.present(list, &source).unwrap();
        presentation.wait_for_presents().unwrap();
        let port = bytes.lock().unwrap().pop().unwrap();
        let original = std::fs::read(directory.join(format!("{name}.bin"))).unwrap();
        assert_eq!(port, original, "{name}");
    }
    presentation.shutdown().unwrap();
}
