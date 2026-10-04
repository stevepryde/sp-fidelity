//! AMD's unchanged C++ host (`oracle/host.cpp`, an effect driver and the
//! vendored SDK sources), driven by a word stream.
use serde_json::Value;
use sp_fidelity::types::FfxDeviceCapabilities;
use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// An SDK effect the oracles drive.
pub struct Effect {
    /// The effect's name in `tools/compile_dxc_oracle.py`; its compiled
    /// variants are in `shaders/generated/<name>`.
    pub name: &'static str,
    /// Oracle pass names by SDK pass value, as in the compile tool's effect
    /// table: the pass directories of captures and the compiled shader stems.
    pub stages: &'static [&'static str],
    /// The effect's driver in `oracle/`, which defines `runEffect()`.
    pub driver: &'static str,
    /// The effect's SDK host sources, relative to the vendored `sdk/`.
    pub sources: &'static [&'static str],
    /// Include directories they need besides `include` and `src/shared`,
    /// relative to `sdk/`.
    pub includes: &'static [&'static str],
}

impl Effect {
    /// Directory of the compiled shader variants, one per permutation options.
    pub fn shaders(&self) -> PathBuf {
        root().join("shaders/generated").join(self.name)
    }
}

/// This crate's directory.
pub fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

/// The vendored SDK 1.1.4 `sdk/` tree of the `sp-fidelity` crate.
pub fn sdk() -> PathBuf {
    root().join("../sp-fidelity/vendor/sdk-1.1.4/sdk")
}

/// Build the C++ host of `effect` into `directory`; returns the executable and
/// the shader-binding table it reads: the DXC reflection of every compiled
/// (pass, permutation options) variant, as AMD's generated per-permutation
/// tables are.
pub fn build_cpp_host(directory: &Path, effect: &Effect) -> (PathBuf, PathBuf) {
    fs::create_dir_all(directory).unwrap();
    let executable = directory.join("cpp-host");
    let sdk = sdk();
    let mut build = Command::new(std::env::var("CXX").unwrap_or_else(|_| "clang++".into()));
    build
        .args([
            "-std=c++17",
            "-DFFX_GCC",
            "-fshort-wchar",
            "-Wno-c++11-narrowing",
            "-include",
        ])
        .arg(root().join("oracle/compat.h"))
        .arg("-I")
        .arg(root().join("oracle"))
        .arg("-I")
        .arg(sdk.join("include"))
        .arg("-I")
        .arg(sdk.join("src/shared"));
    for include in effect.includes {
        build.arg("-I").arg(sdk.join(include));
    }
    build
        .arg(root().join("oracle/host.cpp"))
        .arg(root().join("oracle").join(effect.driver));
    // `oracle/host.cpp` records messages in place of `src/shared/ffx_message.cpp`.
    for file in effect
        .sources
        .iter()
        .chain(&["src/shared/ffx_object_management.cpp"])
    {
        build.arg(sdk.join(file));
    }
    // Compiled at the optimization of the port it is compared with: LLVM
    // turns the SDK's cosf and sinf of one angle (ffx_fsr2.cpp:1003) into
    // one sincos call, 1 ulp away, only when optimizing, in Rust and C++
    // alike.
    // `compat.h`'s wide-string loops must not become calls to the macOS wide
    // CRT, whose wchar_t is 32-bit where `-fshort-wchar` makes it 16-bit.
    if !cfg!(debug_assertions) {
        build.args(["-O2", "-fno-builtin-wcslen"]);
    }
    let output = build
        .arg("-o")
        .arg(&executable)
        .output()
        .expect("the C++ host oracle needs clang++ or CXX");
    assert!(
        output.status.success(),
        "C++ reference build failed:\n{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let bindings = directory.join("shader-bindings.txt");
    fs::write(&bindings, shader_bindings(effect)).unwrap();
    (executable, bindings)
}

/// `stage options kind register arrayIndex name` per reflected resource. A
/// variant's reflection also serves the forced-wave64 table of the same
/// options, whose DXC reflection is the same.
fn shader_bindings(effect: &Effect) -> String {
    let mut text = String::new();
    let mut variants: Vec<_> = fs::read_dir(effect.shaders())
        .unwrap_or_else(|e| panic!("{}: {e}", effect.shaders().display()))
        .map(|entry| entry.unwrap().path())
        .filter(|path| path.join("manifest.json").exists())
        .collect();
    variants.sort();
    for variant in variants {
        let manifest: Value =
            serde_json::from_slice(&fs::read(variant.join("manifest.json")).unwrap()).unwrap();
        assert_eq!(
            manifest["stages"],
            serde_json::json!(effect.stages),
            "{} was compiled for other passes",
            variant.display()
        );
        let wave64 = manifest["forceWave64Flag"].as_u64().unwrap();
        for (pass, record) in manifest["passes"].as_object().unwrap() {
            let stage = effect.stages.iter().position(|s| s == pass).unwrap();
            let options = record["permutationOptions"].as_u64().unwrap();
            let tables = if wave64 == 0 {
                vec![options]
            } else {
                vec![options, options | wave64]
            };
            let path = variant.join(format!("{pass}.reflection.json"));
            let reflection: Value = serde_json::from_slice(&fs::read(path).unwrap()).unwrap();
            for r in reflection["resources"].as_array().unwrap() {
                let kind = match (
                    r["kind"].as_str().unwrap(),
                    r["registerClass"].as_str().unwrap(),
                ) {
                    ("texture", "t") => "srv",
                    ("texture", "u") => "uav",
                    ("buffer", "u") => "buffer",
                    ("constant_buffer", "b") => "cb",
                    ("sampler", "s") => continue,
                    other => panic!("new original shader resource shape: {other:?}"),
                };
                for options in &tables {
                    let _ = writeln!(
                        text,
                        "{stage} {options} {kind} {} {} {}",
                        r["register"],
                        r["arrayIndex"],
                        r["name"].as_str().unwrap()
                    );
                }
            }
        }
    }
    text
}

/// Run the C++ host: `capabilities`, then the effect driver's `words`.
/// `init_data` receives AMD's initialization data. Returns its event stream,
/// one JSON array per line.
pub fn run_cpp_host(
    (executable, bindings): &(PathBuf, PathBuf),
    capabilities: &FfxDeviceCapabilities,
    words: &[u32],
    input: &Path,
    init_data: &Path,
) -> String {
    let c = capabilities;
    let stream: Vec<String> = [
        u32::from(c.fp16_supported),
        c.wave_lane_count_min,
        c.wave_lane_count_max,
        c.maximum_supported_shader_model as u32,
    ]
    .iter()
    .chain(words)
    .map(u32::to_string)
    .collect();
    // A file avoids blocking on a full child-output pipe while writing a long
    // parameter stream into the child's input pipe.
    fs::write(input, stream.join(" ")).unwrap();
    let output = Command::new(executable)
        .arg(bindings)
        .arg(init_data)
        .stdin(fs::File::open(input).unwrap())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "original C++ execution failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout).unwrap()
}
