//! Storage representations for the reflection denoiser's narrow typed UAVs.
//! SDK descriptors and ping-pong indices stay in the component.
use sp_fidelity::types::{FFX_RESOURCE_USAGE_UAV, FfxResourceDescription, FfxSurfaceFormat};
use wgpu::TextureFormat;

pub(crate) struct Formats {
    pub scalar: TextureFormat,
    average: TextureFormat,
}

impl Default for Formats {
    fn default() -> Self {
        Self {
            scalar: TextureFormat::Rgba16Float,
            average: TextureFormat::Rgba16Float,
        }
    }
}

impl Formats {
    pub fn for_adapter(device: &wgpu::Device, adapter: &wgpu::Adapter) -> Self {
        let writable = |format| {
            if device
                .features()
                .contains(wgpu::Features::TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES)
                && adapter
                    .get_texture_format_features(format)
                    .flags
                    .contains(wgpu::TextureFormatFeatureFlags::STORAGE_WRITE_ONLY)
            {
                format
            } else {
                TextureFormat::Rgba16Float
            }
        };
        Self {
            scalar: writable(TextureFormat::R16Float),
            average: writable(TextureFormat::Rg11b10Ufloat),
        }
    }

    pub fn storage_override(&self, description: &FfxResourceDescription) -> Option<TextureFormat> {
        if description.usage & FFX_RESOURCE_USAGE_UAV == 0 {
            return None;
        }
        match description.format {
            FfxSurfaceFormat::R16Float => Some(self.scalar),
            FfxSurfaceFormat::R11G11B10Float => Some(self.average),
            _ => None,
        }
    }

    pub fn shader(
        &self,
        blob: &sp_fidelity::types::FfxShaderBlob,
        features: wgpu::Features,
    ) -> Option<String> {
        sp_fidelity::shaders::ffx_get_denoiser_wgsl_source(
            blob,
            self.scalar == TextureFormat::Rgba16Float,
            self.average == TextureFormat::Rgba16Float,
            features.contains(wgpu::Features::FLOAT32_FILTERABLE),
        )
    }
}

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::*;
    use crate::readback::Readback;
    use wgpu::util::DeviceExt;

    #[test]
    fn portable_average_radiance_matches_metal_typed_stores() {
        use sp_fidelity::denoiser::FfxDenoiserPass;
        use sp_fidelity::types::{FFX_BIND_COMPUTE_SHADER_STAGE, FfxEffect};
        let Some((adapter, device, queue)) = crate::tests::device_with_adapter() else {
            return;
        };
        // DX floating-point format conversion specifies truncation. Metal's
        // typed store is a hardware reference for that rounding. Vulkan permits
        // implementations to choose their format conversion rounding mode.
        if adapter.get_info().backend != wgpu::Backend::Metal {
            return;
        }
        if Formats::for_adapter(&device, &adapter).average != TextureFormat::Rg11b10Ufloat {
            eprintln!("skipping native typed-store comparison: no writable Rg11b10Ufloat");
            return;
        }
        let blob = sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index(
            FfxEffect::Denoiser,
            FfxDenoiserPass::ReprojectReflections as u32,
            FFX_BIND_COMPUTE_SHADER_STAGE,
            0,
        )
        .unwrap();
        let output_slot = sp_fidelity::shaders::FFX_WGSL_BINDING_OFFSET_UAV
            + blob
                .bound_uav_textures
                .iter()
                .find(|b| b.name == "rw_average_radiance")
                .unwrap()
                .binding;
        // Both sides receive identical f32 arithmetic results. Sample values just
        // below, at, and above halfway between representable storage values,
        // including the smallest nonzero exponent and the denormal interval.
        let mut values = vec![[-1.0_f32, 0.0, 1.0, 0.0], [65504.0, 65536.0, 1.0e8, 0.0]];
        for exponent in [-15, -14, -8, 0, 7, 14] {
            let scale = 2.0_f32.powi(exponent);
            for i in 0..128 {
                for remainder in [0.49, 0.5, 0.51] {
                    let value = scale * (1.0 + (i as f32 + remainder) / 64.0);
                    values.push([value, value, value, 0.0]);
                }
            }
        }
        let width = values.len() as u32;
        let input = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: None,
            contents: bytemuck::cast_slice(&values),
            usage: wgpu::BufferUsages::STORAGE,
        });
        let mut encoder = device.create_command_encoder(&Default::default());
        let mut results = Vec::new();
        for format in [TextureFormat::Rg11b10Ufloat, TextureFormat::Rgba16Float] {
            let target = device.create_texture(&wgpu::TextureDescriptor {
                label: None,
                size: wgpu::Extent3d {
                    width,
                    height: 1,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format,
                usage: wgpu::TextureUsages::STORAGE_BINDING | wgpu::TextureUsages::COPY_SRC,
                view_formats: &[],
            });
            let formats = Formats {
                average: format,
                ..Default::default()
            };
            let mut source = formats.shader(&blob, device.features()).unwrap();
            source.push_str(
                "@group(0) @binding(59) var<storage, read> inputs: array<vec4f>;
                 @compute @workgroup_size(64) fn main(@builtin(global_invocation_id) id: vec3u) {
                     if (id.x < arrayLength(&inputs)) {
                         FFX_DNSR_Reflections_StoreAverageRadiance(vec2i(i32(id.x), 0), inputs[id.x].xyz);
                     }
                 }",
            );
            let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: None,
                source: wgpu::ShaderSource::Wgsl(source.into()),
            });
            let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
                label: None,
                layout: None,
                module: &module,
                entry_point: Some("main"),
                compilation_options: Default::default(),
                cache: None,
            });
            let view = target.create_view(&Default::default());
            let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout: &pipeline.get_bind_group_layout(0),
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: output_slot,
                        resource: wgpu::BindingResource::TextureView(&view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 59,
                        resource: input.as_entire_binding(),
                    },
                ],
            });
            let mut pass = encoder.begin_compute_pass(&Default::default());
            pass.set_pipeline(&pipeline);
            pass.set_bind_group(0, &group, &[]);
            pass.dispatch_workgroups(width.div_ceil(64), 1, 1);
            drop(pass);
            results.push(Readback::texture(&device, &mut encoder, &target, 0));
        }
        queue.submit([encoder.finish()]);
        let bytes = Readback::read_all(&device, results);
        let packed: &[u32] = bytemuck::cast_slice(&bytes[0]);
        let portable: &[[u16; 4]] = bytemuck::cast_slice(&bytes[1]);
        for ((&rgb, rgba), value) in packed.iter().zip(portable).zip(values) {
            // An unsigned float11/10 shares f16's biased exponent. Aligning
            // the mantissa bits yields its exact binary16 representation.
            let native = [
                ((rgb & 2047) << 4) as u16,
                (((rgb >> 11) & 2047) << 4) as u16,
                ((rgb >> 22) << 5) as u16,
            ];
            assert_eq!(rgba[..3], native, "input {value:?}");
        }
    }
}
