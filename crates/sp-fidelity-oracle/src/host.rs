//! AMD's unchanged C++ host (`oracle/host.cpp`, an effect driver and the
//! vendored SDK sources), driven by a word stream.
use serde_json::Value;
use sp_fidelity::types::{FfxDeviceCapabilities, FfxEffect};
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
    build_cpp_composite_host(directory, effect, &[])
}

/// Build a composite SDK host with independently reflected constituent effects.
pub fn build_cpp_composite_host(
    directory: &Path,
    effect: &Effect,
    components: &[(FfxEffect, &Effect)],
) -> (PathBuf, PathBuf) {
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
    let reflected = if components.is_empty() {
        shader_bindings(effect)
    } else {
        components
            .iter()
            .map(|(id, component)| {
                shader_bindings(component)
                    .lines()
                    .map(|line| {
                        let (_, rest) = line.split_once(' ').unwrap();
                        format!("{} {rest}\n", *id as u32)
                    })
                    .collect::<String>()
            })
            .collect()
    };
    fs::write(&bindings, reflected).unwrap();
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
                    ("buffer", "t") => "srv-buffer",
                    ("constant_buffer", "b") => "cb",
                    ("sampler", "s") => continue,
                    other => panic!("new original shader resource shape: {other:?}"),
                };
                for options in &tables {
                    let _ = writeln!(
                        text,
                        "4294967295 {stage} {options} {kind} {} {} {}",
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

/// The words of `OpticalFlowSpdConstants` the SDK leaves uninitialized:
/// `pad0_`, `pad1_` and `pad2_` after `mips`, `numworkGroups`,
/// `workGroupOffset[2]` and `numworkGroupsOpticalFlowInputPyramid`
/// (`ffx_opticalflow.cpp:92-103`). The C++ host stages a stack copy whose
/// padding holds whatever the stack held, which varies with the build; no
/// shader reads it.
const OPTICALFLOW_SPD_PADDING: std::ops::Range<usize> = 5..8;

/// Sets the uninitialized padding words of every `OpticalFlowSpdConstants`
/// in a host event stream to zero, the port's value, so a comparison covers
/// every word the SDK initializes and only those.
///
/// A compute event names each constant buffer it binds (`cbOF_SPD`). A
/// `constants` event does not: optical flow's dispatch stages `cbOF` and then
/// `OpticalFlowSpdConstants` (`ffx_opticalflow.cpp:644-645`), and DXC drops
/// the SPD buffer from passes that do not read it, so the SPD buffer is the
/// `constants` event that follows the one whose words a later compute binds
/// as `cbOF`.
pub fn clear_constant_padding(events: &mut [Value]) {
    let clear = |words: &mut Value| {
        for word in &mut words.as_array_mut().expect("constant words")[OPTICALFLOW_SPD_PADDING] {
            *word = Value::from(0);
        }
    };
    for index in 0..events.len() {
        if events[index][0] == "compute" {
            for cb in events[index][6].as_array_mut().expect("compute constants") {
                if cb[0] == "cbOF_SPD" {
                    clear(&mut cb[1]);
                }
            }
            continue;
        }
        if events[index][0] != "constants"
            || events
                .get(index + 1)
                .is_none_or(|next| next[0] != "constants")
        {
            continue;
        }
        let staged = &events[index][1];
        let of_constants = events[index + 1..]
            .iter()
            .filter(|event| event[0] == "compute")
            .flat_map(|event| event[6].as_array().into_iter().flatten())
            .find(|cb| cb[0] == "cbOF")
            .is_some_and(|cb| cb[1] == *staged);
        if of_constants {
            clear(&mut events[index + 1][1]);
        }
    }
}
