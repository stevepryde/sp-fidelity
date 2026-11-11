//! Every observable backend event and initialization byte against AMD's host.
#[path = "framegen_support/opticalflow.rs"]
mod driver;
mod framegen_support;
use driver::run_rust;
use framegen_support::*;
use sp_fidelity::opticalflow::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::OPTICALFLOW;

fn case(name: &str, caps: FfxDeviceCapabilities, flags: u32, size: [u32; 2], rejected: bool) {
    let mut words = vec![flags, size[0], size[1], 36];
    for i in 0..36 {
        let present = if rejected && i < 4 { 15 ^ (1 << i) } else { 15 };
        let render = if rejected && i == 5 {
            [size[0] + 1, size[1]]
        } else if i % 3 == 0 {
            [size[0] * 3 / 4, size[1] * 3 / 4]
        } else {
            size
        };
        words.extend([
            present,
            render[0],
            render[1],
            u32::from(i == 12 || i == 13),
            i % 3,
            (0.01f32 + i as f32 * 0.002).to_bits(),
            (1000.0f32 + i as f32 * 10.0).to_bits(),
        ]);
    }
    compare(&OPTICALFLOW, name, caps, &words, run_rust);
}

#[test]
fn temporal_resets_and_resolution_changes_match_sdk() {
    case(
        "temporal",
        capabilities(false, true),
        0,
        [1920, 1080],
        false,
    );
}

#[test]
fn wave64_and_texture1d_match_sdk() {
    case(
        "wave64",
        capabilities(true, true),
        FFX_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE,
        [1283, 719],
        false,
    );
}

#[test]
fn fp32_and_rejected_dispatches_match_sdk() {
    case(
        "fp32-rejected",
        capabilities(false, false),
        0,
        [65, 33],
        true,
    );
}
