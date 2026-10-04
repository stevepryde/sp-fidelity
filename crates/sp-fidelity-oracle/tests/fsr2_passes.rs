//! FSR2 passes: the port's WGSL against the DXC-compiled unchanged HLSL on
//! Metal, from identical inputs and constant buffers ([`pass`]). RCAS and
//! accumulate run their WGSL directly ([`pass::run`]); the other passes run
//! through the wgpu backend ([`pass::run_backend`]). Accumulate and the
//! backend passes take the constant buffers and dimensions AMD's unchanged
//! C++ host computes for each permutation's context. They need Metal,
//! clang++ and the variants in `shaders/generated/fsr2`, and are selected
//! explicitly:
//!
//! ```sh
//! cargo test -p sp-fidelity-oracle --release --test fsr2_passes -- --ignored --nocapture
//! ```
use serde_json::Value;
use sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index;
use sp_fidelity::blob_accessors::fsr2_shaderblobs::fsr2_get_permutation_blob_by_index;
use sp_fidelity::fsr2::private::*;
use sp_fidelity::fsr2::*;
use sp_fidelity::shaders::ffx_get_wgsl_source;
use sp_fidelity::types::*;
use sp_fidelity_oracle::host::{build_cpp_host, root, run_cpp_host};
use sp_fidelity_oracle::pass::{self, Binding, Job, Pipeline, Resource};
use sp_fidelity_oracle::{Effect, compare, gpu};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fmt::Write as _;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::sync::OnceLock;
use std::sync::atomic::{AtomicUsize, Ordering};

/// FSR2 as the oracles drive it: passes in `FfxFsr2Pass` order (ffx_fsr2.h)
/// under the compile tool's names. `driver`, `sources` and `includes` build
/// the C++ host oracle.
const FSR2: Effect = Effect {
    name: "fsr2",
    stages: &[
        "fsr2_depth_clip",
        "fsr2_reconstruct_previous_depth",
        "fsr2_lock",
        "fsr2_accumulate",
        "fsr2_accumulate_sharpen",
        "fsr2_rcas",
        "fsr2_compute_luminance_pyramid",
        "fsr2_generate_reactive",
        "fsr2_tcr_autogenerate",
    ],
    driver: "fsr2_host.cpp",
    sources: &["src/components/fsr2/ffx_fsr2.cpp"],
    includes: &["src/components/fsr2"],
};

/// `FFX_FSR2_PASS_RCAS`.
const FFX_FSR2_PASS_RCAS: u32 = 5;

/// The `PermutationKey` bits of every FSR2 pass, in the order
/// `POPULATE_PERMUTATION_KEY` sets them from the permutation options
/// (ffx_fsr2_shaderblobs.cpp:68-75, ffx_fsr2_private.h:36-41).
const FSR2_KEY_OPTIONS: &[&str] = &[
    "FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE",
    "FFX_FSR2_OPTION_HDR_COLOR_INPUT",
    "FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS",
    "FFX_FSR2_OPTION_JITTERED_MOTION_VECTORS",
    "FFX_FSR2_OPTION_INVERTED_DEPTH",
    "FFX_FSR2_OPTION_APPLY_SHARPENING",
];

/// The RCAS blob for permutation options: the 32-bit, non-wave64 table
/// (ffx_fsr2_shaderblobs.cpp:237-272 outside `_GAMING_XBOX`).
fn rcas_blob(options: u32) -> FfxShaderBlob {
    FfxShaderBlob {
        shader_name: "ffx_fsr2_rcas_pass",
        permutation: FfxShaderPermutation {
            wave64: false,
            fp16: false,
            key_index: options & 0x3f,
            key_options: FSR2_KEY_OPTIONS,
        },
        ..Default::default()
    }
}

/// `cbRCAS` for each `FfxFsr2DispatchDescription::sharpness`, from AMD's
/// unchanged host code (`oracle/fsr2_rcas_constants.cpp`).
fn rcas_constants(sharpness: &[f32]) -> Vec<Vec<u32>> {
    static TOOL: OnceLock<PathBuf> = OnceLock::new();
    let tool = TOOL.get_or_init(|| {
        let sdk = sp_fidelity_oracle::host::sdk();
        let executable = root().join("target/fsr2-rcas-constants");
        fs::create_dir_all(root().join("target")).unwrap();
        let build = Command::new(std::env::var("CXX").unwrap_or_else(|_| "clang++".into()))
            .args([
                "-std=c++17",
                "-DFFX_GCC",
                "-fshort-wchar",
                "-Wno-c++11-narrowing",
                "-include",
            ])
            .arg(root().join("oracle/compat.h"))
            .arg("-I")
            .arg(sdk.join("include"))
            .arg("-I")
            .arg(sdk.join("src/shared"))
            .arg(root().join("oracle/fsr2_rcas_constants.cpp"))
            .arg("-o")
            .arg(&executable)
            .output()
            .expect("clang++");
        assert!(
            build.status.success(),
            "RCAS constants build: {}",
            String::from_utf8_lossy(&build.stderr)
        );
        executable
    });
    let output = Command::new(tool)
        .args(sharpness.iter().map(|s| s.to_bits().to_string()))
        .output()
        .unwrap();
    assert!(output.status.success());
    String::from_utf8(output.stdout)
        .unwrap()
        .lines()
        .map(|line| line.split(' ').map(|w| w.parse().unwrap()).collect())
        .collect()
}

/// `cbFSR2` (`Fsr2Constants`, ffx_fsr2_private.h:47-69: 31 words). RCAS reads
/// only `preExposure`, which the host sets as ffx_fsr2.cpp:1153 does; every
/// other word is distinct, so reading the wrong member shows.
fn fsr2_constants(display: [u32; 2], pre_exposure: f32, frame: usize) -> Vec<u32> {
    let [width, height] = display.map(|v| i32::try_from(v).unwrap());
    let render = [(width * 2 / 3).max(1), (height * 2 / 3).max(1)];
    let ints = [
        render[0],
        render[1],
        width,
        height,
        width,
        height,
        render[0],
        render[1],
        (width / 32).max(1),
        (height / 32).max(1),
        4,
        i32::try_from(frame).unwrap(),
    ];
    let pre = if pre_exposure != 0.0 {
        pre_exposure
    } else {
        1.0
    };
    let floats = [
        0.0, -0.1, 1.2, 0.7, 0.25, -0.375, 0.5, -0.5, 0.66, 0.66, 0.01, -0.02, pre, 3.5, 0.9, 8.0,
        0.016, 0.75, 1.0,
    ];
    ints.iter()
        .map(|v| v.cast_unsigned())
        .chain(floats.iter().map(|v: &f32| v.to_bits()))
        .collect()
}

/// A deterministic xorshift generator.
struct Random(u32);

impl Random {
    fn next(&mut self) -> u32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 17;
        self.0 ^= self.0 << 5;
        self.0
    }

    /// Non-negative binary16 bits up to 16, subnormals and zero included.
    fn half(&mut self) -> u16 {
        let bits = self.next();
        (u16::try_from(bits % 20).unwrap() << 10) | u16::try_from(bits >> 22).unwrap()
    }
}

/// RGBA16F colour with black and flat neighbourhoods, whose zero and equal
/// ring minima and maxima reach RCAS's divisions by zero.
fn rcas_input(width: u32, height: u32, seed: u32) -> Vec<u8> {
    let mut random = Random(seed | 1);
    let mut bytes = Vec::new();
    for y in 0..height {
        for x in 0..width {
            let texel: [u16; 4] = match (x / 4 + y / 4 + seed) % 7 {
                0 => [0; 4],
                1 => [0x3c00, 0x3800, 0x3400, 0x3c00],
                _ => [random.half(), random.half(), random.half(), random.half()],
            };
            bytes.extend(texel.iter().flat_map(|h| h.to_le_bytes()));
        }
    }
    bytes
}

/// One RCAS dispatch's parameters.
struct Frame {
    sharpness: f32,
    exposure: f32,
    pre_exposure: f32,
}

const FRAMES: &[Frame] = &[
    Frame {
        sharpness: 0.0,
        exposure: 0.0,
        pre_exposure: 1.0,
    },
    Frame {
        sharpness: 0.2,
        exposure: 0.7,
        pre_exposure: 0.0,
    },
    Frame {
        sharpness: 0.5,
        exposure: 1.0,
        pre_exposure: 2.5,
    },
    Frame {
        sharpness: 0.8,
        exposure: 0.35,
        pre_exposure: 0.5,
    },
    Frame {
        sharpness: 1.0,
        exposure: 3.0,
        pre_exposure: 1.7,
    },
];

/// Run the RCAS frames at `display` for `options`; returns the comparison.
fn rcas_case(gpu: &gpu::Gpu, options: u32, display: [u32; 2]) -> compare::Comparison {
    let [width, height] = display;
    let directory = gpu::case_directory(&format!("fsr2-rcas-{options:#04x}-{width}x{height}"));
    // RCAS reads FSR2_InternalUpscaled (ffx_fsr2.cpp:1112), writes the
    // application's output, and reads its exposure (or the SDK's 1x1 default).
    let resources = [
        Resource {
            name: "FSR2_InternalUpscaled1",
            format: FfxSurfaceFormat::R16G16B16A16Float,
            width,
            height,
            mips: 1,
            created: Some(
                FFX_RESOURCE_USAGE_RENDERTARGET
                    | FFX_RESOURCE_USAGE_UAV
                    | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            ),
        },
        Resource {
            name: "Exposure",
            format: FfxSurfaceFormat::R32G32Float,
            width: 1,
            height: 1,
            mips: 1,
            created: None,
        },
        Resource {
            name: "Output",
            format: FfxSurfaceFormat::R16G16B16A16Float,
            width,
            height,
            mips: 1,
            created: None,
        },
    ];
    let pipeline = Pipeline {
        pass: FFX_FSR2_PASS_RCAS,
        options,
        blob: rcas_blob(options),
        // ffx_fsr2.cpp:398-407: Fsr2Constants and Fsr2SecondaryUnion words.
        root_constants: vec![31, 6],
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
    let rcas = rcas_constants(&FRAMES.iter().map(|f| f.sharpness).collect::<Vec<_>>());
    // The output holds 7.0 before each dispatch (alpha included, which RCAS
    // writes as 1), so a texel the port leaves unwritten differs.
    let sentinel: Vec<u8> = (0..width * height)
        .flat_map(|_| [0x4700u16; 4].map(u16::to_le_bytes))
        .flatten()
        .collect();
    let jobs: Vec<Job> = FRAMES
        .iter()
        .zip(rcas)
        .enumerate()
        .map(|(frame, (parameters, rcas))| Job {
            bindings: vec![
                Binding {
                    uav: false,
                    name: "r_input_exposure",
                    resource: "Exposure",
                    mip: 0,
                },
                Binding {
                    uav: false,
                    name: "r_rcas_input",
                    resource: "FSR2_InternalUpscaled1",
                    mip: 0,
                },
                Binding {
                    uav: true,
                    name: "rw_upscaled_output",
                    resource: "Output",
                    mip: 0,
                },
            ],
            constants: vec![
                (
                    "cbFSR2",
                    fsr2_constants(display, parameters.pre_exposure, frame),
                ),
                ("cbRCAS", rcas),
            ],
            contents: HashMap::from([
                (
                    "FSR2_InternalUpscaled1",
                    rcas_input(
                        width,
                        height,
                        0x9e37_79b9 ^ (u32::try_from(frame).unwrap() << 8),
                    ),
                ),
                (
                    "Exposure",
                    [parameters.exposure, 0.5]
                        .iter()
                        .flat_map(|v| v.to_le_bytes())
                        .collect(),
                ),
                ("Output", sentinel.clone()),
            ]),
            // ffx_fsr2.cpp:1310-1313.
            dimensions: [width.div_ceil(16), height.div_ceil(16), 1],
        })
        .collect();
    pass::run(gpu, &FSR2, &directory, &resources, &pipeline, &jobs);
    gpu::replay(&directory, &FSR2);
    let comparison = compare::compare(&directory, FSR2.stages, &|_| {
        Err("RCAS has no documented difference".into())
    });
    println!("{}: {}", directory.display(), comparison.summary());
    assert_eq!(
        comparison.dumps.get("fsr2_rcas").map(|d| d.0),
        Some(FRAMES.len()),
        "one output per frame"
    );
    comparison
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 RCAS variants"]
fn rcas_matches_the_hlsl_in_every_permutation() {
    let gpu = gpu::Gpu::new(false, None);
    let mut failures = Vec::new();
    for options in 0..64 {
        let sizes: &[[u32; 2]] = if options == 0x04 {
            &[[1, 1], [16, 16], [37, 23], [130, 67], [1920, 1080]]
        } else {
            &[[1, 1], [16, 16], [37, 23], [130, 67]]
        };
        for &display in sizes {
            let comparison = rcas_case(&gpu, options, display);
            if !comparison.accepted() {
                failures.push(format!("{options:#04x} {display:?}"));
            }
        }
    }
    assert!(failures.is_empty(), "RCAS differs: {failures:?}");
}

// ---- Permutations and AMD's C++ host ----------------------------------------

/// Permutation options of a pass: the key bits (`FSR2_SHADER_PERMUTATION_*`,
/// ffx_fsr2_private.h) and `ALLOW_FP16`.
const LANCZOS: u32 = FSR2_SHADER_PERMUTATION_USE_LANCZOS_TYPE;
const HDR: u32 = FSR2_SHADER_PERMUTATION_HDR_COLOR_INPUT;
const LOW_RES_MV: u32 = FSR2_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS;
const JITTERED_MV: u32 = FSR2_SHADER_PERMUTATION_JITTER_MOTION_VECTORS;
const INVERTED_DEPTH: u32 = FSR2_SHADER_PERMUTATION_DEPTH_INVERTED;
const SHARPEN: u32 = FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING;
const FP16: u32 = FSR2_SHADER_PERMUTATION_ALLOW_FP16;

/// AMD's unchanged C++ host, built once. Its binding table is the DXC
/// reflection of the compiled variants (`host.rs`), and the SDK creates every
/// pass's pipeline: a (pass, options) without a compiled variant (another
/// pass's permutations) reuses the reflection of the same pass at other
/// options, which only names its bindings: the constant buffers the host
/// stages do not depend on it.
fn cpp_host() -> &'static (PathBuf, PathBuf) {
    static HOST: OnceLock<(PathBuf, PathBuf)> = OnceLock::new();
    HOST.get_or_init(|| {
        let directory = PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join("fsr2-passes-host");
        let (executable, bindings) = build_cpp_host(&directory.join("build"), &FSR2);
        let text = fs::read_to_string(&bindings).unwrap();
        let mut tables: BTreeMap<(u32, u32), Vec<String>> = BTreeMap::new();
        for line in text.lines() {
            let mut words = line.splitn(3, ' ');
            let stage = words.next().unwrap().parse().unwrap();
            let options = words.next().unwrap().parse().unwrap();
            tables
                .entry((stage, options))
                .or_default()
                .push(words.next().unwrap().to_owned());
        }
        let mut extended = text.clone();
        for stage in 0..u32::try_from(FSR2.stages.len()).unwrap() {
            let template = tables
                .iter()
                .find(|((s, _), _)| *s == stage)
                .map(|(_, lines)| lines.clone())
                .expect("a compiled variant of every pass");
            for options in 0..256 {
                if !tables.contains_key(&(stage, options)) {
                    for line in &template {
                        let _ = writeln!(extended, "{stage} {options} {line}");
                    }
                }
            }
        }
        let extended_path = directory.join("shader-bindings-all-options.txt");
        fs::write(&extended_path, extended).unwrap();
        (executable, extended_path)
    })
}

fn leak(text: &str) -> &'static str {
    Box::leak(text.to_owned().into_boxed_str())
}

