//! Exact motion supplied directly to original interpolation: isolate color
//! selection from motion reconstruction, inpainting, any renderer, or a game.
//! Passing seam diagnostics reproduce a known upstream limitation and establish
//! port parity; they do not assert that interpolation quality is correct.
#[path = "framegen_support/frameinterpolation.rs"]
#[allow(dead_code)]
mod driver;
mod framegen_support;
use sp_fidelity::{
    blob_accessors::ffx_get_permutation_blob_by_index, frameinterpolation::*, types::*,
};
use sp_fidelity_oracle::{
    FRAMEINTERPOLATION, gpu,
    pass::{self, Binding, Job, Pipeline, Resource},
};
use std::{collections::HashMap, fs};

#[derive(Clone, Copy)]
enum Scene {
    Illumination,
    Mirror,
    TexturedMirror,
    Lambertian,
    AliasedDiffuseIllumination,
}
fn run(scene: Scene) {
    let mirror = matches!(scene, Scene::Mirror | Scene::TexturedMirror);
    let textured = matches!(scene, Scene::TexturedMirror);
    let lambertian = matches!(scene, Scene::Lambertian | Scene::AliasedDiffuseIllumination);
    let aliased = matches!(scene, Scene::AliasedDiffuseIllumination);
    let gpu = gpu::Gpu::new(false, None);
    let size = [96u32, 64u32];
    let directory = gpu::case_directory(if aliased {
        "fi-wrong-flow-aliased-illumination-control"
    } else if textured {
        "fi-exact-flow-textured-mirror-seam"
    } else if mirror {
        "fi-exact-flow-mirror-seam"
    } else if lambertian {
        "fi-wrong-flow-lambertian-control"
    } else {
        "fi-exact-motion-illumination-seam"
    });
    let words = driver::words(
        FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE,
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
        .find(|e| e[0] == "pipeline" && e[1] == 6)
        .unwrap();
    let dispatch = events
        .iter()
        .find(|e| e[0] == "compute" && e[1] == 6)
        .unwrap();
    let options = pipe[2].as_u64().unwrap() as u32;
    let pipeline = Pipeline {
        pass: 6,
        options,
        blob: ffx_get_permutation_blob_by_index(
            FfxEffect::FrameInterpolation,
            6,
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
        samplers: vec![FfxSamplerDescription {
            filter: FfxFilterType::MinMagMipLinear,
            address_mode_u: FfxAddressMode::Clamp,
            address_mode_v: FfxAddressMode::Clamp,
            address_mode_w: FfxAddressMode::Clamp,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        }],
    };
    let mut resources = Vec::new();
    let mut bindings = Vec::new();
    let mut contents = HashMap::new();
    // A frontoparallel infinite plane translated down by 1/4 viewport between
    // keyframes has exact midpoint-to-previous motion (0,-1/8). Both sources
    // are spatially uniform. Their midpoint intensity is (.5+.75)/2=.625.
    let priority = (1u32 << 31) | (1 << 21);
    for (name, format, texel, uav, buffer) in [
        (
            "r_previous_interpolation_source",
            FfxSurfaceFormat::R16G16B16A16Float,
            [0x3800u16, 0x3800, 0x3800, 0x3c00]
                .into_iter()
                .flat_map(u16::to_le_bytes)
                .collect::<Vec<_>>(),
            false,
            false,
        ),
        (
            "r_current_interpolation_source",
            FfxSurfaceFormat::R16G16B16A16Float,
            [0x3a00u16, 0x3a00, 0x3a00, 0x3c00]
                .into_iter()
                .flat_map(u16::to_le_bytes)
                .collect(),
            false,
            false,
        ),
        (
            "r_disocclusion_mask",
            FfxSurfaceFormat::R8G8Unorm,
            vec![255, 255],
            false,
            false,
        ),
        (
            "r_game_motion_vector_field_x",
            FfxSurfaceFormat::R32Uint,
            priority.to_le_bytes().to_vec(),
            false,
            false,
        ),
        (
            "r_game_motion_vector_field_y",
            FfxSurfaceFormat::R32Uint,
            (priority | 0xb000).to_le_bytes().to_vec(),
            false,
            false,
        ),
        (
            "r_optical_flow_motion_vector_field_x",
            FfxSurfaceFormat::R32Uint,
            priority.to_le_bytes().to_vec(),
            false,
            false,
        ),
        (
            "r_optical_flow_motion_vector_field_y",
            FfxSurfaceFormat::R32Uint,
            (priority | 0xb000).to_le_bytes().to_vec(),
            false,
            false,
        ),
        (
            "r_inpainting_pyramid",
            FfxSurfaceFormat::R16G16B16A16Float,
            vec![0; 8],
            false,
            false,
        ),
        (
            "r_counters",
            FfxSurfaceFormat::R32Uint,
            vec![12, 0, 0, 0, 12, 0, 0, 0, 12, 0, 0, 0],
            false,
            true,
        ),
        (
            "rw_output",
            FfxSurfaceFormat::R16G16B16A16Float,
            vec![0; 8],
            true,
            false,
        ),
    ] {
        resources.push(Resource {
            r#type: if buffer {
                FfxResourceType::Buffer
            } else {
                FfxResourceType::Texture2D
            },
            name,
            format,
            width: if buffer { 12 } else { size[0] },
            height: if buffer { 1 } else { size[1] },
            mips: 1,
            created: Some(FFX_RESOURCE_USAGE_UAV),
        });
        bindings.push(Binding {
            uav,
            name,
            resource: name,
            mip: 0,
        });
        contents.insert(
            name,
            if buffer {
                texel
            } else {
                texel.repeat((size[0] * size[1]) as usize)
            },
        );
    }
    if mirror {
        // Infinite translating planar mirror, fixed camera orientation and an
        // environment at infinity. Reflected radiance depends on the viewing
        // ray, so both color images and the physical midpoint are identical.
        // Surface geometry moves by 1/4 screen; optical flow is exactly zero.
        let mut colors = Vec::new();
        for y in 0..size[1] {
            for x in 0..size[0] {
                let uv = [
                    (x as f32 + 0.5) / size[0] as f32,
                    (y as f32 + 0.5) / size[1] as f32,
                ];
                let red = if textured {
                    0.5 + 0.25 * ((y as f32 + 0.5) * std::f32::consts::TAU / 48.0).sin()
                } else {
                    0.25 + 0.5 * uv[1]
                };
                for value in [red, 0.25 + 0.25 * uv[0], 0.5, 1.0] {
                    colors.extend(
                        (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16).to_le_bytes(),
                    );
                }
            }
        }
        contents.insert("r_previous_interpolation_source", colors.clone());
        contents.insert("r_current_interpolation_source", colors);
        for name in [
            "r_optical_flow_motion_vector_field_x",
            "r_optical_flow_motion_vector_field_y",
        ] {
            contents.insert(
                name,
                priority.to_le_bytes().repeat((size[0] * size[1]) as usize),
            );
        }
    }
    if lambertian {
        // A diffuse painted plane has geometric image motion; a stationary OF
        // estimate is deliberately wrong. Its non-linear texture distinguishes
        // correct correspondence from an average of unrelated screen samples.
        for (name, shift) in [
            ("r_previous_interpolation_source", 0.0),
            ("r_current_interpolation_source", 16.0),
        ] {
            let mut colors = Vec::new();
            for y in 0..size[1] {
                for _x in 0..size[0] {
                    let period = if aliased { 16.0 } else { 48.0 };
                    let light = if aliased && shift > 0.0 {
                        1.0 / 1024.0
                    } else {
                        0.0
                    };
                    let red = 0.5
                        + light
                        + 0.25 * ((y as f32 + 0.5 - shift) * std::f32::consts::TAU / period).sin();
                    for value in [red, 0.5, 0.5, 1.0] {
                        colors.extend(
                            (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16)
                                .to_le_bytes(),
                        );
                    }
                }
            }
            contents.insert(name, colors);
        }
        for name in [
            "r_optical_flow_motion_vector_field_x",
            "r_optical_flow_motion_vector_field_y",
        ] {
            contents.insert(
                name,
                priority.to_le_bytes().repeat((size[0] * size[1]) as usize),
            );
        }
    }
    let mut constants: Vec<u32> = dispatch[6][0][1]
        .as_array()
        .unwrap()
        .iter()
        .map(|v| v.as_u64().unwrap() as u32)
        .collect();
    // Linear/scRGB makes the specified .5 -> .75 illumination ramp an
    // unambiguous linear-radiance midpoint, not interpolation in sRGB codes.
    constants[35] = FfxBackbufferTransferFunction::Scrgb as u32;
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
            dimensions: [12, 8, 1],
        }],
    );
    gpu::replay(&directory, &FRAMEINTERPOLATION);
    let original = fs::read(
        directory.join("metal-replay/frame-0/frameinterpolation_interpolation/rw_output.mip-0.bin"),
    )
    .unwrap();
    for backend in ["metal-replay", "wgpu"] {
        let bytes = fs::read(directory.join(format!(
            "{backend}/frame-0/frameinterpolation_interpolation/rw_output.mip-0.bin"
        )))
        .unwrap();
        assert!(
            bytes == original,
            "{backend}: isolated interpolation must match unchanged original HLSL; artifacts at {}",
            directory.display()
        );
        let word = |x: usize, y: usize| {
            u16::from_le_bytes(
                bytes[(y * 96 + x) * 8..(y * 96 + x) * 8 + 2]
                    .try_into()
                    .unwrap(),
            )
        };
        if aliased {
            let unpack = |bits: u16| {
                let exp = i32::from((bits >> 10) & 31);
                let f = f32::from(bits & 1023) / 1024.0;
                if exp == 0 {
                    f * 2f32.powi(-14)
                } else {
                    (1.0 + f) * 2f32.powi(exp - 15)
                }
            };
            let mut worst = 0f32;
            for y in 8..64 {
                let expected = 0.5
                    + 0.25 * ((y as f32 + 0.5 - 8.0) * std::f32::consts::TAU / 16.0).sin()
                    + 1.0 / 2048.0;
                worst = worst.max((unpack(word(48, y)) - expected).abs());
            }
            // The illumination ramp is one binary16 step at this intensity.
            // A change that selects the aliased OF texture incurs ~.5 error,
            // far beyond missing half-step illumination or input quantization.
            assert!(
                worst < 3.0 / 1024.0,
                "{backend}: tiny illumination change switched to an incorrect aliased optical hypothesis: {worst}"
            );
            println!(
                "{backend}: aliased diffuse with small illumination change max error={worst}, source={}",
                directory.display()
            );
            continue;
        }
        if lambertian {
            for y in 8..64 {
                let expected = sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(
                    0.5 + 0.25 * ((y as f32 + 0.5 - 8.0) * std::f32::consts::TAU / 48.0).sin(),
                ) as u16;
                assert_eq!(
                    word(48, y),
                    expected,
                    "{backend}: wrong optical flow must not replace a valid diffuse correspondence at row {y}"
                );
            }
            println!(
                "{backend}: wrong-flow diffuse control preserves exact moving texture at {}",
                directory.display()
            );
            continue;
        }
        if textured {
            let mut wrong_overlap = 0;
            let mut wrong_edge = 0;
            for y in 0..64 {
                let expected = sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(
                    0.5 + 0.25 * ((y as f32 + 0.5) * std::f32::consts::TAU / 48.0).sin(),
                ) as u16;
                let wrong = word(48, y) != expected;
                if (8..56).contains(&y) {
                    wrong_overlap += usize::from(wrong);
                } else {
                    wrong_edge += usize::from(wrong);
                }
            }
            println!(
                "{backend}: stationary textured mirror mismatched rows: overlap={wrong_overlap}, edge={wrong_edge}, source={}",
                directory.display()
            );
            assert!(
                wrong_overlap > 0 && wrong_edge > 0,
                "diagnostic must reproduce the original hypothesis-selection and boundary limitations"
            );
            continue;
        }
        if mirror {
            let half = |value: f32| sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16;
            let expected = half(0.25 + 0.5 * 62.5 / 64.0);
            let shifted = half(0.25 + 0.5 * 54.5 / 64.0);
            println!(
                "{backend}: mirror edge={:#x}, expected={expected:#x}, source={}",
                word(48, 62),
                directory.display()
            );
            assert_eq!(
                word(48, 62),
                shifted,
                "diagnostic must reproduce the original geometric warp of a stationary reflection"
            );
            assert_ne!(
                word(48, 62),
                expected,
                "known mirror defect was not reproduced"
            );
            continue;
        }
        assert_eq!(word(48, 32), 0x3900, "overlap should interpolate to .625");
        assert_eq!(
            word(48, 62),
            0x3800,
            "original one-sided selection exposes .5 edge seam"
        );
        println!(
            "{backend}: exact-motion overlap=.625/outgoing=.5 at {}",
            directory.display()
        );
    }
}

#[test]
#[ignore = "requires Metal and original DXC interpolation variant"]
fn original_interpolation_reproduces_one_sided_illumination_seam_with_exact_motion() {
    run(Scene::Illumination);
}

#[test]
#[ignore = "requires Metal and original DXC interpolation variant"]
fn original_interpolation_reproduces_affine_mirror_seam_despite_exact_optical_flow() {
    run(Scene::Mirror);
}

#[test]
#[ignore = "requires Metal and original DXC interpolation variant"]
fn wrong_optical_flow_preserves_a_moving_diffuse_texture() {
    run(Scene::Lambertian);
}

#[test]
#[ignore = "requires Metal and original DXC interpolation variant"]
fn original_interpolation_reproduces_textured_mirror_error_despite_exact_optical_flow() {
    run(Scene::TexturedMirror);
}

#[test]
#[ignore = "requires Metal and original DXC interpolation variant"]
fn small_illumination_change_does_not_select_aliased_optical_flow() {
    run(Scene::AliasedDiffuseIllumination);
}
