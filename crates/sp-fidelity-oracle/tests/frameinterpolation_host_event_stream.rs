//! All contexts share one run so the SDK's global debug-color sequence is compared.
#[path = "framegen_support/frameinterpolation.rs"]
mod driver;
mod framegen_support;
use framegen_support::*;
use sp_fidelity::frameinterpolation::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::FRAMEINTERPOLATION;

#[test]
fn prepare_temporal_history_permutations_formats_and_async_match_sdk() {
    let mut words = vec![69];
    let mut context = |flags, render, display, formats, frames| {
        words.extend(
            driver::words(flags, render, display, formats, frames)
                .into_iter()
                .skip(1),
        );
    };
    context(
        0,
        [1280, 720],
        [1920, 1080],
        [FfxSurfaceFormat::R8G8B8A8Unorm; 2],
        24,
    );
    for flags in 0..64 {
        context(
            flags,
            [857, 481],
            [1283, 719],
            [FfxSurfaceFormat::R16G16B16A16Float; 2],
            8,
        );
    }
    context(
        FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT | FFX_FRAMEINTERPOLATION_ENABLE_HDR_COLOR_INPUT,
        [640, 360],
        [1280, 720],
        [
            FfxSurfaceFormat::R8G8B8A8Unorm,
            FfxSurfaceFormat::B8G8R8A8Unorm,
        ],
        25,
    );
    context(
        FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT
            | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED
            | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE
            | FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
            | FFX_FRAMEINTERPOLATION_ENABLE_JITTER_MOTION_VECTORS,
        [256, 128],
        [512, 256],
        [
            FfxSurfaceFormat::R16G16B16A16Float,
            FfxSurfaceFormat::R16G16B16A16Float,
        ],
        25,
    );
    // Rejected creates have no dispatch count: both hosts return immediately.
    for formats in [
        [
            FfxSurfaceFormat::Unknown,
            FfxSurfaceFormat::R16G16B16A16Float,
        ],
        [
            FfxSurfaceFormat::R16G16B16A16Float,
            FfxSurfaceFormat::R8G8B8A8Unorm,
        ],
    ] {
        words.extend([0, 640, 360, 1280, 720, formats[0] as u32, formats[1] as u32]);
    }
    compare(
        &FRAMEINTERPOLATION,
        "all-contexts",
        capabilities(true, true),
        &words,
        driver::run_rust,
    );
}