// ---- Accumulate --------------------------------------------------------------

/// `FFX_FSR2_PASS_ACCUMULATE` and `FFX_FSR2_PASS_ACCUMULATE_SHARPEN`.
const FFX_FSR2_PASS_ACCUMULATE: u32 = 3;
const FFX_FSR2_PASS_ACCUMULATE_SHARPEN: u32 = 4;

/// Dispatches AMD's host runs before a case's jobs, so that the first job
/// reads a history (the synthetic one the case supplies) rather than
/// resetting as the SDK's first execution does.
const WARMUP: usize = 2;
/// Accumulate jobs per case.
const JOBS: usize = 5;
const DISPATCHES: usize = WARMUP + JOBS;

/// `FfxFsr2DispatchDescription::preExposure` per dispatch (0 selects 1).
const PRE_EXPOSURE: [f32; DISPATCHES] = [1.0, 1.25, 1.0, 2.0, 0.0, 0.5, 0.5];
/// The application's exposure per dispatch (0 selects 1 in `Exposure()`).
const EXPOSURE: [f32; DISPATCHES] = [1.0, 1.0, 0.0, 1.1, 1.1, 0.9, 2.5];
/// `FSR2_AutoExposure` per dispatch.
const AUTO_EXPOSURE: [f32; DISPATCHES] = [1.0, 1.0, 0.9, 0.0, 1.05, 1.6, 0.4];

/// Display, render and maximum render sizes.
#[derive(Clone, Copy)]
struct Sizes {
    display: [u32; 2],
    render: [u32; 2],
    max_render: [u32; 2],
}

/// Upscale ratios 1.0 to 3.0 with odd sizes and partial 8x8 tiles, some with
/// a maximum render size above the render size.
const ACCUMULATE_SIZES: [Sizes; 4] = [
    Sizes {
        display: [37, 23],
        render: [37, 23],
        max_render: [37, 23],
    },
    Sizes {
        display: [67, 45],
        render: [45, 30],
        max_render: [48, 33],
    },
    Sizes {
        display: [58, 42],
        render: [29, 21],
        max_render: [29, 21],
    },
    Sizes {
        display: [99, 61],
        render: [33, 21],
        max_render: [36, 24],
    },
];

const FULL_HD: Sizes = Sizes {
    display: [1920, 1080],
    render: [1280, 720],
    max_render: [1280, 720],
};

/// Where the accumulate pass reads the exposure: the application's texture,
/// the SDK's default (`FSR2_DefaultExposure`, no application texture) or
/// `FSR2_AutoExposure` (`FFX_FSR2_ENABLE_AUTO_EXPOSURE`).
#[derive(Clone, Copy, Debug)]
enum ExposureSource {
    Application,
    Default,
    Auto,
}

/// One case: AMD's C++ host runs a context and `DISPATCHES` dispatches whose
/// accumulate pipeline has `options`; the accumulate jobs of the last `JOBS`
/// run through the port's WGSL and the DXC-compiled HLSL.
struct AccumulateCase {
    /// Permutation options (`FP16` included); `SHARPEN`
    /// selects `FFX_FSR2_PASS_ACCUMULATE_SHARPEN`.
    options: u32,
    sizes: Sizes,
    exposure: ExposureSource,
    /// A dispatch after the warm-up with `FfxFsr2DispatchDescription::reset`.
    reset: Option<usize>,
}

impl AccumulateCase {
    fn pass(&self) -> u32 {
        if self.options & SHARPEN == 0 {
            FFX_FSR2_PASS_ACCUMULATE
        } else {
            FFX_FSR2_PASS_ACCUMULATE_SHARPEN
        }
    }

    /// The context flags of the permutation (ffx_fsr2.cpp:371-388).
    fn flags(&self) -> u32 {
        let mut flags = 0;
        for (bit, flag, set) in [
            (HDR, FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE, true),
            (
                LOW_RES_MV,
                FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS,
                false,
            ),
            (
                JITTERED_MV,
                FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
                true,
            ),
            (INVERTED_DEPTH, FFX_FSR2_ENABLE_DEPTH_INVERTED, true),
        ] {
            if (self.options & bit != 0) == set {
                flags |= flag;
            }
        }
        if matches!(self.exposure, ExposureSource::Auto) {
            flags |= FFX_FSR2_ENABLE_AUTO_EXPOSURE;
        }
        flags
    }

    /// A device whose capabilities select the permutation: FP16, and the
    /// Lanczos LUT with 32 to 64 lanes below SM6.6, which leaves wave64
    /// unforced (ffx_fsr2.cpp:414-428).
    fn capabilities(&self) -> FfxDeviceCapabilities {
        let lut = self.options & LANCZOS != 0;
        FfxDeviceCapabilities {
            maximum_supported_shader_model: if lut {
                FfxShaderModel::ShaderModel6_5
            } else {
                FfxShaderModel::ShaderModel6_2
            },
            wave_lane_count_min: 32,
            wave_lane_count_max: if lut { 64 } else { 32 },
            fp16_supported: self.options & FP16 != 0,
            ..Default::default()
        }
    }

    /// The word stream of `oracle/fsr2_host.cpp` (documented in
    /// tests/fsr2_host_event_stream.rs): a context, then the dispatches, at
    /// the SDK's jitter sequence and with changing pre-exposure.
    fn host_words(&self) -> Vec<u32> {
        let s = self.sizes;
        let mut words = vec![
            1,
            self.flags(),
            s.max_render[0],
            s.max_render[1],
            s.display[0],
            s.display[1],
            s.max_render[0],
            s.max_render[1],
            u32::try_from(DISPATCHES).unwrap(),
        ];
        // Command list, depth, motion vectors and output, and the exposure.
        let exposure = if matches!(self.exposure, ExposureSource::Application) {
            8
        } else {
            0
        };
        for (dispatch, pre_exposure) in PRE_EXPOSURE.iter().enumerate() {
            let index = u32::try_from(dispatch).unwrap();
            words.extend([
                0,
                1 | 2 | 4 | 64 | exposure,
                0,
                s.render[0],
                s.render[1],
                0,
                index,
            ]);
            words.extend([1.0f32, 1.0].map(f32::to_bits));
            words.extend([
                u32::from(self.options & SHARPEN != 0),
                0.6f32.to_bits(),
                16.7f32.to_bits(),
                pre_exposure.to_bits(),
                u32::from(self.reset == Some(dispatch)),
            ]);
            words.extend([0.1f32, 100.0, 1.0, 1.0].map(f32::to_bits));
            words.push(0);
            words.extend([0.05f32, 1.0, 5.0, 0.9].map(f32::to_bits));
        }
        words
    }
}

fn number(value: &Value) -> u32 {
    u32::try_from(value.as_u64().unwrap()).unwrap()
}

fn surface_format(value: u32) -> FfxSurfaceFormat {
    use FfxSurfaceFormat as F;
    [
        F::R16G16B16A16Float,
        F::R32G32Float,
        F::R8G8B8A8Unorm,
        F::R16G16Float,
        F::R16Float,
        F::R16Snorm,
        F::R8Unorm,
        F::R8G8Unorm,
    ]
    .into_iter()
    .find(|f| *f as u32 == value)
    .unwrap_or_else(|| panic!("surface format {value}"))
}

/// SDK resources the accumulate pass reads that the passes before it
/// (luminance pyramid, reconstruct, depth clip, lock) write each frame: here
/// per-frame inputs, so the case declares them as application resources.
const PRODUCED_EACH_FRAME: &[&str] = &[
    "FSR2_PreparedInputColor",
    "FSR2_DilatedReactiveMasks",
    "FSR2_InternalDilatedVelocity1",
    "FSR2_InternalDilatedVelocity2",
    "FSR2_ExposureMips",
    "FSR2_NewLocks",
    "FSR2_AutoExposure",
];

/// A value in [0, 1) from integer coordinates.
fn noise(x: u32, y: u32, seed: u32) -> f32 {
    let mut h =
        x.wrapping_mul(0x8da6_b343) ^ y.wrapping_mul(0xd816_3841) ^ seed.wrapping_mul(0xcb1a_b31f);
    h ^= h >> 13;
    h = h.wrapping_mul(0x5bd1_e995);
    h ^= h >> 15;
    (h >> 8) as f32 / (1 << 24) as f32
}

/// One of `choices`, by `noise`.
fn pick<T: Copy>(choices: &[T], x: u32, y: u32, seed: u32) -> T {
    choices[(noise(x, y, seed) * choices.len() as f32) as usize]
}

/// IEEE binary16 bits of `value`, rounded to nearest even.
fn half(value: f32) -> u16 {
    let bits = value.to_bits();
    let sign = u16::try_from((bits >> 16) & 0x8000).unwrap();
    let exponent = i32::try_from((bits >> 23) & 0xff).unwrap() - 127 + 15;
    let mantissa = bits & 0x7f_ffff;
    if exponent >= 0x1f {
        return sign | 0x7c00;
    }
    let (kept, shift) = if exponent <= 0 {
        if exponent < -10 {
            return sign;
        }
        (mantissa | 0x80_0000, u32::try_from(14 - exponent).unwrap())
    } else {
        (
            (u32::try_from(exponent).unwrap() << 10 << 13) | mantissa,
            13,
        )
    };
    let rest = kept & ((1 << shift) - 1);
    let halfway = 1 << (shift - 1);
    let mut result = kept >> shift;
    if rest > halfway || (rest == halfway && result & 1 == 1) {
        result += 1;
    }
    sign | u16::try_from(result).unwrap()
}

