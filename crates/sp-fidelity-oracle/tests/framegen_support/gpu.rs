use sp_fidelity::types::*;
use sp_fidelity_oracle::gpu::{self, Input};

pub fn input(
    gpu: &gpu::Gpu,
    name: &'static str,
    size: [u32; 2],
    format: FfxSurfaceFormat,
    bytes: Vec<u8>,
    writable: bool,
) -> Input {
    let native = match format {
        FfxSurfaceFormat::R16G16B16A16Float => wgpu::TextureFormat::Rgba16Float,
        FfxSurfaceFormat::R16G16Float => wgpu::TextureFormat::Rg16Float,
        FfxSurfaceFormat::R16G16Sint => wgpu::TextureFormat::Rg16Sint,
        FfxSurfaceFormat::R32Float => wgpu::TextureFormat::R32Float,
        FfxSurfaceFormat::R32Uint => wgpu::TextureFormat::R32Uint,
        _ => panic!("unimplemented input format {format:?}"),
    };
    let texture = gpu.device.create_texture(&wgpu::TextureDescriptor {
        label: Some(name),
        size: wgpu::Extent3d {
            width: size[0],
            height: size[1],
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: native,
        usage: wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST
            | if writable {
                wgpu::TextureUsages::STORAGE_BINDING
                    | if format == FfxSurfaceFormat::R32Uint {
                        wgpu::TextureUsages::STORAGE_ATOMIC
                    } else {
                        wgpu::TextureUsages::empty()
                    }
            } else {
                wgpu::TextureUsages::empty()
            },
        view_formats: &[],
    });
    gpu::upload(&gpu.queue, &texture, &bytes);
    Input {
        name,
        texture,
        format,
        cube: false,
        bytes,
    }
}

/// Binary16 values selected exactly from their representable bit patterns.
/// Motion of high-contrast blocks forces optical flow/history to contribute.
pub fn color(size: [u32; 2], frame: u32) -> Vec<u8> {
    (0..size[1])
        .flat_map(|y| {
            (0..size[0]).flat_map(move |x| {
                let stripe = ((x + frame * 3) / 8 + y / 11) % 4;
                let r = [0x3000, 0x3400, 0x3800, 0x3c00][stripe as usize];
                let g = [0x3a00, 0x3600, 0x3200, 0x3800][((stripe + y / 5) % 4) as usize];
                [r, g, 0x3800u16, 0x3c00]
                    .into_iter()
                    .flat_map(u16::to_le_bytes)
            })
        })
        .collect()
}

pub fn zeros(size: [u32; 2], bytes_per_texel: u32) -> Vec<u8> {
    vec![0; (size[0] * size[1] * bytes_per_texel) as usize]
}
