//! AMD's unchanged FSR 3.1 host against the Rust host: complete backend event
//! streams, staged constants and initialization bytes, including destruction.
#[path = "support/fsr3upscaler.rs"]
mod support;
use sp_fidelity::fsr3upscaler::*;
use support::*;

#[test]
fn helpers_match_the_sdk() {
    let mut words = vec![0];
    let displays = [(1920, 1080), (3840, 2160), (1283, 719), (1, 1), (7, 3)];
    words.push((displays.len() * 5) as u32);
    for mode in 0..=4 {
        for (width, height) in displays {
            words.extend([mode, width, height]);
        }
    }
    let phases = [
        (1280, 1920),
        (1129, 1920),
        (960, 1920),
        (640, 1920),
        (1920, 1920),
        (857, 1283),
        (1, 3),
        (3, 1),
    ];
    words.push(phases.len() as u32);
    for (render, display) in phases {
        words.extend([render, display]);
    }
    let mut jitters = Vec::new();
    for phase_count in [18, 23, 32, 72, 8, 1] {
        for index in [0, 1, 5, 17, 18, 23, 31, 32, 71, 72, 73, 1000, 12345] {
            jitters.push((index, phase_count));
        }
    }
    jitters.extend([(-1, 18), (-19, 18), (0, 0), (5, 0), (5, -4), (i32::MAX, 72)]);
    words.push(jitters.len() as u32);
    for (index, phase_count) in jitters {
        words.extend([index as u32, phase_count as u32]);
    }
    compare("helpers", rdna(), &words);
}

#[test]
fn context_variants_and_temporal_sequences_match_the_sdk() {
    // Native AA, all quality presets, all initialization flags and the
    // device-dependent LUT/wave64/FP16 table selections.
    let all = FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE
        | FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
        | FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
        | FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED
        | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE
        | FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE
        | FFX_FSR3UPSCALER_ENABLE_DYNAMIC_RESOLUTION
        | FFX_FSR3UPSCALER_ENABLE_TEXTURE1D_USAGE
        | FFX_FSR3UPSCALER_ENABLE_DEBUG_CHECKING;
    for (name, caps, flags) in [
        (
            "wgpu-hdr-auto",
            wgpu(),
            FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE | FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE,
        ),
        ("rdna-default", rdna(), 0),
        ("wave64-all", wave64_fp32(), all),
        (
            "wave32-dynamic",
            wave32_fp32(),
            FFX_FSR3UPSCALER_ENABLE_DYNAMIC_RESOLUTION
                | FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
        ),
    ] {
        let ops = (0..120)
            .map(|index| {
                if index % 21 == 20 {
                    return Op::Generate(generate((857, 481), index as u32 % 16));
                }
                let render = match index % 7 {
                    0 => RenderSize::Quality(FfxFsr3UpscalerQualityMode::NativeAa),
                    1 => RenderSize::Quality(FfxFsr3UpscalerQualityMode::Quality),
                    2 => RenderSize::Quality(FfxFsr3UpscalerQualityMode::Balanced),
                    3 => RenderSize::Quality(FfxFsr3UpscalerQualityMode::Performance),
                    4 => RenderSize::Quality(FfxFsr3UpscalerQualityMode::UltraPerformance),
                    _ => RenderSize::Explicit(641 + index as u32, 359 + index as u32),
                };
                let mut f = frame(index, render);
                f.present |= match index % 4 {
                    0 => EXPOSURE | REACTIVE,
                    1 => TRANSPARENCY_AND_COMPOSITION | SHARED,
                    2 => DILATED_DEPTH,
                    _ => DILATED_MOTION_VECTORS | RECONSTRUCTED_DEPTH,
                };
                f.sharpen = index % 3 != 0;
                f.sharpness = (index % 11) as f32 / 10.0;
                f.reset = index == 59 || index == 60;
                f.flags = if index % 9 == 4 {
                    FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW
                } else {
                    0
                };
                // Zero requests maxUpscaleSize; explicit sizes exercise changes.
                if index % 5 == 1 {
                    f.upscale = (1101, 617);
                }
                if flags & FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED != 0 {
                    f.camera_near = f32::MAX;
                    f.camera_far = 0.1;
                }
                if index % 13 == 0 {
                    f.pre_exposure = 0.0;
                    f.view_space_to_meters = 0.0;
                }
                Op::Dispatch(f)
            })
            .collect();
        compare(
            name,
            caps,
            &Case {
                flags,
                max_render: (1283, 719),
                display: (1283, 719),
                color: (1296, 728),
                ops,
            }
            .words(),
        );
    }
}

#[test]
fn configuration_clamping_defaults_and_persistence_match_the_sdk() {
    let mut ops = Vec::new();
    let mut index = 0;
    for key in [
        FfxFsr3UpscalerConfigureKey::VelocityFactor,
        FfxFsr3UpscalerConfigureKey::ReactivenessScale,
        FfxFsr3UpscalerConfigureKey::ShadingChangeScale,
        FfxFsr3UpscalerConfigureKey::AccumulationAddedPerFrame,
        FfxFsr3UpscalerConfigureKey::MinDisocclusionAccumulation,
    ] {
        for value in [
            Some(-2.0),
            Some(-0.5),
            Some(0.0),
            Some(0.25),
            Some(2.5),
            None,
        ] {
            ops.push(Op::Configure(key, value));
            for _ in 0..2 {
                let mut f = frame(index, RenderSize::Explicit(128, 72));
                f.sharpen = index % 2 == 0;
                ops.push(Op::Dispatch(f));
                index += 1;
            }
        }
    }
    compare(
        "configuration",
        wgpu(),
        &Case {
            flags: 0,
            max_render: (128, 72),
            display: (192, 108),
            color: (128, 72),
            ops,
        }
        .words(),
    );
}

#[test]
fn debug_messages_and_rejected_dispatches_match_the_sdk() {
    let ops = (0..56)
        .map(|index| {
            let mut f = frame(index, RenderSize::Explicit(64, 36));
            f.camera_far = f32::MAX;
            match index % 14 {
                0 => f.present = 0,
                1 => f.present |= EXPOSURE,
                2 => f.jitter = Jitter::Explicit(1.5, -2.0),
                3 => f.motion_vector_scale = (5000.0, 0.0),
                4 => f.render = RenderSize::Explicit(0, 36),
                5 => f.render = RenderSize::Explicit(4000, 36),
                6 => f.sharpness = 1.5,
                7 => {
                    f.sharpness = -0.25;
                    f.frame_time_delta = 0.5;
                }
                8 => {
                    f.pre_exposure = 0.0;
                    f.frame_time_delta = -5.0;
                }
                9 => {
                    f.camera_near = 2000.0;
                    f.camera_far = 1000.0;
                }
                10 => f.camera_near = 0.01,
                11 => f.fov = 0.0,
                12 => f.fov = 3.5,
                _ => f.upscale = (4000, 2160),
            }
            Op::Dispatch(f)
        })
        .collect();
    compare(
        "debug",
        rdna(),
        &Case {
            flags: FFX_FSR3UPSCALER_ENABLE_DEBUG_CHECKING
                | FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE
                | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE,
            max_render: (64, 36),
            display: (96, 54),
            color: (64, 36),
            ops,
        }
        .words(),
    );
}