/// Motion at display pixel (x, y) in dispatch `d`, in display pixels: still,
/// sub-pixel, below and above the 0.1 pixel threshold, large (beyond the 20
/// pixel velocity saturation) and history off-screen (disocclusion).
fn motion(x: u32, y: u32, d: u32) -> [f32; 2] {
    match (x / 6 + (y / 5) * 3 + d) % 9 {
        1 => [0.35, -0.2],
        2 => [0.02, 0.01],
        3 => [25.0, -14.0],
        4 => [3.0, 1.5],
        5 => [-(x as f32) - 10.0, 0.0],
        6 => [0.09, 0.0],
        7 => [-0.6, 0.8],
        _ => [0.0, 0.0],
    }
}

/// What a job supplies for `resource` in dispatch `dispatch`: every
/// application resource; of the created ones, in the first job, the Lanczos
/// LUT (AMD's initialization data) and a synthetic history for the ones it
/// reads (`history`). The rest start zeroed, as the SDK clears them.
#[allow(clippy::too_many_lines)] // One synthetic input per resource.
fn contents(
    case: &AccumulateCase,
    resource: &Resource,
    dispatch: usize,
    history: bool,
    init: &HashMap<String, Vec<u8>>,
) -> Option<Vec<u8>> {
    let hdr = case.options & HDR != 0;
    let [dw, dh] = case.sizes.display;
    let [rw, rh] = case.sizes.render;
    let d = u32::try_from(dispatch).unwrap();
    let (width, height) = (resource.width, resource.height);
    let texels = move |mip: u32| {
        let (w, h) = ((width >> mip).max(1), (height >> mip).max(1));
        (0..h).flat_map(move |y| (0..w).map(move |x| (x, y)))
    };
    let halves = |values: &[f32]| {
        values
            .iter()
            .flat_map(|v| half(*v).to_le_bytes())
            .collect::<Vec<u8>>()
    };
    let unorm = |v: f32| (v * 255.0).round() as u8;
    let floats = |values: [f32; 2]| values.iter().flat_map(|v| v.to_le_bytes()).collect();
    let bright = |x: u32, y: u32, rgb: [f32; 3]| {
        let scale = match (x * 3 + y + d) % 23 {
            0 if hdr => 3000.0,
            1 if hdr => 60000.0,
            _ if hdr => 40.0,
            _ => 1.0,
        };
        rgb.map(|c| c * scale)
    };
    Some(match resource.name {
        "FSR2_LanczosLutData" => init["FSR2_LanczosLutData"].clone(),
        "FSR2_DefaultExposure" => return None,
        name if resource.created.is_some() && !history => {
            assert!(name.starts_with("FSR2_"), "{name}");
            return None;
        }
        // Output colour and signed temporal reactive factor (negative: in
        // motion last frame).
        "FSR2_InternalUpscaled1" | "FSR2_InternalUpscaled2" => texels(0)
            .flat_map(|(x, y)| {
                let rgb = bright(
                    x,
                    y,
                    [
                        noise(x, y, 400) * 1.1,
                        noise(y, x, 401) * 0.9,
                        noise(x + 7, y, 402),
                    ],
                );
                let factor = pick(
                    &[-1.0, -0.4, -0.05, 0.0, 0.0, 0.0, 0.02, 0.1, 0.5, 1.0],
                    x / 2,
                    y / 2,
                    403,
                );
                halves(&[rgb[0], rgb[1], rgb[2], factor])
            })
            .collect(),
        // Lock lifetime (0 to 2) and temporal luma (0: none yet).
        "FSR2_LockStatus1" | "FSR2_LockStatus2" => texels(0)
            .flat_map(|(x, y)| {
                halves(&[
                    pick(&[0.0, 0.0, 0.25, 0.9, 1.0, 1.4, 2.0], x, y, 404),
                    pick(&[0.0, 0.9, 1.0, 1.05, 1.3], x, y, 405),
                ])
            })
            .collect(),
        // Four frames of rounded luma, a fifth of them zero.
        "FSR2_LumaHistory1" | "FSR2_LumaHistory2" => texels(0)
            .flat_map(|(x, y)| {
                (0..4).map(move |c| {
                    if noise(x, y, 406 + c) < 0.2 {
                        0
                    } else {
                        (noise(x, y, 410 + c) * 255.0) as u8
                    }
                })
            })
            .collect(),
        "exposure" => floats([EXPOSURE[dispatch], 0.5]),
        "FSR2_AutoExposure" => floats([AUTO_EXPOSURE[dispatch], 0.25]),
        // A sentinel the pass overwrites.
        "output" => texels(0)
            .flat_map(|_| [0x4700u16; 4].map(u16::to_le_bytes))
            .flatten()
            .collect(),
        // YCoCg of the prepared colour, and the depth clip factor in w.
        "FSR2_PreparedInputColor" => texels(0)
            .flat_map(|(x, y)| {
                let n = noise(x, y, 17 + d / 2);
                let rgb = if x >= rw || y >= rh {
                    // Beyond the render size: stale texels the kernel reaches.
                    [4.0, 0.0, 3.0]
                } else {
                    bright(
                        x,
                        y,
                        match (x / 5 + y / 3 + d) % 7 {
                            0 => [0.0; 3],
                            1 => [1.0; 3],
                            2 => [f32::from(u8::from((x + y) % 2 == 0)); 3],
                            _ => [
                                x as f32 / rw as f32 * 0.8 + n * 0.2,
                                y as f32 / rh as f32 * 0.6 + noise(y, x, 5) * 0.4,
                                0.5 + (n - 0.5) * 0.6,
                            ],
                        },
                    )
                };
                let [r, g, b] = rgb;
                let depth_clip = pick(&[1.0, 0.3, 0.08, 0.5], x / 3, y / 2, 20 + d)
                    * f32::from(u8::from(noise(x / 3, y / 2, 25 + d) < 0.2));
                halves(&[
                    0.25 * r + 0.5 * g + 0.25 * b,
                    0.5 * r - 0.5 * b,
                    -0.25 * r + 0.5 * g - 0.25 * b,
                    depth_clip,
                ])
            })
            .collect(),
        // Reactive factor and accumulation (transparency and composition) mask.
        "FSR2_DilatedReactiveMasks" => texels(0)
            .flat_map(|(x, y)| {
                [
                    unorm(
                        pick(&[1.0, 0.5, 0.15], x / 2, y, 30 + d)
                            * f32::from(u8::from(noise(x / 2, y, 35 + d) < 0.15)),
                    ),
                    unorm(
                        pick(&[1.0, 0.4], x, y / 2, 40 + d)
                            * f32::from(u8::from(noise(x, y / 2, 45 + d) < 0.1)),
                    ),
                ]
            })
            .collect(),
        // Dilated motion at render resolution, in UV.
        "FSR2_InternalDilatedVelocity1" | "FSR2_InternalDilatedVelocity2" => texels(0)
            .flat_map(|(x, y)| {
                let [mx, my] = motion(x * dw / rw, y * dh / rh, d);
                halves(&[mx / dw as f32, my / dh as f32])
            })
            .collect(),
        // Display-resolution motion in pixels (motionVectorScale 1).
        "motion-vectors" => texels(0)
            .flat_map(|(x, y)| halves(&motion(x, y, d)))
            .collect(),
        // Log luminance, all mips, jumping in two fifths of the texels.
        "FSR2_ExposureMips" => (0..resource.mips)
            .flat_map(|mip| {
                texels(mip).flat_map(move |(x, y)| {
                    let jump = if noise(x, y, 91 + mip + d) < 0.4 {
                        0.8
                    } else {
                        0.0
                    };
                    halves(&[-1.0 + 2.0 * noise(x, y, 7 + mip) + jump])
                })
            })
            .collect(),
        // New locks lasting two dispatches, so some relock; 127 is not above
        // the 127/255 threshold, 128 is.
        "FSR2_NewLocks" => texels(0)
            .map(|(x, y)| pick(&[255, 128, 127, 200, 0, 0, 0, 0], x / 2, y / 2, 300 + d / 2))
            .collect(),
        name => panic!("no contents for {name}"),
    })
}

/// DXC's fast-math folds of the accumulate HLSL, as its compiled variants show
/// (`shaders/generated/fsr2/options-*/fsr2_accumulate*.metal`): divisions by
/// constants become multiplications by the rounded reciprocal, and
/// `(fLuminanceDiff - 0.1f) * 10.0f` with `fLuminanceDiff = 1.0f - m` becomes
/// `(0.9 - m) * 10`. The strict comparison applies them to the port's WGSL.
const DXC_FOLDS: &[(&str, &str)] = &[
    (
        "ffxSaturate_f32((*fLuminanceDiff - 0.1f) * 10.0f)",
        "ffxSaturate_f32((0.9f - MinDividedByMax_f32_f32(fPreviousShadingChangeLuma, fShadingChangeLuma)) * 10.0f)",
    ),
    ("params.fHrVelocity / 50.0f", "params.fHrVelocity * 0.02f"),
    (
        "round(fCurrentFrameLuma * 255.0f) / 255.0f",
        "round(fCurrentFrameLuma * 255.0f) * 0.0039215688593685626983642578125f",
    ),
    ("fBoxSize / 0.1f", "fBoxSize * 10.0f"),
    (
        "ffxSaturate_f32(params.fHrVelocity / 20.0f)",
        "ffxSaturate_f32(params.fHrVelocity * 0.05f)",
    ),
    (
        "ffxSaturate_f32(params.fHrVelocity / FfxFloat32(20))",
        "ffxSaturate_f32(params.fHrVelocity * 0.05f)",
    ),
];

/// The comparisons of one accumulate case.
struct AccumulateResult {
    /// Each job's inputs identical on both sides (the port's previous
    /// outputs), both compiled with fast math as wgpu compiles.
    identical: compare::Comparison,
    /// Each side carrying its own outputs from job to job.
    carried: compare::Comparison,
    /// Identical inputs, both compiled without fast math and contraction,
    /// the port's WGSL with `DXC_FOLDS` applied.
    strict: compare::Comparison,
}

