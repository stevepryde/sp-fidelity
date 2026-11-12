//! Source-level FI regressions: no renderer, game, or captured application inputs.
#[path = "framegen_support/frameinterpolation.rs"]
#[allow(dead_code)]
mod driver;
mod framegen_support;

use sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index;
use sp_fidelity::frameinterpolation::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::pass::{self, Binding, Job, Pipeline, Resource};
use sp_fidelity_oracle::{FRAMEINTERPOLATION, gpu};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

fn field(directory: &Path, backend: &str, axis: &str) -> Vec<u32> {
    fs::read(directory.join(format!(
        "{backend}/frame-0/frameinterpolation_game_motion_vector_field/{axis}.mip-0.bin"
    )))
    .unwrap()
    .chunks_exact(4)
    .map(|bytes| u32::from_le_bytes(bytes.try_into().unwrap()))
    .collect()
}

#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn original_receding_plane_leaves_inaccurate_vectors_between_primary_splats() {
    let gpu = gpu::Gpu::new(false, None);
    for size in [[96u32, 64u32]] {
        let directory = gpu::case_directory(&format!("fi-receding-plane-{}x{}", size[0], size[1]));
        let flags = FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED
            | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE;
        let words = driver::words(
            flags,
            size,
            size,
            [FfxSurfaceFormat::R16G16B16A16Float; 2],
            2,
        );
        let (events, _) = framegen_support::cpp(
            &FRAMEINTERPOLATION,
            framegen_support::capabilities(false, false),
            &words,
            &directory,
        );
        let pipe = events
            .iter()
            .find(|e| e[0] == "pipeline" && e[1] == 3)
            .unwrap();
        let dispatch = events
            .iter()
            .find(|e| e[0] == "compute" && e[1] == 3)
            .unwrap();
        let options = pipe[2].as_u64().unwrap() as u32;
        let pipeline = Pipeline {
            pass: 3,
            options,
            blob: ffx_get_permutation_blob_by_index(
                FfxEffect::FrameInterpolation,
                3,
                FFX_BIND_COMPUTE_SHADER_STAGE,
                options,
            )
            .unwrap(),
            root_constants: pipe[4]
                .as_array()
                .unwrap()
                .iter()
                .map(|v| v.as_u64().unwrap() as u32)
                .collect(),
            samplers: [
                FfxFilterType::MinMagMipPoint,
                FfxFilterType::MinMagMipLinear,
            ]
            .map(|filter| FfxSamplerDescription {
                filter,
                address_mode_u: FfxAddressMode::Clamp,
                address_mode_v: FfxAddressMode::Clamp,
                address_mode_w: FfxAddressMode::Clamp,
                stage: FFX_BIND_COMPUTE_SHADER_STAGE,
            })
            .to_vec(),
        };
        let mut bindings = Vec::new();
        let mut resources = Vec::new();
        let mut contents = HashMap::new();
        for (name, format, texel, uav) in [
            (
                "r_dilated_depth",
                FfxSurfaceFormat::R32Float,
                (0.3f32 / 9.0).to_le_bytes().to_vec(),
                false,
            ),
            (
                "r_dilated_motion_vectors",
                FfxSurfaceFormat::R16G16Float,
                vec![0; 4],
                false,
            ),
            (
                "r_previous_interpolation_source",
                FfxSurfaceFormat::R16G16B16A16Float,
                [0x3c00u16; 4]
                    .into_iter()
                    .flat_map(u16::to_le_bytes)
                    .collect(),
                false,
            ),
            (
                "r_current_interpolation_source",
                FfxSurfaceFormat::R16G16B16A16Float,
                [0x3c00u16; 4]
                    .into_iter()
                    .flat_map(u16::to_le_bytes)
                    .collect(),
                false,
            ),
            (
                "r_input_distortion_field",
                FfxSurfaceFormat::R16G16Float,
                vec![0; 4],
                false,
            ),
            (
                "rw_game_motion_vector_field_x",
                FfxSurfaceFormat::R32Uint,
                vec![0; 4],
                true,
            ),
            (
                "rw_game_motion_vector_field_y",
                FfxSurfaceFormat::R32Uint,
                vec![0; 4],
                true,
            ),
        ] {
            resources.push(Resource {
                r#type: FfxResourceType::Texture2D,
                name,
                format,
                width: size[0],
                height: size[1],
                mips: 1,
                created: uav.then_some(FFX_RESOURCE_USAGE_UAV),
            });
            bindings.push(Binding {
                uav,
                name,
                resource: name,
                mip: 0,
            });
            contents.insert(name, texel.repeat((size[0] * size[1]) as usize));
        }
        let half = |v: f32| (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(v) as u16).to_le_bytes();
        let mut motion = Vec::new();
        let mut previous = Vec::new();
        let mut current = Vec::new();
        for y in 0..size[1] {
            for x in 0..size[0] {
                let uv = [
                    (x as f32 + 0.5) / size[0] as f32,
                    (y as f32 + 0.5) / size[1] as f32,
                ];
                for component in uv {
                    motion.extend(half((component - 0.5) * 3.5));
                }
                for (z, data) in [(2.0, &mut previous), (9.0, &mut current)] {
                    for v in [0.25, 0.5 + (uv[1] - 0.5) * z / 16.0, 0.75, 1.0] {
                        data.extend(half(v));
                    }
                }
            }
        }
        contents.insert("r_dilated_motion_vectors", motion);
        contents.insert("r_previous_interpolation_source", previous);
        contents.insert("r_current_interpolation_source", current);
        let constants = dispatch[6][0][1]
            .as_array()
            .unwrap()
            .iter()
            .map(|v| v.as_u64().unwrap() as u32)
            .collect();
        let dimensions = std::array::from_fn(|i| dispatch[2][i].as_u64().unwrap() as u32);
        pass::run_backend(
            &gpu,
            &FRAMEINTERPOLATION,
            &directory,
            &resources,
            &pipeline,
            &[Job {
                bindings,
                constants: vec![("cbFI", constants)],
                contents,
                dimensions,
            }],
        );
        gpu::replay(&directory, &FRAMEINTERPOLATION);
        let port = field(&directory, "wgpu", "rw_game_motion_vector_field_y");
        let original = field(&directory, "metal-replay", "rw_game_motion_vector_field_y");
        let mut holes = 0;
        let mut worst = 0.0f32;
        for y in 4..size[1] - 4 {
            let expected = ((y as f32 + 0.5) / size[1] as f32 - 0.5) * 1.75 / 2.75;
            for x in 4..size[0] - 4 {
                let i = (y * size[0] + x) as usize;
                if original[i] >> 31 != 0 {
                    assert_eq!(port[i], original[i]);
                    continue;
                }
                holes += 1;
                // Independent analytic midpoint for a positive-depth plane,
                // z_previous=2, z_current=9; all motion inputs remain finite.
                let actual = {
                    let b = original[i] & 65535;
                    let e = ((b >> 10) & 31) as i32;
                    let f = (b & 1023) as f32 / 1024.0;
                    let sign = if b & 32768 == 0 { 1.0 } else { -1.0 };
                    sign * if e == 0 {
                        f * 2f32.powi(-14)
                    } else {
                        (1.0 + f) * 2f32.powi(e - 15)
                    }
                };
                worst = worst.max((actual - expected).abs() * size[1] as f32);
            }
        }
        println!(
            "{}: original holes={holes}, maximum motion error={worst} pixels",
            directory.display()
        );
        assert!(
            holes > 0 && worst > 2.0,
            "original negative control must reproduce the sparse-splat reconstruction defect"
        );
    }
}
