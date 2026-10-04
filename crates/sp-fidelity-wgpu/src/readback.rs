//! GPU readback of resources, for captures around jobs (with
//! [`crate::FfxWgpuJobObserver`]) and for fidelity tests.

/// A copy recorded into an encoder, readable once the encoder is submitted.
pub struct Readback {
    buffer: wgpu::Buffer,
    bytes_per_row: usize,
    padded_bytes_per_row: usize,
    rows: usize,
}

impl Readback {
    /// Copy `mip` of `texture` (every layer, each after the previous). The
    /// texture needs `COPY_SRC`.
    pub fn texture(
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        texture: &wgpu::Texture,
        mip: u32,
    ) -> Self {
        let extent = texture.size().mip_level_size(mip, texture.dimension());
        let bytes_per_row = extent.width
            * texture
                .format()
                .block_copy_size(Some(wgpu::TextureAspect::All))
                .or_else(|| {
                    texture
                        .format()
                        .block_copy_size(Some(wgpu::TextureAspect::DepthOnly))
                })
                .expect("uncompressed format");
        let padded = bytes_per_row.next_multiple_of(wgpu::COPY_BYTES_PER_ROW_ALIGNMENT);
        let rows = extent.height * extent.depth_or_array_layers;
        let buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("FidelityFX readback"),
            size: u64::from(padded) * u64::from(rows),
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });
        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture,
                mip_level: mip,
                origin: wgpu::Origin3d::ZERO,
                aspect: if texture.format().is_depth_stencil_format() {
                    wgpu::TextureAspect::DepthOnly
                } else {
                    wgpu::TextureAspect::All
                },
            },
            wgpu::TexelCopyBufferInfo {
                buffer: &buffer,
                layout: wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(padded),
                    rows_per_image: Some(extent.height),
                },
            },
            extent,
        );
        Self {
            buffer,
            bytes_per_row: bytes_per_row as usize,
            padded_bytes_per_row: padded as usize,
            rows: rows as usize,
        }
    }

    /// Copy all of `source`, which needs `COPY_SRC`.
    pub fn buffer(
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        source: &wgpu::Buffer,
    ) -> Self {
        let buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("FidelityFX readback"),
            size: source.size(),
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });
        encoder.copy_buffer_to_buffer(source, 0, &buffer, 0, source.size());
        let size = usize::try_from(source.size()).unwrap();
        Self {
            buffer,
            bytes_per_row: size,
            padded_bytes_per_row: size,
            rows: 1,
        }
    }

    /// The copied bytes of each readback, without row padding, after the
    /// encoders that recorded them have been submitted.
    pub fn read_all(device: &wgpu::Device, readbacks: Vec<Self>) -> Vec<Vec<u8>> {
        for readback in &readbacks {
            readback
                .buffer
                .slice(..)
                .map_async(wgpu::MapMode::Read, |result| result.expect("map readback"));
        }
        device
            .poll(wgpu::PollType::wait_indefinitely())
            .expect("readback completion");
        readbacks
            .into_iter()
            .map(|readback| {
                let mapped = readback.buffer.slice(..).get_mapped_range();
                let mut bytes = Vec::with_capacity(readback.bytes_per_row * readback.rows);
                for row in 0..readback.rows {
                    let start = row * readback.padded_bytes_per_row;
                    bytes.extend_from_slice(&mapped[start..start + readback.bytes_per_row]);
                }
                drop(mapped);
                readback.buffer.unmap();
                bytes
            })
            .collect()
    }
}