/// Run `case` through AMD's C++ host, the port's WGSL and the Metal oracle.
#[allow(clippy::too_many_lines)] // Host trace to jobs, resources and pipeline.
fn accumulate_case(gpu: &gpu::Gpu, case: &AccumulateCase) -> AccumulateResult {
    let [dw, dh] = case.sizes.display;
    let directory =
        gpu::case_directory(&format!("fsr2-accumulate-{:#04x}-{dw}x{dh}", case.options));

    // AMD's host: its accumulate pipeline, resources, jobs and LUT data.
    let init_directory = directory.join("host-init-data");
    fs::create_dir_all(&init_directory).unwrap();
    let output = run_cpp_host(
        cpp_host(),
        &case.capabilities(),
        &case.host_words(),
        &directory.join("host-input.words"),
        &init_directory,
    );
    fs::write(directory.join("host.jsonl"), &output).unwrap();
    let events: Vec<Value> = output
        .lines()
        .map(|l| serde_json::from_str(l).unwrap())
        .collect();
    let init: HashMap<String, Vec<u8>> = fs::read_dir(&init_directory)
        .unwrap()
        .map(|entry| {
            let path = entry.unwrap().path();
            let name = path.file_stem().unwrap().to_string_lossy().into_owned();
            (name, fs::read(path).unwrap())
        })
        .collect();
    for event in &events {
        if event[0] == "create-result" || event[0] == "dispatch-result" {
            assert_eq!(event[1], 0, "C++ host: {event}");
        }
    }
    let pass = case.pass();
    let host_pipeline = events
        .iter()
        .find(|e| e[0] == "pipeline" && number(&e[1]) == pass)
        .unwrap();
    assert_eq!(
        number(&host_pipeline[2]),
        case.options,
        "the host's permutation"
    );
    let mut dispatch = 0;
    let mut jobs = Vec::new();
    for event in &events {
        if event[0] == "frame" {
            dispatch = number(&event[1]) as usize;
        } else if event[0] == "compute" && number(&event[1]) == pass && dispatch >= WARMUP {
            jobs.push(Job {
                bindings: event[5]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|b| Binding {
                        uav: b[0] == "uav",
                        name: leak(b[1].as_str().unwrap()),
                        resource: leak(b[2].as_str().unwrap()),
                        mip: number(&b[3]),
                    })
                    .collect(),
                constants: event[6]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|c| {
                        let words = c[1].as_array().unwrap().iter().map(number).collect();
                        (leak(c[0].as_str().unwrap()), words)
                    })
                    .collect(),
                contents: HashMap::new(),
                dimensions: [0, 1, 2].map(|i| number(&event[2][i])),
            });
        }
    }
    assert_eq!(jobs.len(), JOBS, "one accumulate job per dispatch");

    // Every bound resource, as the host describes the ones it creates.
    let mut resources: Vec<Resource> = Vec::new();
    for binding in jobs.iter().flat_map(|j| &j.bindings) {
        let name = binding.resource;
        if resources.iter().any(|r| r.name == name) {
            continue;
        }
        let created = events.iter().find(|e| e[0] == "resource" && e[1] == name);
        resources.push(if let Some(e) = created {
            let (width, height) = (number(&e[4]), number(&e[5]));
            Resource {
                name,
                format: surface_format(number(&e[3])),
                width,
                height,
                // Zero requests the full chain.
                mips: match number(&e[6]) {
                    0 => u32::BITS - width.max(height).leading_zeros(),
                    mips => mips,
                },
                created: (!PRODUCED_EACH_FRAME.contains(&name)).then(|| number(&e[7])),
            }
        } else {
            let (format, [width, height]) = match name {
                "exposure" => (FfxSurfaceFormat::R32G32Float, [1, 1]),
                "motion-vectors" => (FfxSurfaceFormat::R16G16Float, [dw, dh]),
                "output" => (FfxSurfaceFormat::R16G16B16A16Float, [dw, dh]),
                name => panic!("unknown application resource {name}"),
            };
            Resource {
                name,
                format,
                width,
                height,
                mips: 1,
                created: None,
            }
        });
    }
    for (index, job) in jobs.iter_mut().enumerate() {
        for r in &resources {
            let binding = job.bindings.iter().find(|b| b.resource == r.name);
            // Created resources only in the first job; application
            // resources in every job binding them, and all in the first.
            let supplied = if r.created.is_some() {
                index == 0
            } else {
                binding.is_some() || index == 0
            };
            let history = binding.is_some_and(|b| !b.uav);
            if supplied && let Some(bytes) = contents(case, r, WARMUP + index, history, &init) {
                job.contents.insert(r.name, bytes);
            }
        }
    }

    let options = number(&host_pipeline[2]);
    let pipeline = Pipeline {
        pass,
        options,
        blob: fsr2_get_permutation_blob_by_index(pass, options).unwrap(),
        root_constants: host_pipeline[4]
            .as_array()
            .unwrap()
            .iter()
            .map(number)
            .collect(),
        samplers: host_pipeline[5]
            .as_array()
            .unwrap()
            .iter()
            .map(|s| {
                let address = |v: &Value| match number(v) {
                    2 => FfxAddressMode::Clamp,
                    mode => panic!("address mode {mode}"),
                };
                FfxSamplerDescription {
                    filter: match number(&s[0]) {
                        0 => FfxFilterType::MinMagMipPoint,
                        1 => FfxFilterType::MinMagMipLinear,
                        filter => panic!("filter {filter}"),
                    },
                    address_mode_u: address(&s[1]),
                    address_mode_v: address(&s[2]),
                    address_mode_w: address(&s[3]),
                    stage: number(&s[4]),
                }
            })
            .collect(),
    };
    pass::run(gpu, &FSR2, &directory, &resources, &pipeline, &jobs);
    // Both oracles compile with Metal fast math (SDK-P22): measured.
    let fast_math = |_: &compare::Difference| Ok("SDK-P22");
    gpu::replay(&directory, &FSR2);
    let identical = compare::compare(&directory, FSR2.stages, &fast_math);
    let carried = compare::compare(
        &gpu::run_sequence(&directory, &FSR2),
        FSR2.stages,
        &fast_math,
    );

    let strict = directory.join("strict");
    let mut source = ffx_get_wgsl_source(&pipeline.blob).unwrap();
    for (sdk, dxc) in DXC_FOLDS {
        assert_eq!(source.matches(sdk).count(), 1, "{sdk}");
        source = source.replace(sdk, dxc);
    }
    let [port, original] = pass::strict_variants(&FSR2, &pipeline, &source, &strict);
    gpu::link_case(&directory, &strict, &["cpp.jsonl", "inputs"]);
    // The port into `wgpu` and the original into `metal-replay`, the
    // directories compare::compare reads.
    gpu::replay_strict(&directory, &port, &strict.join("wgpu"));
    gpu::replay_strict(&directory, &original, &strict.join("metal-replay"));
    let strict = compare::compare(&strict, FSR2.stages, &|_: &compare::Difference| {
        Err("strict compilation must match".into())
    });

    let outputs = jobs
        .iter()
        .map(|j| j.bindings.iter().filter(|b| b.uav).count())
        .sum();
    for (mode, comparison) in [
        ("identical inputs", &identical),
        ("own outputs", &carried),
        ("strict", &strict),
    ] {
        println!("{} ({mode}): {}", directory.display(), comparison.summary());
        assert_eq!(
            comparison
                .dumps
                .get(FSR2.stages[pass as usize])
                .map(|d| d.0),
            Some(outputs),
            "every UAV of every job"
        );
    }
    AccumulateResult {
        identical,
        carried,
        strict,
    }
}

/// The largest difference per written resource (ping-pong pairs joined).
fn maxima(comparison: &compare::Comparison, into: &mut BTreeMap<String, f64>) {
    for d in &comparison.differences {
        let entry = into
            .entry(d.resource.trim_end_matches(['1', '2']).to_owned())
            .or_default();
        *entry = entry.max(d.maximum);
    }
}

/// Every accumulate permutation (both passes, both tables) at every size, one
/// exposure source each and a reset in every other size. The strict
/// comparison must be exact for every output of every job; the fast-math
/// comparisons, with identical inputs and with each side's own outputs, are
/// measured and printed.
#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 accumulate variants"]
fn accumulate_matches_the_hlsl_in_every_permutation() {
    let gpu = gpu::Gpu::new(true, None);
    let mut failures = Vec::new();
    let mut table = String::new();
    for index in 0..128u32 {
        let options = (index & 0x3f) | if index >= 64 { FP16 } else { 0 };
        let exposure = [
            ExposureSource::Application,
            ExposureSource::Default,
            ExposureSource::Auto,
        ][index as usize % 3];
        let mut sizes = ACCUMULATE_SIZES.to_vec();
        if options & !FP16 == LOW_RES_MV {
            sizes.push(FULL_HD);
        }
        let (mut identical, mut carried) = (BTreeMap::new(), BTreeMap::new());
        for (i, &sizes) in sizes.iter().enumerate() {
            let case = AccumulateCase {
                options,
                sizes,
                exposure,
                reset: (i % 2 == 1).then_some(WARMUP + 2),
            };
            let result = accumulate_case(&gpu, &case);
            maxima(&result.identical, &mut identical);
            maxima(&result.carried, &mut carried);
            if ![&result.identical, &result.carried, &result.strict]
                .iter()
                .all(|c| c.accepted())
            {
                failures.push(format!("{options:#04x} {:?}", sizes.display));
            }
        }
        let _ = writeln!(
            table,
            "{options:#04x} {exposure:?}: identical inputs {identical:?}, own outputs {carried:?}"
        );
    }
    println!("{table}");
    assert!(failures.is_empty(), "accumulate differs: {failures:?}");
}

// ---- Passes through the wgpu backend, constants from AMD's C++ host --------

/// Every permutation options value the SDK compiles for a pass: the 64 keys
/// of its `FSR2_PERMUTATION_ARGS` (gpu/fsr2/CMakeCompileFSR2Shaders.txt) in
/// the 32-bit table and, where the blob accessor selects it, the 16-bit table.
fn permutations(fp16_table: bool) -> Vec<u32> {
    let keys = 0..64;
    if fp16_table {
        keys.clone().chain(keys.map(|k| k | FP16)).collect()
    } else {
        keys.collect()
    }
}

/// A context AMD's host creates: its flags, the device capabilities that
/// select the Lanczos LUT (a wave range including 64) and FP16, and sizes.
struct Context {
    flags: u32,
    lut: bool,
    fp16: bool,
    max_render: [u32; 2],
    display: [u32; 2],
    color: [u32; 2],
}

impl Context {
    /// The context whose pipelines the host creates with the key bits of
    /// `options` (getPipelinePermutationFlags, ffx_fsr2.cpp:370-388; the
    /// sharpening bit is the accumulate pass's own), plus `extra` flags that
    /// select no permutation.
    fn for_options(options: u32, extra: u32, max_render: [u32; 2], display: [u32; 2]) -> Self {
        let flag = |bit, flag| if options & bit != 0 { flag } else { 0 };
        Self {
            flags: flag(HDR, FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE)
                | if options & LOW_RES_MV == 0 {
                    FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
                } else {
                    0
                }
                | flag(
                    JITTERED_MV,
                    FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
                )
                | flag(INVERTED_DEPTH, FFX_FSR2_ENABLE_DEPTH_INVERTED)
                | extra,
            lut: options & LANCZOS != 0,
            fp16: options & FP16 != 0,
            max_render,
            display,
            color: max_render,
        }
    }
}

/// One `ffxFsr2ContextDispatch` (see `oracle/fsr2_host.cpp`); the jitter is
/// the SDK's sequence at `jitter_index`.
#[derive(Clone, Copy)]
struct Dispatch {
    present: u32,
    render: [u32; 2],
    jitter_index: i32,
    motion_vector_scale: [f32; 2],
    frame_time_delta: f32,
    pre_exposure: f32,
    reset: bool,
    camera_near: f32,
    camera_far: f32,
    fov: f32,
    view_space_to_meters: f32,
    auto_reactive: bool,
    auto_tc: [f32; 2],
    auto_reactive_scale_max: [f32; 2],
}

/// Dispatch present bits (`oracle/fsr2_host.cpp`): command list, depth,
/// motion vectors, exposure, output; and opaque-only colour.
const PRESENT: u32 = 1 | 2 | 4 | 8 | 64;
const OPAQUE_ONLY: u32 = 128;

impl Dispatch {
    /// Frame `index` of a sequence at `render` size: varied jitter, motion
    /// vector scale, frame time, pre-exposure (0 is the SDK's "none") and
    /// camera.
    fn frame(index: usize, render: [u32; 2]) -> Self {
        let i = index as f32;
        let [width, height] = render.map(|v| v as f32);
        Self {
            present: PRESENT,
            render,
            jitter_index: i32::try_from(index * 5 + 1).unwrap(),
            motion_vector_scale: [width * (1.0 + 0.25 * i), -height * (1.0 - 0.125 * i)],
            frame_time_delta: [16.6, 2500.0, 0.0, 33.3][index % 4],
            pre_exposure: [1.0, 0.0, 2.5, 0.35][index % 4],
            reset: index == 0,
            camera_near: [0.1, 0.5, 2.0][index % 3],
            camera_far: [1000.0, 50.0, f32::MAX][index % 3],
            fov: 0.9 + i * 0.2,
            view_space_to_meters: [1.0, 0.0, 2.5][index % 3],
            auto_reactive: false,
            auto_tc: [0.05, 1.0],
            auto_reactive_scale_max: [5.0, 0.9],
        }
    }
}

/// One `ffxFsr2ContextGenerateReactiveMask` (`oracle/fsr2_host.cpp`).
#[derive(Clone, Copy)]
struct Generate {
    render: [u32; 2],
    scale: f32,
    cutoff_threshold: f32,
    binary_value: f32,
    flags: u32,
}

enum Op {
    Dispatch(Dispatch),
    Generate(Generate),
}

/// A compute job the host scheduled: its dimensions and constant buffers.
#[derive(Clone)]
struct HostJob {
    dimensions: [u32; 3],
    constants: Vec<(String, Vec<u32>)>,
}

/// What AMD's host did for one op: the compute jobs by pass, and the
/// constant buffers it staged (in order).
#[derive(Default)]
struct HostFrame {
    jobs: HashMap<u32, HostJob>,
    staged: Vec<Vec<u32>>,
}

/// The pipelines (by pass: options, root-constant sizes, samplers) and frames
/// of `ops` run by AMD's unchanged host.
struct HostRun {
    pipelines: HashMap<u32, (u32, Vec<u32>, Vec<FfxSamplerDescription>)>,
    frames: Vec<HostFrame>,
}

