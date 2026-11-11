//! The pacing oracle compiles AMD's unchanged moving-average template and the
//! arithmetic block of interpolationThread. Platform events/queues are supplied
//! by the harness; expected intervals come only from the retained C++.
use sp_fidelity_wgpu::presentation::pacing::{FramePacing, FramePacingTuning};
use std::{
    fs,
    io::Write,
    path::PathBuf,
    process::{Command, Stdio},
};

#[test]
fn pacing_matches_amd_cpp_for_warmup_jitter_hitches_resets_and_tuning() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..");
    let sdk = root.join(
        "crates/sp-fidelity/vendor/sdk-1.1.4/sdk/src/backends/dx12/FrameInterpolationSwapchain",
    );
    let helper = fs::read_to_string(sdk.join("FrameInterpolationSwapchainDX12_Helpers.h")).unwrap();
    let cpp = fs::read_to_string(sdk.join("FrameInterpolationSwapchainDX12.cpp")).unwrap();
    let template = &helper[helper
        .find("template <const int Size, typename Type = double>")
        .unwrap()..];
    let start = cpp.find("const double deltaQpc =").unwrap();
    let end = start + cpp[start..].find("// schedule presents").unwrap();
    let arithmetic = &cpp[start..end];
    let directory = root.join("target/presentation-pacing-oracle");
    fs::create_dir_all(&directory).unwrap();
    let source = format!(
        r#"
#include <cmath>
#include <cstdint>
#include <iostream>
{template}
struct PacingData {{ enum FrameType {{ Interpolated_1, Real }}; struct Frame {{ int64_t presentQpcDelta; }} frames[2]; }};
struct Presenter {{ bool resetTimer; double safetyMarginInSec; double varianceFactor; }};
int main() {{
    int64_t qpcFrequency, previousQpc=0,previousDelta=0,currentQpc;
    std::cin >> qpcFrequency;
    SimpleMovingAverage<10,double> frameTime;
    Presenter state; auto* presenter=&state;
    float safety,variance;
    while(std::cin >> currentQpc >> state.resetTimer >> safety >> variance) {{
        state.safetyMarginInSec=static_cast<double>(safety)/1000.0;
        state.varianceFactor=static_cast<double>(variance);
        PacingData entry;
        {arithmetic}
        std::cout << entry.frames[PacingData::Real].presentQpcDelta << '\n';
    }}
}}
"#
    );
    let source_path = directory.join("pacing.cpp");
    let executable = directory.join("pacing");
    fs::write(&source_path, source).unwrap();
    let compile = Command::new(std::env::var("CXX").unwrap_or_else(|_| "clang++".into()))
        .args(["-std=c++17", "-O0"])
        .arg(&source_path)
        .arg("-o")
        .arg(&executable)
        .output()
        .unwrap();
    assert!(
        compile.status.success(),
        "{}",
        String::from_utf8_lossy(&compile.stderr)
    );
    for frequency in [10_000_000, 1_000_000_000, 24_000_000, 1_000_000_001] {
        let mut ticks = 1i64;
        let mut input = format!("{frequency}\n");
        let mut expected = Vec::new();
        let mut port = FramePacing::new(frequency);
        for frame in 0..200 {
            let seconds = match frame {
                0..=24 => 1. / 60.,
                25..=69 => [0.008, 0.018, 0.012, 0.025][frame % 4],
                70 => 0.12,
                _ => 1. / 120.,
            };
            // Exercise the 100 ms discontinuity just below, at and above the
            // boundary, after enough regular samples to distinguish a reset.
            ticks += match frame {
                140 => frequency / 10 - 1,
                160 => frequency / 10,
                180 => frequency / 10 + 1,
                _ => (seconds * frequency as f64) as i64,
            };
            let reset = frame == 102;
            let tuning = FramePacingTuning {
                safety_margin_ms: if frame < 120 { 0.1 } else { 0.75 },
                variance_factor: if frame < 120 { 0.1 } else { 0.25 },
                ..Default::default()
            };
            input += &format!(
                "{ticks} {} {} {}\n",
                u8::from(reset),
                tuning.safety_margin_ms,
                tuning.variance_factor
            );
            expected.push(port.sample(ticks, reset, tuning));
        }
        let mut process = Command::new(&executable)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .unwrap();
        process
            .stdin
            .take()
            .unwrap()
            .write_all(input.as_bytes())
            .unwrap();
        let output = process.wait_with_output().unwrap();
        assert!(output.status.success());
        let original: Vec<i64> = String::from_utf8(output.stdout)
            .unwrap()
            .lines()
            .map(|s| s.parse().unwrap())
            .collect();
        assert_eq!(expected, original, "frequency {frequency}");
    }
}
