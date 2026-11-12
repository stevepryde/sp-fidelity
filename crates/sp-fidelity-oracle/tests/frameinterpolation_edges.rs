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

/// A constant upward translation moves every valid source away from the last
/// row. Only an invalid padded invocation can publish a primary vector there.
/// This catches an in-bounds atomic write, which GPU bounds validation cannot.
#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn padded_game_field_threads_do_not_publish_primary_vectors() {
    let gpu = gpu::Gpu::new(false, None);
    for size in [[32, 750], [750, 32]] {
        let directory = gpu::case_directory(&format!("fi-padded-{}x{}", size[0], size[1]));
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
        let horizontal = size[0] == 750;
        let motion = if horizontal {
            [0xb400u16, 0]
        } else {
            [0, 0xb400u16]
        };
        for (name, format, texel, uav) in [
            (
                "r_dilated_depth",
                FfxSurfaceFormat::R32Float,
                0.3f32.to_le_bytes().to_vec(),
                false,
            ),
            (
                "r_dilated_motion_vectors",
                FfxSurfaceFormat::R16G16Float,
                motion.into_iter().flat_map(u16::to_le_bytes).collect(),
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
        let axis = if horizontal {
            "rw_game_motion_vector_field_x"
        } else {
            "rw_game_motion_vector_field_y"
        };
        let port = field(&directory, "wgpu", axis);
        let original = field(&directory, "metal-replay", axis);
        let edge = |index: usize| {
            if horizontal {
                index % size[0] as usize == size[0] as usize - 1
            } else {
                index / size[0] as usize == size[1] as usize - 1
            }
        };
        let primary = |word: u32| word >> 31 != 0;
        assert!(
            original
                .iter()
                .enumerate()
                .any(|(i, &v)| edge(i) && primary(v)),
            "unchanged AMD negative control must expose the padded-thread bug: {}",
            directory.display()
        );
        assert!(
            !port.iter().enumerate().any(|(i, &v)| edge(i) && primary(v)),
            "padded invocations published primary vectors: {}",
            directory.display()
        );
        let valid: Vec<_> = port.iter().copied().filter(|&v| primary(v)).collect();
        assert!(
            !valid.is_empty(),
            "the real sources must still publish vectors"
        );
        assert!(
            valid.iter().all(|v| v & 0xffff == 0xb000),
            "every primary must carry the valid -1/8 midpoint motion"
        );
        for (i, &v) in original
            .iter()
            .enumerate()
            .filter(|(_, v)| primary(**v) && **v & 0xffff == 0xb000)
        {
            assert_eq!(port[i], v, "valid primary changed at {i}");
        }
        println!(
            "{}: original padded-edge writes reproduced, port excludes them",
            directory.display()
        );
    }
}