fn host(context: &Context, ops: &[Op]) -> HostRun {
    static RUN: AtomicUsize = AtomicUsize::new(0);
    let capabilities = FfxDeviceCapabilities {
        maximum_supported_shader_model: FfxShaderModel::ShaderModel6_2,
        wave_lane_count_min: 32,
        wave_lane_count_max: if context.lut { 64 } else { 32 },
        fp16_supported: context.fp16,
        ..Default::default()
    };
    let mut words = vec![
        1,
        context.flags,
        context.max_render[0],
        context.max_render[1],
        context.display[0],
        context.display[1],
        context.color[0],
        context.color[1],
        u32::try_from(ops.len()).unwrap(),
    ];
    for op in ops {
        match op {
            Op::Dispatch(d) => {
                words.extend([0, d.present, 0, d.render[0], d.render[1], 0]);
                words.push(d.jitter_index.cast_unsigned());
                words.extend(d.motion_vector_scale.map(f32::to_bits));
                words.extend([0, 0.5f32.to_bits(), d.frame_time_delta.to_bits()]);
                words.extend([d.pre_exposure.to_bits(), u32::from(d.reset)]);
                words.extend(
                    [d.camera_near, d.camera_far, d.fov, d.view_space_to_meters].map(f32::to_bits),
                );
                words.push(u32::from(d.auto_reactive));
                words.extend(d.auto_tc.map(f32::to_bits));
                words.extend(d.auto_reactive_scale_max.map(f32::to_bits));
            }
            Op::Generate(g) => {
                words.extend([1, 1, g.render[0], g.render[1]]);
                words.extend([g.scale, g.cutoff_threshold, g.binary_value].map(f32::to_bits));
                words.push(g.flags);
            }
        }
    }
    let directory = PathBuf::from(env!("CARGO_TARGET_TMPDIR"))
        .join("fsr2-passes-host")
        .join(format!("run-{}", RUN.fetch_add(1, Ordering::Relaxed)));
    let _ = fs::remove_dir_all(&directory);
    fs::create_dir_all(directory.join("init-data")).unwrap();
    let output = run_cpp_host(
        cpp_host(),
        &capabilities,
        &words,
        &directory.join("input.words"),
        &directory.join("init-data"),
    );
    let mut run = HostRun {
        pipelines: HashMap::new(),
        frames: Vec::new(),
    };
    let number = |v: &Value| u32::try_from(v.as_u64().unwrap()).unwrap();
    for line in output.lines() {
        let event: Value = serde_json::from_str(line).unwrap();
        match event[0].as_str().unwrap() {
            "pipeline" => {
                let samplers = event[5]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|s| FfxSamplerDescription {
                        filter: [
                            FfxFilterType::MinMagMipPoint,
                            FfxFilterType::MinMagMipLinear,
                            FfxFilterType::MinMagLinearMipPoint,
                        ][number(&s[0]) as usize],
                        address_mode_u: address_mode(number(&s[1])),
                        address_mode_v: address_mode(number(&s[2])),
                        address_mode_w: address_mode(number(&s[3])),
                        stage: number(&s[4]),
                    })
                    .collect();
                let roots = event[4].as_array().unwrap().iter().map(number).collect();
                run.pipelines
                    .insert(number(&event[1]), (number(&event[2]), roots, samplers));
            }
            "frame" => run.frames.push(HostFrame::default()),
            "constants" => {
                let words = event[1].as_array().unwrap().iter().map(number).collect();
                run.frames.last_mut().unwrap().staged.push(words);
            }
            "compute" => {
                let dimensions = [0, 1, 2].map(|i| number(&event[2][i]));
                let constants = event[6]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|cb| {
                        (
                            cb[0].as_str().unwrap().to_owned(),
                            cb[1].as_array().unwrap().iter().map(number).collect(),
                        )
                    })
                    .collect();
                run.frames.last_mut().unwrap().jobs.insert(
                    number(&event[1]),
                    HostJob {
                        dimensions,
                        constants,
                    },
                );
            }
            "create-result" | "dispatch-result" | "generate-reactive-result" => {
                assert_eq!(event[1], 0, "AMD's host rejected the case: {line}");
            }
            _ => {}
        }
    }
    run
}

fn address_mode(value: u32) -> FfxAddressMode {
    [
        FfxAddressMode::Wrap,
        FfxAddressMode::Mirror,
        FfxAddressMode::Clamp,
        FfxAddressMode::Border,
        FfxAddressMode::MirrorOnce,
    ][value as usize]
}

/// Differences the comparison admits, by the documented exception (IDs are
/// provisional, for CONFORMANCE.md):
///
/// - FSR2-F1: float evaluation in regular frames. Both programs are compiled
///   with Metal fast math from differently shaped code (DXC's optimized
///   SPIR-V through SPIRV-Cross; naga's direct translation), so FMA
///   contraction, reassociation and fast-math approximations differ; outputs
///   that cancel large terms (YCoCg chroma, TCR's edge difference) or
///   compare against thresholds carry the difference further.
/// - FSR2-F2: degenerate evaluation in edge frames (black, flat, constant
///   65504 and sky inputs): 0/0, x/0, sqrt(0) and infinite view depths, whose
///   results Metal fast math leaves undefined on both sides, and HLSL `max`'s
///   IEEE maxNum (SPIRV-Cross `precise::max`) that WGSL `max` does not
///   guarantee.
/// - `extra`: a pass's own exception (SDK-P14 for the luminance pyramid).
///
/// F1 and F2 admit a difference only up to [`MEASURED`]; integer outputs must
/// match exactly.
#[allow(clippy::too_many_arguments)]
fn admit(
    resources: &[Resource],
    jobs: &[Job],
    edges: &[bool],
    fp16: bool,
    extra: &Exception,
    d: &compare::Difference,
) -> Result<&'static str, String> {
    let frame: usize = d.path.iter().next().unwrap().to_str().unwrap()["frame-".len()..]
        .parse()
        .unwrap();
    if let Some(exception) = extra(d, &jobs[frame]) {
        return Ok(exception);
    }
    let format = resources
        .iter()
        .find(|r| r.name == d.resource)
        .unwrap()
        .format;
    if matches!(format, FfxSurfaceFormat::R32Uint) {
        return Err(format!("{format:?} outputs must match exactly"));
    }
    let edge = edges[frame];
    let fraction = d.texels as f64 / f64::from(d.size[0] * d.size[1]);
    let bound = MEASURED.iter().find(|b| {
        b.stage == d.stage && d.resource.starts_with(b.output) && b.fp16 == fp16 && b.edge == edge
    });
    let measured = format!("max {:e}, {fraction:e} of the texels", d.maximum);
    match bound {
        Some(b) if d.maximum <= b.maximum && fraction <= b.fraction => Ok(leak(&format!(
            "{}, {measured}",
            if edge { "FSR2-F2" } else { "FSR2-F1" }
        ))),
        _ => Err(format!(
            "{} frame, {measured}: beyond the measured maxima",
            if edge { "edge" } else { "regular" }
        )),
    }
}

/// A measured maximum of FSR2-F1 or FSR2-F2: per pass, output (resource name
/// prefix), 16-bit table and frame class, the largest channel difference
/// and the largest fraction of a dump's texels that differ.
struct Bound {
    stage: &'static str,
    output: &'static str,
    fp16: bool,
    edge: bool,
    maximum: f64,
    fraction: f64,
}

const fn bound(
    stage: &'static str,
    output: &'static str,
    fp16: bool,
    edge: bool,
    maximum: f64,
    fraction: f64,
) -> Bound {
    Bound {
        stage,
        output,
        fp16,
        edge,
        maximum,
        fraction,
    }
}

/// The maxima measured over every case of these tests (Apple M5, macOS 27,
/// wgpu 29.0.4, 2026-09-30), not tolerances chosen to pass.
const MEASURED: &[Bound] = &[
    // YCoCg: one binary16 ulp of the texel's luma, whose chroma cancels.
    bound(
        "fsr2_depth_clip",
        "FSR2_PreparedInputColor",
        false,
        false,
        16.0,
        0.004_700_352_526_439_483,
    ),
    bound(
        "fsr2_depth_clip",
        "FSR2_PreparedInputColor",
        true,
        false,
        16.0,
        0.004_700_352_526_439_483,
    ),
    bound(
        "fsr2_depth_clip",
        "FSR2_PreparedInputColor",
        false,
        true,
        0.000_244_140_625,
        3.858_024_691_358_025e-6,
    ),
    bound(
        "fsr2_depth_clip",
        "FSR2_PreparedInputColor",
        true,
        true,
        0.000_244_140_625,
        3.858_024_691_358_025e-6,
    ),
    // Black neighbourhoods: 0/0 similarity (ffx_fsr2_depth_clip.h:192).
    bound(
        "fsr2_depth_clip",
        "FSR2_DilatedReactiveMasks",
        false,
        true,
        1.0,
        0.117_187_5,
    ),
    bound(
        "fsr2_depth_clip",
        "FSR2_DilatedReactiveMasks",
        true,
        true,
        1.0,
        0.117_187_5,
    ),
    // alphaEdge - opaqueEdge cancels; FP16 thresholds its half products.
    bound(
        "fsr2_tcr_autogenerate",
        "FSR2_AutoReactive",
        false,
        false,
        0.058_823_529_411_764_72,
        0.000_574_052_812_858_783,
    ),
    bound(
        "fsr2_tcr_autogenerate",
        "FSR2_AutoReactive",
        true,
        false,
        0.2,
        0.000_169_004_563_123_204_3,
    ),
    // Flat neighbourhoods: sqrt(sqrt(0)) (ffx_fsr2_tcr_autogen.h:147, :172).
    bound(
        "fsr2_tcr_autogenerate",
        "FSR2_AutoReactive",
        false,
        true,
        1.0,
        0.023_437_5,
    ),
    bound(
        "fsr2_tcr_autogenerate",
        "FSR2_AutoReactive",
        true,
        true,
        1.0,
        0.023_437_5,
    ),
    // The exposure's exp, log2 and pow after DXC folded 78 / (0.65 * 100)
    // and 100 / 12.5 (ffx_fsr2_common.h:403-415); the log luma is exact.
    bound(
        "fsr2_compute_luminance_pyramid",
        "FSR2_AutoExposure",
        false,
        false,
        7.450_580_596_923_828e-9,
        1.0,
    ),
    bound(
        "fsr2_compute_luminance_pyramid",
        "FSR2_AutoExposure",
        false,
        true,
        1.490_116_119_384_765_6e-8,
        1.0,
    ),
];

/// A pass case: the host's pipeline for `pass` at `options` and the jobs,
/// through the port (wgpu backend) and the HLSL on Metal.
#[allow(clippy::too_many_arguments)]
fn backend_case(
    gpu: &gpu::Gpu,
    name: &str,
    pass: u32,
    options: u32,
    host_run: &HostRun,
    resources: &[Resource],
    jobs: &[Job],
    edges: &[bool],
    extra: &Exception,
) -> compare::Comparison {
    let (_, root_constants, samplers) = host_run.pipelines[&pass].clone();
    let pipeline = Pipeline {
        pass,
        options,
        blob: ffx_get_permutation_blob_by_index(
            FfxEffect::Fsr2,
            pass,
            FFX_BIND_COMPUTE_SHADER_STAGE,
            options,
        )
        .unwrap(),
        root_constants,
        samplers,
    };
    let directory = gpu::case_directory(&format!("{name}-{options:#04x}"));
    pass::run_backend(gpu, &FSR2, &directory, resources, &pipeline, jobs);
    gpu::replay(&directory, &FSR2);
    let comparison = compare::compare(&directory, FSR2.stages, &|d| {
        admit(resources, jobs, edges, options & FP16 != 0, extra, d)
    });
    let stage = FSR2.stages[pass as usize];
    println!("{}: {}", directory.display(), comparison.summary());
    let dumps: usize = jobs
        .iter()
        .map(|job| {
            let written: HashSet<_> = job
                .bindings
                .iter()
                .filter(|b| b.uav)
                .map(|b| b.resource)
                .collect();
            written
                .iter()
                .map(|name| resources.iter().find(|r| r.name == *name).unwrap().mips as usize)
                .sum::<usize>()
        })
        .sum();
    assert_eq!(
        comparison.dumps.get(stage).map(|d| d.0),
        Some(dumps),
        "every mip of every UAV of every job compared"
    );
    // The printed summary is the record; a rejected case stays for inspection.
    if comparison.accepted() {
        fs::remove_dir_all(&directory).unwrap();
    }
    comparison
}

// ---- Synthetic inputs -------------------------------------------------------

impl Random {
    fn unit(&mut self) -> f32 {
        (self.next() >> 8) as f32 / (1u32 << 24) as f32
    }

    fn range(&mut self, low: f32, high: f32) -> f32 {
        low + (high - low) * self.unit()
    }

    /// binary16 bits of a value of magnitude below 2^(max_exponent - 14)
    /// (exponent field up to `max_exponent`), zero and subnormals included,
    /// with a random sign when `signed`.
    fn half_up_to(&mut self, max_exponent: u32, signed: bool) -> u16 {
        self.half_between(0, max_exponent, signed)
    }

