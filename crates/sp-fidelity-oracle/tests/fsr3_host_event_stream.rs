//! Composite FSR3 against AMD's unchanged C++: resource lifetime and rings,
//! constituent scheduling, staged constants, configuration and callback dispatch.
#[path = "support/fsr3.rs"]
mod support;
use sp_fidelity::fsr3::*;
use support::*;

struct Case {
    flags: u32,
    operations: Vec<Vec<u32>>,
}
impl Case {
    fn words(self) -> Vec<u32> {
        let mut words = vec![
            self.flags,
            128,
            72,
            192,
            108,
            192,
            108,
            self.operations.len() as u32,
        ];
        words.extend(self.operations.into_iter().flatten());
        words
    }
    fn push(&mut self, op: Vec<u32>) {
        self.operations.push(op);
    }
}
fn id(words: &mut Vec<u32>, frame_id: u64) {
    words.extend([frame_id as u32, (frame_id >> 32) as u32]);
}
fn scalars(words: &mut Vec<u32>, values: &[f32]) {
    words.extend(values.iter().map(|v| v.to_bits()));
}
fn upscale(frame_id: u64, index: u32) -> Vec<u32> {
    let mut w = vec![0];
    id(&mut w, frame_id);
    let (width, height) = match index % 3 {
        0 => (128, 72),
        1 => (112, 64),
        _ => (96, 54),
    };
    // Nonzero upscaleSize deliberately differs from maxUpscaleSize: the
    // original composite drops this field when calling its upscaler.
    w.extend([index % 8, width, height, 160, 90]);
    scalars(&mut w, &[0.125, -0.25, width as f32, height as f32]);
    w.push(index % 2);
    scalars(
        &mut w,
        &[
            (index % 7) as f32 / 6.0,
            8.0 + index as f32,
            1.0 + (index % 4) as f32 / 8.0,
        ],
    );
    w.push(u32::from(index == 0 || index == 5));
    scalars(&mut w, &[0.1, 1000.0, 1.0, 1.0]);
    w.push(if index % 4 == 2 {
        FFX_FSR3_UPSCALER_FLAG_DRAW_DEBUG_VIEW
    } else {
        0
    });
    w
}
fn prepare(frame_id: u64, index: u32) -> Vec<u32> {
    let mut w = vec![1];
    id(&mut w, frame_id);
    // Prepare caches camera information even when the upscaler already
    // produced its textures; those cached values feed the later callback.
    w.extend([128 - index % 3 * 16, 72 - index % 3 * 8]);
    scalars(
        &mut w,
        &[
            -0.125,
            0.375,
            128.0,
            72.0,
            11.0 + index as f32,
            0.2 + index as f32 / 100.0,
            1500.0 + index as f32,
            0.5 + index as f32 / 10.0,
            1.1 + index as f32 / 100.0,
        ],
    );
    w
}
fn configure(
    frame_id: u64,
    flags: u32,
    enabled: bool,
    asynchronous: bool,
    hudless: bool,
) -> Vec<u32> {
    let mut w = vec![2];
    id(&mut w, frame_id);
    w.extend([
        flags,
        u32::from(enabled),
        u32::from(asynchronous),
        u32::from(frame_id & 1 != 0),
        u32::from(hudless),
        8,
        6,
        176,
        96,
    ]);
    w
}
fn generate(frame_id: u64, index: u32) -> Vec<u32> {
    let mut w = vec![3];
    id(&mut w, frame_id);
    w.extend([u32::from(index == 0 || index == 5), index % 3]);
    scalars(&mut w, &[0.01, 1000.0]);
    w.extend([8, 6, 176, 96]);
    w
}
fn reactive(index: u32) -> Vec<u32> {
    let mut w = vec![4, 128, 72];
    scalars(&mut w, &[0.7, 0.2, 0.9]);
    w.push(index % 16);
    w
}

fn upscaling_only() -> Case {
    let mut case = Case {
        flags: FFX_FSR3_ENABLE_UPSCALING_ONLY | FFX_FSR3_ENABLE_AUTO_EXPOSURE,
        operations: vec![vec![5]],
    };
    for index in 0..9 {
        case.push(upscale(0x1_0000_0000 + u64::from(index), index));
        if index % 3 == 1 {
            case.push(reactive(index));
        }
    }
    case.push(vec![5]);
    case
}

fn synchronous() -> Case {
    let mut case = Case {
        flags: FFX_FSR3_ENABLE_DYNAMIC_RESOLUTION,
        operations: vec![vec![5]],
    };
    let ids = [0, 1, 4, 5, 0x1_0000_0002, 0x1_0000_0003, 12, 13];
    for (index, frame_id) in ids.into_iter().enumerate() {
        let index = index as u32;
        let flags = match index % 4 {
            0 => 0,
            1 => FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_TEAR_LINES,
            2 => FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW,
            _ => FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_PACING_LINES,
        };
        case.push(configure(
            frame_id,
            flags,
            true,
            false,
            !index.is_multiple_of(2),
        ));
        case.push(upscale(frame_id, index));
        case.push(prepare(frame_id, index));
        case.push(generate(frame_id, index));
        if index == 3 {
            case.push(reactive(index));
        }
    }
    case.push(configure(14, 0, false, false, false));
    case.push(generate(14, 8)); // The SDK's disabled global callback returns INVALID_POINTER.
    case.push(vec![5]);
    case
}

fn asynchronous() -> Case {
    let mut case = Case {
        flags: FFX_FSR3_ENABLE_ASYNC_WORKLOAD_SUPPORT
            | FFX_FSR3_ENABLE_HIGH_DYNAMIC_RANGE
            | FFX_FSR3_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
        operations: vec![vec![5]],
    };
    for pair in 0..6u32 {
        let first = 0x2_0000_0000 + u64::from(pair * 4);
        let second = first + 1;
        case.push(configure(
            first,
            if pair % 2 == 0 {
                FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW
                    | FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_PACING_LINES
            } else {
                FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_TEAR_LINES
            },
            true,
            true,
            pair % 2 == 0,
        ));
        // Two prepares before either callback expose parity-dependent cached
        // camera values and the SDK's current shared resource selection.
        for (frame_id, index) in [(first, pair * 2), (second, pair * 2 + 1)] {
            case.push(upscale(frame_id, index));
            case.push(prepare(frame_id, index));
        }
        case.push(generate(first, pair * 2));
        case.push(generate(second, pair * 2 + 1));
    }
    case.push(configure(0x2_0000_0018, 0, false, false, false));
    case.push(vec![5]);
    case
}

fn hdr(flags: u32) -> Case {
    let mut case = Case {
        flags,
        operations: vec![],
    };
    case.push(configure(1, 0, true, false, true));
    for index in 0..3u32 {
        let frame_id = u64::from(index) + 1;
        case.push(upscale(frame_id, index));
        case.push(prepare(frame_id, index));
        case.push(generate(frame_id, index));
    }
    case.push(configure(4, 0, false, false, false));
    case
}

#[test]
fn all_composite_modes_and_temporal_sequences_match_sdk() {
    // One process on each side preserves the SDK's process-global debug
    // color sequence across contexts; every constant remains compared.
    let cases = [
        upscaling_only(),
        synchronous(),
        asynchronous(),
        hdr(FFX_FSR3_ENABLE_HDR_UPSCALE_SDR_FINALOUTPUT),
        hdr(FFX_FSR3_ENABLE_SDR_UPSCALE_HDR_FINALOUTPUT),
    ];
    let mut words = vec![cases.len() as u32];
    for case in cases {
        words.extend(case.words());
    }
    compare("all-contexts", capabilities(true, 32, 64), &words);
}