    /// binary16 bits with an exponent field in `min_exponent..=max_exponent`.
    fn half_between(&mut self, min_exponent: u32, max_exponent: u32, signed: bool) -> u16 {
        let bits = self.next();
        let exponent =
            u16::try_from(min_exponent + (bits >> 16) % (max_exponent - min_exponent + 1)).unwrap();
        let sign = if signed && bits & 1 != 0 { 0x8000 } else { 0 };
        sign | (exponent << 10) | u16::try_from((bits >> 1) & 0x3ff).unwrap()
    }
}

/// Every texel of a `width` x `height` image from `texel(x, y)`.
fn image(width: u32, height: u32, mut texel: impl FnMut(u32, u32) -> Vec<u8>) -> Vec<u8> {
    let mut bytes = Vec::new();
    for y in 0..height {
        for x in 0..width {
            bytes.extend(texel(x, y));
        }
    }
    bytes
}

fn halves(values: &[u16]) -> Vec<u8> {
    values.iter().flat_map(|h| h.to_le_bytes()).collect()
}

fn floats(values: &[f32]) -> Vec<u8> {
    values.iter().flat_map(|f| f.to_le_bytes()).collect()
}

/// RGBA16F colour. Regular: every component positive (red may be negative),
/// with bright HDR blocks from 32 to 65504 (the binary16 maximum) in which
/// neighbours differ. Edge: 4x4 blocks of black, flat grey, a constant 65504
/// channel (which makes neighbourhood differences cancel to the last bits),
/// negative components and noise.
fn colour(width: u32, height: u32, seed: u32, edge: bool) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |x, y| {
        let block = (x / 4 + 3 * (y / 4) + seed) % 7;
        let texel = if edge {
            match block {
                0 => [0; 4],
                1 => [0x3800, 0x3800, 0x3800, 0x3c00],
                2 => [0x7bff, random.half_up_to(30, false), 0x7000, 0x3c00],
                3 => [
                    random.half_up_to(16, true),
                    random.half_up_to(16, true),
                    random.half_up_to(16, true),
                    0x3c00,
                ],
                _ => [
                    random.half_up_to(17, false),
                    random.half_up_to(17, false),
                    random.half_up_to(17, false),
                    random.half_up_to(15, false),
                ],
            }
        } else {
            let mut value = |min_exponent, max_exponent, signed| {
                random.half_between(min_exponent, max_exponent, signed)
            };
            match block {
                0 => [
                    value(20, 30, false),
                    value(20, 30, false),
                    value(20, 30, false),
                    0x3c00,
                ],
                1 => [
                    value(4, 16, true),
                    value(4, 16, false),
                    value(4, 16, false),
                    0x3c00,
                ],
                _ => [
                    value(4, 17, false),
                    value(4, 17, false),
                    value(4, 17, false),
                    value(4, 15, false),
                ],
            }
        };
        halves(&texel)
    })
}

/// RG16F motion vectors in 4x4 blocks: sub-threshold, moderate, and large
/// enough to leave the screen (disocclusion); edge frames add none at all.
/// The dispatch scales them to UV space (ffx_fsr2.cpp:1178-1181).
fn motion_vectors(width: u32, height: u32, seed: u32, edge: bool) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |x, y| {
        let texel = match (x / 4 + 5 * (y / 4) + seed) % 5 {
            0 if edge => [0, 0],
            0 | 1 => [
                random.half_between(5, 7, true),
                random.half_between(5, 7, true),
            ],
            2 => [
                random.half_between(5, 10, true),
                random.half_between(5, 10, true),
            ],
            3 => [
                random.half_between(5, 14, true),
                random.half_between(5, 13, true),
            ],
            _ => [
                random.half_between(5, 12, true),
                random.half_between(5, 12, true),
            ],
        };
        halves(&texel)
    })
}

/// R32F device depth: a smooth ramp and noise inside (0, 1); edge frames add
/// 4x4 blocks of 0 and 1 (the near or far plane, "sky" depending on the
/// inversion).
fn depth(width: u32, height: u32, seed: u32, edge: bool) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |x, y| {
        let value = match (x / 4 + 7 * (y / 4) + seed) % 6 {
            0 if edge => 0.0,
            1 if edge => 1.0,
            2 => 0.01 + 0.98 * (x + y) as f32 / (width + height) as f32,
            _ => random.range(0.01, 0.99),
        };
        floats(&[value])
    })
}

/// R32_UINT reconstructed depth: float bits of depths inside (0, 1); edge
/// frames add the lock pass's far-plane clear for either depth direction.
fn reconstructed_depth(width: u32, height: u32, seed: u32, edge: bool) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |_, _| {
        let value = match random.next() % 4 {
            0 if edge => 0x3f80_0000,
            1 if edge => 0,
            _ => random.range(0.01, 0.99).to_bits(),
        };
        value.to_le_bytes().to_vec()
    })
}

/// Any bytes (fully overwritten outputs, or unwritten texels kept by both).
fn noise_bytes(len: usize, seed: u32) -> Vec<u8> {
    let mut random = Random(seed | 1);
    (0..len).map(|_| (random.next() >> 24) as u8).collect()
}

/// UNORM8 masks: mostly zero with blocks of partial and full coverage.
fn mask(width: u32, height: u32, channels: usize, seed: u32) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |x, y| {
        (0..channels)
            .map(|_| match (x / 3 + y / 5 + seed) % 5 {
                0 | 1 => 0,
                2 => 255,
                _ => (random.next() >> 24) as u8,
            })
            .collect()
    })
}

/// One size of a case: the context's maximum render and display sizes and
/// the dispatches' render size.
#[derive(Clone, Copy)]
struct Size {
    max_render: [u32; 2],
    render: [u32; 2],
    display: [u32; 2],
}

const fn size(max_render: [u32; 2], render: [u32; 2], display: [u32; 2]) -> Size {
    Size {
        max_render,
        render,
        display,
    }
}

/// Partial 8x8 tiles, odd and 1x1-ish sizes, dynamic resolution (render
/// below the maximum) and native resolution.
const SIZES: &[Size] = &[
    size([2, 1], [1, 1], [3, 2]),
    size([2, 1], [2, 1], [3, 2]),
    size([16, 8], [16, 8], [24, 12]),
    size([37, 23], [37, 23], [56, 35]),
    size([130, 67], [101, 50], [195, 100]),
    size([97, 61], [97, 61], [97, 61]),
];

/// About 1920x1080, at Quality (x1.5).
const LARGE: Size = size([1920, 1080], [1920, 1080], [2880, 1620]);

/// Frames per size.
const FRAMES_PER_SIZE: usize = 3;

/// An application or effect texture of a case.
fn resource(
    name: &'static str,
    format: FfxSurfaceFormat,
    [width, height]: [u32; 2],
    mips: u32,
    created: Option<FfxResourceUsage>,
) -> Resource {
    Resource {
        name,
        format,
        width,
        height,
        mips,
        created,
    }
}

fn binding(uav: bool, name: &'static str, resource: &'static str) -> Binding {
    Binding {
        uav,
        name,
        resource,
        mip: 0,
    }
}

/// R16F lock input luma in 4x4 blocks: flat (every neighbour similar), a
/// bright ridge row and column (thin features), zero (0/0 differences),
/// isolated bright texels, and noise.
fn lock_luma(width: u32, height: u32, seed: u32) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |x, y| {
        let value = match (x / 4 + 3 * (y / 4) + seed) % 6 {
            0 => 0x3800,
            1 if x % 4 == 1 || y % 4 == 2 => 0x3c00,
            1 => 0x3400,
            2 => 0,
            3 if (x + y) % 3 == 0 => 0x3a00,
            3 => 0x3000,
            _ => random.half_up_to(15, false),
        };
        halves(&[value])
    })
}

/// R11G11B10F colour: random texels up to 2^(16 - 15) (no infinity or NaN
/// encodings); edge frames add black blocks.
fn packed_colour(width: u32, height: u32, seed: u32, edge: bool) -> Vec<u8> {
    let mut random = Random(seed | 1);
    image(width, height, |x, y| {
        let mut channel = |shift: u32, mantissa: u32| {
            ((random.next() % 17) << mantissa | (random.next() & ((1 << mantissa) - 1))) << shift
        };
        let value = if edge && (x / 4 + y / 4 + seed).is_multiple_of(4) {
            0
        } else {
            channel(0, 6) | channel(11, 6) | channel(22, 5)
        };
        value.to_le_bytes().to_vec()
    })
}

/// The effect resources a case creates, as `ffx_fsr2.cpp:538-834` does.
fn created(
    name: &'static str,
    format: FfxSurfaceFormat,
    size: [u32; 2],
    mips: u32,
    usage: FfxResourceUsage,
) -> Resource {
    resource(name, format, size, mips, Some(usage))
}

fn application(name: &'static str, format: FfxSurfaceFormat, size: [u32; 2]) -> Resource {
    resource(name, format, size, 1, None)
}

const UAV: FfxResourceUsage = FFX_RESOURCE_USAGE_UAV;
const RT_UAV: FfxResourceUsage = FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV;
const RT_UAV_DCC: FfxResourceUsage = RT_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET;
const UAV_DCC: FfxResourceUsage = FFX_RESOURCE_USAGE_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET;

/// A pass's own admitted difference for a job (see [`admit`]).
type Exception = dyn Fn(&compare::Difference, &Job) -> Option<&'static str>;

/// Builds a size's resources and jobs (each with its edge-frame flag) from
/// AMD's host run, resource names made unique per size and a seed.
type Jobs<'a> = dyn Fn(
        &Size,
        &dyn Fn(&str) -> &'static str,
        &HostRun,
        u32,
        &mut Vec<Resource>,
        &mut Vec<(Job, bool)>,
    ) + 'a;

/// A case over `sizes`: per size, AMD's host runs `ops(size)` in the context
/// for `options` (with DEPTH_INFINITE on odd sizes), and `jobs(size, label,
/// run)` builds the resources and jobs from its frames.
#[allow(clippy::too_many_arguments)]
fn sized_case(
    gpu: &gpu::Gpu,
    name: &str,
    pass: FfxFsr2Pass,
    options: u32,
    sizes: &[Size],
    ops: &dyn Fn(usize, &Size) -> Vec<Op>,
    extra: &Exception,
    jobs: &Jobs<'_>,
) -> compare::Comparison {
    let pass = pass as u32;
    let mut resources = Vec::new();
    let mut all_jobs = Vec::new();
    let mut last = None;
    for (s, size) in sizes.iter().enumerate() {
        let infinite = if s % 2 == 1 {
            FFX_FSR2_ENABLE_DEPTH_INFINITE
        } else {
            0
        };
        let context = Context::for_options(options, infinite, size.max_render, size.display);
        let run = host(&context, &ops(s, size));
        // The key the host selects for the context (no pass of these has the
        // sharpening bit, which only the accumulate pass sets).
        assert_eq!(
            run.pipelines[&pass].0,
            options & !FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING,
            "the host's permutation for the context"
        );
        let label = format!("{}x{}-{s}", size.render[0], size.render[1]);
        jobs(
            size,
            &|n| leak(&format!("{n}@{label}")),
            &run,
            0x9e37_79b9 ^ u32::try_from(s << 8).unwrap(),
            &mut resources,
            &mut all_jobs,
        );
        last = Some(run);
    }
    let (all_jobs, edges): (Vec<Job>, Vec<bool>) = all_jobs.into_iter().unzip();
    backend_case(
        gpu,
        name,
        pass,
        options,
        last.as_ref().unwrap(),
        &resources,
        &all_jobs,
        &edges,
        extra,
    )
}

fn host_constants(job: &HostJob) -> Vec<(&'static str, Vec<u32>)> {
    job.constants
        .iter()
        .map(|(n, w)| (leak(n), w.clone()))
        .collect()
}

fn dispatches(_: usize, size: &Size) -> Vec<Op> {
    (0..FRAMES_PER_SIZE)
        .map(|i| Op::Dispatch(Dispatch::frame(i, size.render)))
        .collect()
}

fn motion_vector_size(options: u32, size: &Size) -> [u32; 2] {
    if options & LOW_RES_MV != 0 {
        size.max_render
    } else {
        size.display
    }
}

fn depth_clip_case(gpu: &gpu::Gpu, options: u32, sizes: &[Size]) -> compare::Comparison {
    let pass = FfxFsr2Pass::DepthClip;
    sized_case(
        gpu,
        "fsr2-depth-clip",
        pass,
        options,
        sizes,
        &dispatches,
        &|_, _| None,
        &|size, name, run, seed, resources, jobs| {
            let motion_size = motion_vector_size(options, size);
            let [
                reconstructed,
                dilated_mv,
                dilated_depth,
                reactive,
                tc,
                previous_mv,
                mv,
                color,
                exposure,
                masks,
                prepared,
            ] = [
                "FSR2_ReconstructedPrevNearestDepth",
                "FSR2_InternalDilatedVelocity1",
                "FSR2_DilatedDepth",
                "reactive",
                "transparency-and-composition",
                "FSR2_InternalDilatedVelocity2",
                "motion-vectors",
                "color",
                "exposure",
                "FSR2_DilatedReactiveMasks",
                "FSR2_PreparedInputColor",
            ]
            .map(name);
            let r = size.max_render;
            resources.extend([
                created(reconstructed, FfxSurfaceFormat::R32Uint, r, 1, UAV),
                created(dilated_mv, FfxSurfaceFormat::R16G16Float, r, 1, RT_UAV_DCC),
                created(dilated_depth, FfxSurfaceFormat::R32Float, r, 1, RT_UAV),
                application(reactive, FfxSurfaceFormat::R8Unorm, r),
                application(tc, FfxSurfaceFormat::R8Unorm, r),
                created(previous_mv, FfxSurfaceFormat::R16G16Float, r, 1, RT_UAV_DCC),
                application(mv, FfxSurfaceFormat::R16G16Float, motion_size),
                application(color, FfxSurfaceFormat::R16G16B16A16Float, r),
                application(exposure, FfxSurfaceFormat::R32G32Float, [1, 1]),
                created(masks, FfxSurfaceFormat::R8G8Unorm, r, 1, UAV_DCC),
                created(prepared, FfxSurfaceFormat::R16G16B16A16Float, r, 1, UAV_DCC),
            ]);
            let [w, h] = r;
            for (i, frame) in run.frames.iter().enumerate() {
                let seed = seed ^ u32::try_from(i).unwrap();
                let edge = i == FRAMES_PER_SIZE - 1;
                let job = &frame.jobs[&(pass as u32)];
                jobs.push((
                    Job {
                        bindings: vec![
                            binding(false, "r_input_color_jittered", color),
                            binding(false, "r_input_motion_vectors", mv),
                            binding(false, "r_input_exposure", exposure),
                            binding(false, "r_reactive_mask", reactive),
                            binding(false, "r_transparency_and_composition_mask", tc),
                            binding(
                                false,
                                "r_reconstructed_previous_nearest_depth",
                                reconstructed,
                            ),
                            binding(false, "r_dilated_motion_vectors", dilated_mv),
                            binding(false, "r_previous_dilated_motion_vectors", previous_mv),
                            binding(false, "r_dilatedDepth", dilated_depth),
                            binding(true, "rw_prepared_input_color", prepared),
                            binding(true, "rw_dilated_reactive_masks", masks),
                        ],
                        constants: host_constants(job),
                        contents: HashMap::from([
                            (color, colour(w, h, seed, edge)),
                            (
                                mv,
                                motion_vectors(motion_size[0], motion_size[1], seed, edge),
                            ),
                            (exposure, floats(&[[0.0, 0.7, 2.5][i % 3], 0.5])),
                            (reactive, mask(w, h, 1, seed)),
                            (tc, mask(w, h, 1, seed ^ 7)),
                            (reconstructed, reconstructed_depth(w, h, seed, edge)),
                            (dilated_mv, motion_vectors(w, h, seed ^ 3, edge)),
                            (previous_mv, motion_vectors(w, h, seed ^ 5, edge)),
                            (dilated_depth, depth(w, h, seed ^ 9, edge)),
                            (prepared, noise_bytes((w * h * 8) as usize, seed)),
                            (masks, noise_bytes((w * h * 2) as usize, seed ^ 1)),
                        ]),
                        dimensions: job.dimensions,
                    },
                    edge,
                ));
            }
        },
    )
}

fn lock_case(gpu: &gpu::Gpu, options: u32, sizes: &[Size]) -> compare::Comparison {
    let pass = FfxFsr2Pass::Lock;
    sized_case(
        gpu,
        "fsr2-lock",
        pass,
        options,
        sizes,
        &dispatches,
        &|_, _| None,
        &|size, name, run, seed, resources, jobs| {
            let [luma, new_locks, reconstructed] = [
                "FSR2_LockInputLuma",
                "FSR2_NewLocks",
                "FSR2_ReconstructedPrevNearestDepth",
            ]
            .map(name);
            resources.extend([
                created(luma, FfxSurfaceFormat::R16Float, size.max_render, 1, UAV),
                created(new_locks, FfxSurfaceFormat::R8Unorm, size.display, 1, UAV),
                created(
                    reconstructed,
                    FfxSurfaceFormat::R32Uint,
                    size.max_render,
                    1,
                    UAV,
                ),
            ]);
            let [w, h] = size.max_render;
            let [dw, dh] = size.display;
            for (i, frame) in run.frames.iter().enumerate() {
                let seed = seed ^ u32::try_from(i).unwrap();
                let edge = i == FRAMES_PER_SIZE - 1;
                let job = &frame.jobs[&(pass as u32)];
                jobs.push((
                    Job {
                        bindings: vec![
                            binding(false, "r_lock_input_luma", luma),
                            binding(true, "rw_new_locks", new_locks),
                            binding(
                                true,
                                "rw_reconstructed_previous_nearest_depth",
                                reconstructed,
                            ),
                        ],
                        constants: host_constants(job),
                        contents: HashMap::from([
                            (luma, lock_luma(w, h, seed)),
                            (new_locks, mask(dw, dh, 1, seed)),
                            (reconstructed, reconstructed_depth(w, h, seed, edge)),
                        ]),
                        dimensions: job.dimensions,
                    },
                    edge,
                ));
            }
        },
    )
}

fn reconstruct_previous_depth_case(
    gpu: &gpu::Gpu,
    options: u32,
    sizes: &[Size],
) -> compare::Comparison {
    let pass = FfxFsr2Pass::ReconstructPreviousDepth;
    sized_case(
        gpu,
        "fsr2-reconstruct-previous-depth",
        pass,
        options,
        sizes,
        &dispatches,
        &|_, _| None,
        &|size, name, run, seed, resources, jobs| {
            let motion_size = motion_vector_size(options, size);
            let [
                color,
                mv,
                input_depth,
                exposure,
                reconstructed,
                dilated_mv,
                dilated_depth,
                luma,
            ] = [
                "color",
                "motion-vectors",
                "depth",
                "exposure",
                "FSR2_ReconstructedPrevNearestDepth",
                "FSR2_InternalDilatedVelocity1",
                "FSR2_DilatedDepth",
                "FSR2_LockInputLuma",
            ]
            .map(name);
            let r = size.max_render;
            resources.extend([
                application(color, FfxSurfaceFormat::R16G16B16A16Float, r),
                application(mv, FfxSurfaceFormat::R16G16Float, motion_size),
                application(input_depth, FfxSurfaceFormat::R32Float, r),
                application(exposure, FfxSurfaceFormat::R32G32Float, [1, 1]),
                created(reconstructed, FfxSurfaceFormat::R32Uint, r, 1, UAV),
                created(dilated_mv, FfxSurfaceFormat::R16G16Float, r, 1, RT_UAV_DCC),
                created(dilated_depth, FfxSurfaceFormat::R32Float, r, 1, RT_UAV),
                created(luma, FfxSurfaceFormat::R16Float, r, 1, UAV),
            ]);
            let [w, h] = r;
            for (i, frame) in run.frames.iter().enumerate() {
                let seed = seed ^ u32::try_from(i).unwrap();
                let edge = i == FRAMES_PER_SIZE - 1;
                let job = &frame.jobs[&(pass as u32)];
                jobs.push((
                    Job {
                        bindings: vec![
                            binding(false, "r_input_color_jittered", color),
                            binding(false, "r_input_motion_vectors", mv),
                            binding(false, "r_input_depth", input_depth),
                            binding(false, "r_input_exposure", exposure),
                            binding(
                                true,
                                "rw_reconstructed_previous_nearest_depth",
                                reconstructed,
                            ),
                            binding(true, "rw_dilated_motion_vectors", dilated_mv),
                            binding(true, "rw_dilatedDepth", dilated_depth),
                            binding(true, "rw_lock_input_luma", luma),
                        ],
                        constants: host_constants(job),
                        contents: HashMap::from([
                            (color, colour(w, h, seed, edge)),
                            (
                                mv,
                                motion_vectors(motion_size[0], motion_size[1], seed, edge),
                            ),
                            (input_depth, depth(w, h, seed, edge)),
                            (exposure, floats(&[[0.0, 0.7, 2.5][i % 3], 0.5])),
                            (reconstructed, reconstructed_depth(w, h, seed, edge)),
                            (dilated_mv, noise_bytes((w * h * 4) as usize, seed)),
                            (dilated_depth, noise_bytes((w * h * 4) as usize, seed ^ 1)),
                            (luma, noise_bytes((w * h * 2) as usize, seed ^ 2)),
                        ]),
                        dimensions: job.dimensions,
                    },
                    edge,
                ));
            }
        },
    )
}

/// Frames of the SDK's auto-reactive dispatch (ffx_fsr2.cpp:1287-1294): the
/// TCR pass runs with the opaque-only colour and the dispatch's thresholds.
fn auto_reactive_dispatches(_: usize, size: &Size) -> Vec<Op> {
    (0..FRAMES_PER_SIZE)
        .map(|i| {
            let mut dispatch = Dispatch::frame(i, size.render);
            dispatch.present |= OPAQUE_ONLY;
            dispatch.auto_reactive = true;
            dispatch.auto_tc = [[0.05, 0.0, 0.3][i % 3], [1.0, 0.5, 2.0][i % 3]];
            dispatch.auto_reactive_scale_max = [[5.0, 1.0, 20.0][i % 3], [0.9, 0.2, 1.5][i % 3]];
            Op::Dispatch(dispatch)
        })
        .collect()
}

fn tcr_autogenerate_case(gpu: &gpu::Gpu, options: u32, sizes: &[Size]) -> compare::Comparison {
    let pass = FfxFsr2Pass::TcrAutogenerate;
    sized_case(
        gpu,
        "fsr2-tcr-autogenerate",
        pass,
        options,
        sizes,
        &auto_reactive_dispatches,
        &|_, _| None,
        &|size, name, run, seed, resources, jobs| {
            let motion_size = motion_vector_size(options, size);
            let [
                opaque,
                color,
                mv,
                reactive,
                tc,
                pre,
                post,
                auto_reactive,
                auto_composition,
                pre_out,
                post_out,
            ] = [
                "opaque-only",
                "color",
                "motion-vectors",
                "reactive",
                "transparency-and-composition",
                "FSR2_PrevPreAlpha0",
                "FSR2_PrevPostAlpha0",
                "FSR2_AutoReactive",
                "FSR2_AutoComposition",
                "FSR2_PrevPreAlpha1",
                "FSR2_PrevPostAlpha1",
            ]
            .map(name);
            let r = size.max_render;
            resources.extend([
                application(opaque, FfxSurfaceFormat::R16G16B16A16Float, r),
                application(color, FfxSurfaceFormat::R16G16B16A16Float, r),
                application(mv, FfxSurfaceFormat::R16G16Float, motion_size),
                application(reactive, FfxSurfaceFormat::R8Unorm, r),
                application(tc, FfxSurfaceFormat::R8Unorm, r),
                created(pre, FfxSurfaceFormat::R11G11B10Float, r, 1, UAV),
                created(post, FfxSurfaceFormat::R11G11B10Float, r, 1, UAV),
                created(auto_reactive, FfxSurfaceFormat::R8Unorm, r, 1, UAV),
                created(auto_composition, FfxSurfaceFormat::R8Unorm, r, 1, UAV),
                created(pre_out, FfxSurfaceFormat::R11G11B10Float, r, 1, UAV),
                created(post_out, FfxSurfaceFormat::R11G11B10Float, r, 1, UAV),
            ]);
            let [w, h] = r;
            for (i, frame) in run.frames.iter().enumerate() {
                let seed = seed ^ u32::try_from(i).unwrap();
                let edge = i == FRAMES_PER_SIZE - 1;
                let job = &frame.jobs[&(pass as u32)];
                // Post-alpha colour: in edge frames the opaque colour in some
                // stripes, so "no alpha" pixels and flat neighbourhoods occur.
                let opaque_colour = colour(w, h, seed, edge);
                let mut post_alpha = colour(w, h, seed ^ 11, edge);
                for (texel, (from, to)) in opaque_colour
                    .chunks(8)
                    .zip(post_alpha.chunks_mut(8))
                    .enumerate()
                {
                    if edge && (texel / 3).is_multiple_of(3) {
                        to.copy_from_slice(from);
                    }
                }
                jobs.push((
                    Job {
                        bindings: vec![
                            binding(false, "r_input_color_jittered", color),
                            binding(false, "r_input_opaque_only", opaque),
                            binding(false, "r_input_motion_vectors", mv),
                            binding(false, "r_reactive_mask", reactive),
                            binding(false, "r_transparency_and_composition_mask", tc),
                            binding(false, "r_input_prev_color_pre_alpha", pre),
                            binding(false, "r_input_prev_color_post_alpha", post),
                            binding(true, "rw_output_autoreactive", auto_reactive),
                            binding(true, "rw_output_autocomposition", auto_composition),
                            binding(true, "rw_output_prev_color_pre_alpha", pre_out),
                            binding(true, "rw_output_prev_color_post_alpha", post_out),
                        ],
                        constants: host_constants(job),
                        contents: HashMap::from([
                            (opaque, opaque_colour),
                            (color, post_alpha),
                            (
                                mv,
                                motion_vectors(motion_size[0], motion_size[1], seed, edge),
                            ),
                            (reactive, mask(w, h, 1, seed)),
                            (tc, mask(w, h, 1, seed ^ 7)),
                            (pre, packed_colour(w, h, seed, edge)),
                            (post, packed_colour(w, h, seed ^ 13, edge)),
                            (auto_reactive, noise_bytes((w * h) as usize, seed)),
                            (auto_composition, noise_bytes((w * h) as usize, seed ^ 1)),
                            (pre_out, noise_bytes((w * h * 4) as usize, seed ^ 2)),
                            (post_out, noise_bytes((w * h * 4) as usize, seed ^ 3)),
                        ]),
                        dimensions: job.dimensions,
                    },
                    edge,
                ));
            }
        },
    )
}

/// `ffxFsr2ContextGenerateReactiveMask` calls with every flag combination
/// (FFX_FSR2_AUTOREACTIVEFLAGS_*) and varied scale, cutoff and binary value.
fn generate_reactive_ops(s: usize, size: &Size) -> Vec<Op> {
    (0..16u32)
        .map(|flags| {
            let i = flags as usize + s;
            Op::Generate(Generate {
                render: size.render,
                scale: [1.0, 0.5, 4.0][i % 3],
                cutoff_threshold: [0.2, 0.0, 0.9][i % 3],
                binary_value: [0.9, 1.0, 0.3][i % 3],
                flags,
            })
        })
        .collect()
}

fn generate_reactive_case(gpu: &gpu::Gpu, options: u32, sizes: &[Size]) -> compare::Comparison {
    sized_case(
        gpu,
        "fsr2-generate-reactive",
        FfxFsr2Pass::GenerateReactive,
        options,
        sizes,
        &generate_reactive_ops,
        &|_, _| None,
        &|size, name, run, seed, resources, jobs| {
            let [opaque, color, out] = ["opaque-only", "color", "out-reactive"].map(name);
            let r = size.max_render;
            resources.extend([
                application(opaque, FfxSurfaceFormat::R16G16B16A16Float, r),
                application(color, FfxSurfaceFormat::R16G16B16A16Float, r),
                application(out, FfxSurfaceFormat::R8Unorm, r),
            ]);
            let [w, h] = r;
            // SDK 1.1.4 never schedules the job (ffx_fsr2.cpp:1569); its constants
            // are the ones it stages (:1553-1561) and its dimensions :1515-1517's.
            let dimensions = [size.render[0].div_ceil(8), size.render[1].div_ceil(8), 1];
            for (i, frame) in run.frames.iter().enumerate() {
                let seed = seed ^ u32::try_from(i).unwrap();
                let edge = i % 2 == 1;
                assert_eq!(frame.staged.len(), 1, "the reactive-mask constants");
                jobs.push((
                    Job {
                        bindings: vec![
                            binding(false, "r_input_color_jittered", color),
                            binding(false, "r_input_opaque_only", opaque),
                            binding(true, "rw_output_autoreactive", out),
                        ],
                        constants: vec![("cbGenerateReactive", frame.staged[0].clone())],
                        contents: HashMap::from([
                            (opaque, colour(w, h, seed, edge)),
                            (color, colour(w, h, seed ^ 0x55, edge)),
                            (out, noise_bytes((w * h) as usize, seed)),
                        ]),
                        dimensions,
                    },
                    edge,
                ));
            }
        },
    )
}

/// Sizes of the luminance pyramid: `FSR2_ExposureMips` (half the maximum
/// render size, full chain) must hold the mips 4 and 5 the pass binds. SPD
/// runs its last-workgroup epilogue (mips 6 and up, the atomic counter) from
/// 128 render texels; partial 64x64 tiles and dynamic resolution included.
const PYRAMID_SIZES: &[Size] = &[
    size([64, 3], [64, 3], [96, 5]),
    size([97, 61], [97, 61], [97, 61]),
    size([130, 67], [130, 67], [195, 100]),
    size([257, 75], [200, 60], [385, 112]),
];

/// SDK-P14: SPD's epilogue (mips 6 and up, run when `mips` exceeds 6,
/// ffx_spd.h:538-555) runs in the last workgroup and reads the mip 5 that
/// every workgroup's thread 0 wrote. FSR2 declares `rw_img_mip_5`
/// globallycoherent (ffx_fsr2_callbacks_hlsl.h:458), which WGSL cannot
/// express; SPIRV-Cross's Metal only fences a thread's reads of its own
/// writes, and neither side has a device-scope fence, so on Metal the
/// epilogue may read mip-5 texels from before the dispatch. In FSR2 its only
/// output is the exposure (`SpdStore` at `MipCount() - 1`); a job that
/// repeats the previous one reads back the same values either way.
fn stale_mip_5(d: &compare::Difference, job: &Job) -> Option<&'static str> {
    // Fsr2SpdConstants (ffx_fsr2_private.h:137-143): mips first.
    let mips = job
        .constants
        .iter()
        .find(|(name, _)| *name == "cbSPD")
        .unwrap()
        .1[0];
    // A repeated job (no mip contents) reads back what it writes.
    let mip_5_set = job
        .contents
        .keys()
        .any(|name| name.starts_with("FSR2_ExposureMips"));
    (d.resource.starts_with("FSR2_AutoExposure") && mips > 6 && mip_5_set).then_some("SDK-P14")
}

fn luminance_pyramid_case(gpu: &gpu::Gpu, options: u32, sizes: &[Size]) -> compare::Comparison {
    let pass = FfxFsr2Pass::ComputeLuminancePyramid;
    sized_case(
        gpu,
        "fsr2-compute-luminance-pyramid",
        pass,
        options,
        sizes,
        &dispatches,
        &stale_mip_5,
        &|size, name, run, seed, resources, jobs| {
            let [color, counter, mips, exposure] = [
                "color",
                "FSR2_SpdAtomicCounter",
                "FSR2_ExposureMips",
                "FSR2_AutoExposure",
            ]
            .map(name);
            // ffx_fsr2.cpp:664-672, 701-710, 767-776.
            let mip_size = size.max_render.map(|v| v / 2);
            let mip_count = u32::BITS - mip_size[0].max(mip_size[1]).leading_zeros();
            resources.extend([
                application(color, FfxSurfaceFormat::R16G16B16A16Float, size.max_render),
                created(counter, FfxSurfaceFormat::R32Uint, [1, 1], 1, UAV),
                created(mips, FfxSurfaceFormat::R16Float, mip_size, mip_count, UAV),
                created(exposure, FfxSurfaceFormat::R32G32Float, [1, 1], 1, UAV),
            ]);
            let [w, h] = size.max_render;
            for (i, frame) in run.frames.iter().enumerate() {
                let seed = seed ^ u32::try_from(i).unwrap();
                let edge = i == FRAMES_PER_SIZE - 1;
                let job = &frame.jobs[&(pass as u32)];
                let color_contents = colour(w, h, seed, edge);
                // Each frame runs twice. The first job's mip 5 holds other values
                // before it (noise), so SPD's epilogue may read them (SDK-P14);
                // the repeat reads back the mip 5 it writes again, whatever the
                // visibility, so its exposure is compared like any output.
                let mut random = Random(seed | 1);
                let mut texels = Vec::new();
                for mip in 0..mip_count {
                    let (mw, mh) = ((mip_size[0] >> mip).max(1), (mip_size[1] >> mip).max(1));
                    texels.extend(
                        (0..mw * mh).flat_map(|_| random.half_up_to(16, true).to_le_bytes()),
                    );
                }
                // The first frame starts from the SDK's initial counter and the
                // reset clear of the exposure (ffx_fsr2.cpp:1236-1240); the second
                // keeps what the previous job left (an exposure below
                // resetAutoExposureAverageSmoothing, so smoothed); the third
                // starts from a converged one (at or above it).
                let exposure_contents = match i {
                    0 => Some(floats(&[-1.0, 1e8])),
                    2 => Some(floats(&[0.25, 3e8])),
                    _ => None,
                };
                for repeat in [false, true] {
                    let mut contents = HashMap::from([(color, color_contents.clone())]);
                    if !repeat {
                        contents.insert(mips, texels.clone());
                    }
                    if i == 0 && !repeat {
                        contents.insert(counter, 0u32.to_le_bytes().to_vec());
                    }
                    if let Some(bytes) = &exposure_contents {
                        contents.insert(exposure, bytes.clone());
                    }
                    let mut bindings = vec![
                        binding(false, "r_input_color_jittered", color),
                        binding(true, "rw_spd_global_atomic", counter),
                        binding(true, "rw_img_mip_shading_change", mips),
                        binding(true, "rw_img_mip_5", mips),
                        binding(true, "rw_auto_exposure", exposure),
                    ];
                    // FFX_FSR2_SHADING_CHANGE_MIP_LEVEL and mip 5 (ffx_fsr2.cpp:993-1004).
                    bindings[2].mip = 4;
                    bindings[3].mip = 5;
                    jobs.push((
                        Job {
                            bindings,
                            constants: host_constants(job),
                            contents,
                            dimensions: job.dimensions,
                        },
                        edge,
                    ));
                }
            }
        },
    )
}

/// Run `case` for every permutation options value the SDK compiles for the
/// pass (`fp16_table`: the blob accessor also selects its 16-bit table) at
/// `sizes`, and at [`LARGE`] for `large`.
fn every_permutation(
    fp16_table: bool,
    sizes: &[Size],
    large: &[u32],
    case: fn(&gpu::Gpu, u32, &[Size]) -> compare::Comparison,
) {
    let gpu = gpu::Gpu::new(true, None);
    let mut failures = Vec::new();
    let runs = permutations(fp16_table)
        .into_iter()
        .map(|options| (options, sizes))
        .chain(
            large
                .iter()
                .map(|&options| (options, std::slice::from_ref(&LARGE))),
        );
    for (options, sizes) in runs {
        if !case(&gpu, options, sizes).accepted() {
            failures.push(format!(
                "{options:#04x} at {}x{}",
                sizes[0].render[0], sizes[0].render[1]
            ));
        }
    }
    assert!(failures.is_empty(), "rejected: {failures:#?}");
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 variants"]
fn reconstruct_previous_depth_matches_the_hlsl_in_every_permutation() {
    every_permutation(
        true,
        SIZES,
        &[
            INVERTED_DEPTH | JITTERED_MV | LOW_RES_MV | FP16,
            HDR | LANCZOS,
        ],
        reconstruct_previous_depth_case,
    );
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 variants"]
fn depth_clip_matches_the_hlsl_in_every_permutation() {
    every_permutation(
        true,
        SIZES,
        &[
            INVERTED_DEPTH | JITTERED_MV | LOW_RES_MV | FP16,
            HDR | LANCZOS,
        ],
        depth_clip_case,
    );
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 variants"]
fn lock_matches_the_hlsl_in_every_permutation() {
    every_permutation(
        true,
        SIZES,
        &[INVERTED_DEPTH | LOW_RES_MV | FP16, HDR | LANCZOS],
        lock_case,
    );
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 variants"]
fn compute_luminance_pyramid_matches_the_hlsl_in_every_permutation() {
    every_permutation(
        false,
        PYRAMID_SIZES,
        &[INVERTED_DEPTH | LOW_RES_MV, HDR | LANCZOS],
        luminance_pyramid_case,
    );
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 variants"]
fn generate_reactive_matches_the_hlsl_in_every_permutation() {
    every_permutation(
        true,
        SIZES,
        &[LOW_RES_MV | FP16, HDR | LANCZOS],
        generate_reactive_case,
    );
}

#[test]
#[ignore = "needs Metal, clang++ and the compiled FSR2 variants"]
fn tcr_autogenerate_matches_the_hlsl_in_every_permutation() {
    every_permutation(
        true,
        SIZES,
        &[
            INVERTED_DEPTH | JITTERED_MV | LOW_RES_MV | FP16,
            HDR | LANCZOS,
        ],
        tcr_autogenerate_case,
    );
}
