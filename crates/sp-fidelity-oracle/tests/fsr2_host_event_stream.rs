//! The FSR2 host port against AMD's unchanged C++ host: `oracle/fsr2_host.cpp`
//! drives `ffx_fsr2.cpp` and [`run_rust`] drives the port, word for word, both
//! through a recording backend. Every event (resources and initialization
//! data, pipelines and their DXC-reflected bindings, samplers, root and staged
//! constants, clears, dispatches, registrations, execution, messages and
//! destruction) must be identical.
//!
//! Word stream (after the device capabilities): `0` runs the helpers
//! (`quality` entries of mode, display width and height; `phase-count` entries
//! of render and display width; `jitter-offset` entries of index and phase
//! count). `1` runs a context: flags, maximum render size, display size, input
//! color resource size, frame count, then per frame `0` and a dispatch (see
//! [`Dispatch::words`]) or `1` and a reactive-mask generation (see
//! [`Generate::words`]).
use serde_json::{Value, json};
use sp_fidelity::error::FfxErrorCode;
use sp_fidelity::fsr2::*;
use sp_fidelity::interface::FfxInterfaceRef;
use sp_fidelity::types::*;
use sp_fidelity_oracle::FSR2;
use sp_fidelity_oracle::host::{build_cpp_host, run_cpp_host};
use sp_fidelity_oracle::recorder::{Recorder, record_message};
use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::rc::Rc;
use std::sync::OnceLock;

/// `word()`/`scalar()` of `oracle/host.cpp`.
struct Words<'a> {
    words: &'a [u32],
    at: usize,
}

impl Words<'_> {
    fn word(&mut self) -> u32 {
        self.at += 1;
        self.words[self.at - 1]
    }

    fn scalar(&mut self) -> f32 {
        f32::from_bits(self.word())
    }
}

fn quality_mode(value: u32) -> FfxFsr2QualityMode {
    match value {
        1 => FfxFsr2QualityMode::Quality,
        2 => FfxFsr2QualityMode::Balanced,
        3 => FfxFsr2QualityMode::Performance,
        4 => FfxFsr2QualityMode::UltraPerformance,
        _ => panic!("quality mode {value}"),
    }
}

fn status<T>(result: &Result<T, FfxErrorCode>) -> FfxErrorCode {
    result.as_ref().err().copied().unwrap_or(0)
}

/// `helpers()` of `oracle/fsr2_host.cpp`.
fn helpers(recorder: &Rc<RefCell<Recorder>>, w: &mut Words) {
    let push = |event: Value| recorder.borrow_mut().events.push(event);
    for _ in 0..w.word() {
        let mode = quality_mode(w.word());
        let (display_width, display_height) = (w.word(), w.word());
        let result =
            ffx_fsr2_get_render_resolution_from_quality_mode(display_width, display_height, mode);
        let (render_width, render_height) = result.unwrap_or((0, 0));
        push(json!([
            "quality",
            mode as u32,
            display_width,
            display_height,
            ffx_fsr2_get_upscale_ratio_from_quality_mode(mode).to_bits(),
            status(&result),
            render_width,
            render_height
        ]));
    }
    for _ in 0..w.word() {
        let (render_width, display_width) = (w.word() as i32, w.word() as i32);
        push(json!([
            "phase-count",
            render_width,
            display_width,
            ffx_fsr2_get_jitter_phase_count(render_width, display_width)
        ]));
    }
    for _ in 0..w.word() {
        let (index, phase_count) = (w.word() as i32, w.word() as i32);
        let result = ffx_fsr2_get_jitter_offset(index, phase_count);
        let (x, y) = result.unwrap_or((0.0, 0.0));
        push(json!([
            "jitter-offset",
            index,
            phase_count,
            status(&result),
            x.to_bits(),
            y.to_bits()
        ]));
    }
    let null = ffx_fsr2_resource_is_null(&FfxResource::default());
    let color = recorder.borrow_mut().external("color", 1, 1);
    push(json!([
        "resource-is-null",
        u8::from(null),
        u8::from(ffx_fsr2_resource_is_null(&color))
    ]));
    push(json!(["version", ffx_fsr2_get_effect_version()]));
}

fn optional(present: bool, resource: &FfxResource) -> FfxResource {
    if present {
        resource.clone()
    } else {
        FfxResource::default()
    }
}

/// `sequence()` of `oracle/fsr2_host.cpp`.
fn sequence(recorder: &Rc<RefCell<Recorder>>, w: &mut Words) {
    let backend: FfxInterfaceRef = recorder.clone();
    let description = FfxFsr2ContextDescription {
        flags: w.word(),
        max_render_size: FfxDimensions2D {
            width: w.word(),
            height: w.word(),
        },
        display_size: FfxDimensions2D {
            width: w.word(),
            height: w.word(),
        },
        fp_message: None,
        backend_interface: backend,
    };
    let (color_width, color_height) = (w.word(), w.word());
    ffx_fsr2_set_global_debug_message(Some(record_message), 0).unwrap();
    Recorder::record_messages(recorder);

    let (max_render, display) = (description.max_render_size, description.display_size);
    let external = |label, width, height| recorder.borrow_mut().external(label, width, height);
    let color = external("color", color_width, color_height);
    let depth = external("depth", max_render.width, max_render.height);
    let motion_vectors = external("motion-vectors", display.width, display.height);
    let exposure = external("exposure", 1, 1);
    let reactive = external("reactive", max_render.width, max_render.height);
    let transparency_and_composition = external(
        "transparency-and-composition",
        max_render.width,
        max_render.height,
    );
    let output = external("output", display.width, display.height);
    let opaque_only = external("opaque-only", max_render.width, max_render.height);
    let out_reactive = external("out-reactive", max_render.width, max_render.height);

    let mut context = FfxFsr2Context::default();
    let created = ffx_fsr2_context_create(&mut context, &description);
    recorder.borrow_mut().result("create-result", created);
    if created.is_err() {
        return;
    }

    let queried = ffx_fsr2_context_get_gpu_memory_usage(&mut context);
    let usage = queried.unwrap_or_default();
    recorder.borrow_mut().events.push(json!([
        "memory-usage-result",
        status(&queried),
        usage.total_usage_in_bytes,
        usage.aliasable_usage_in_bytes
    ]));

    for index in 0..w.word() as usize {
        recorder.borrow_mut().frame(index);
        if w.word() == 0 {
            let present = w.word();
            let mut dispatch = FfxFsr2DispatchDescription {
                command_list: usize::from(present & 1 != 0),
                color: color.clone(),
                depth: optional(present & 2 != 0, &depth),
                motion_vectors: optional(present & 4 != 0, &motion_vectors),
                exposure: optional(present & 8 != 0, &exposure),
                reactive: optional(present & 16 != 0, &reactive),
                transparency_and_composition: optional(
                    present & 32 != 0,
                    &transparency_and_composition,
                ),
                output: optional(present & 64 != 0, &output),
                color_opaque_only: optional(present & 128 != 0, &opaque_only),
                ..Default::default()
            };
            let render_mode = w.word();
            if render_mode == 0 {
                dispatch.render_size.width = w.word();
                dispatch.render_size.height = w.word();
            } else {
                let (width, height) = ffx_fsr2_get_render_resolution_from_quality_mode(
                    display.width,
                    display.height,
                    quality_mode(render_mode),
                )
                .expect("quality mode rejected");
                dispatch.render_size = FfxDimensions2D { width, height };
            }
            if w.word() == 0 {
                let jitter_index = w.word() as i32;
                let phase_count = ffx_fsr2_get_jitter_phase_count(
                    dispatch.render_size.width as i32,
                    display.width as i32,
                );
                if let Ok((x, y)) = ffx_fsr2_get_jitter_offset(jitter_index, phase_count) {
                    dispatch.jitter_offset = FfxFloatCoords2D { x, y };
                }
            } else {
                dispatch.jitter_offset.x = w.scalar();
                dispatch.jitter_offset.y = w.scalar();
            }
            dispatch.motion_vector_scale.x = w.scalar();
            dispatch.motion_vector_scale.y = w.scalar();
            dispatch.enable_sharpening = w.word() != 0;
            dispatch.sharpness = w.scalar();
            dispatch.frame_time_delta = w.scalar();
            dispatch.pre_exposure = w.scalar();
            dispatch.reset = w.word() != 0;
            dispatch.camera_near = w.scalar();
            dispatch.camera_far = w.scalar();
            dispatch.camera_fov_angle_vertical = w.scalar();
            dispatch.view_space_to_meters_factor = w.scalar();
            dispatch.enable_auto_reactive = w.word() != 0;
            dispatch.auto_tc_threshold = w.scalar();
            dispatch.auto_tc_scale = w.scalar();
            dispatch.auto_reactive_scale = w.scalar();
            dispatch.auto_reactive_max = w.scalar();
            let dispatched = ffx_fsr2_context_dispatch(&mut context, &dispatch);
            recorder.borrow_mut().result("dispatch-result", dispatched);
        } else {
            let generate = FfxFsr2GenerateReactiveDescription {
                command_list: usize::from(w.word() != 0),
                color_opaque_only: opaque_only.clone(),
                color_pre_upscale: color.clone(),
                out_reactive: out_reactive.clone(),
                render_size: FfxDimensions2D {
                    width: w.word(),
                    height: w.word(),
                },
                scale: w.scalar(),
                cutoff_threshold: w.scalar(),
                binary_value: w.scalar(),
                flags: w.word(),
            };
            let generated = ffx_fsr2_context_generate_reactive_mask(&mut context, &generate);
            recorder
                .borrow_mut()
                .result("generate-reactive-result", generated);
        }
    }
    let destroyed = ffx_fsr2_context_destroy(&mut context);
    recorder.borrow_mut().result("destroy-result", destroyed);
}

/// The port's events and initialization data for `words`.
fn run_rust(
    capabilities: FfxDeviceCapabilities,
    words: &[u32],
) -> (Vec<Value>, HashMap<String, Vec<u8>>) {
    let recorder = Rc::new(RefCell::new(Recorder::new(capabilities)));
    let mut w = Words { words, at: 0 };
    if w.word() == 0 {
        helpers(&recorder, &mut w);
    } else {
        sequence(&recorder, &mut w);
    }
    let mut recorder = recorder.borrow_mut();
    (
        std::mem::take(&mut recorder.events),
        std::mem::take(&mut recorder.init_data),
    )
}

/// AMD's C++ host events and initialization data for `words`.
fn run_cpp(
    name: &str,
    capabilities: FfxDeviceCapabilities,
    words: &[u32],
) -> (Vec<Value>, HashMap<String, Vec<u8>>) {
    static HOST: OnceLock<(PathBuf, PathBuf)> = OnceLock::new();
    let root = PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join("fsr2-host");
    let host = HOST.get_or_init(|| build_cpp_host(&root.join("build"), &FSR2));
    let directory = root.join(name);
    let init_data = directory.join("init-data");
    let _ = fs::remove_dir_all(&directory);
    fs::create_dir_all(&init_data).unwrap();
    let output = run_cpp_host(
        host,
        &capabilities,
        words,
        &directory.join("input.words"),
        &init_data,
    );
    let events = output
        .lines()
        .map(|line| serde_json::from_str(line).unwrap_or_else(|e| panic!("{line}: {e}")))
        .collect();
    let data = fs::read_dir(&init_data)
        .unwrap()
        .map(|entry| {
            let path = entry.unwrap().path();
            let name = path.file_stem().unwrap().to_string_lossy().into_owned();
            (name, fs::read(path).unwrap())
        })
        .collect();
    (events, data)
}

/// Runs both hosts and requires identical event streams and initialization
/// data; returns the number of events compared.
fn compare(name: &str, capabilities: FfxDeviceCapabilities, words: &[u32]) -> usize {
    let (cpp, cpp_data) = run_cpp(name, capabilities, words);
    let (rust, rust_data) = run_rust(capabilities, words);
    for (index, (c, r)) in cpp.iter().zip(&rust).enumerate() {
        assert!(
            c == r,
            "{name}: event {index} differs\n  C++:  {c}\n  Rust: {r}\n  preceded by C++ {}",
            cpp[index.saturating_sub(3)..index]
                .iter()
                .map(Value::to_string)
                .collect::<Vec<_>>()
                .join("\n    ")
        );
    }
    assert_eq!(cpp.len(), rust.len(), "{name}: event counts differ");
    assert_eq!(
        cpp_data.keys().collect::<std::collections::BTreeSet<_>>(),
        rust_data.keys().collect(),
        "{name}: initialization data resources differ"
    );
    for (resource, data) in &cpp_data {
        assert!(
            *data == rust_data[resource],
            "{name}: {resource} initialization data differs"
        );
    }
    println!("{name}: {} events identical", cpp.len());
    cpp.len()
}

/// Device capabilities: AMD RDNA (wave32 to wave64, SM6.6, FP16), the wgpu
/// backend on Apple GPUs (wave32, SM6.2, FP16), a wave64-only FP32 device
/// (SM6.5) and a wave32 FP32 device (SM6.0).
fn capabilities(
    fp16: bool,
    wave_min: u32,
    wave_max: u32,
    sm: FfxShaderModel,
) -> FfxDeviceCapabilities {
    FfxDeviceCapabilities {
        maximum_supported_shader_model: sm,
        wave_lane_count_min: wave_min,
        wave_lane_count_max: wave_max,
        fp16_supported: fp16,
        ..Default::default()
    }
}

fn rdna() -> FfxDeviceCapabilities {
    capabilities(true, 32, 64, FfxShaderModel::ShaderModel6_6)
}

fn wgpu() -> FfxDeviceCapabilities {
    capabilities(true, 32, 32, FfxShaderModel::ShaderModel6_2)
}

fn wave64_fp32() -> FfxDeviceCapabilities {
    capabilities(false, 64, 64, FfxShaderModel::ShaderModel6_5)
}

fn wave32_fp32() -> FfxDeviceCapabilities {
    capabilities(false, 32, 32, FfxShaderModel::ShaderModel6_0)
}

/// Present bits of a dispatch: command list, depth, motion vectors, exposure,
/// reactive, transparency and composition, output, opaque-only color.
const COMMAND_LIST: u32 = 1;
const DEPTH: u32 = 2;
const MOTION_VECTORS: u32 = 4;
const EXPOSURE: u32 = 8;
const REACTIVE: u32 = 16;
const TRANSPARENCY_AND_COMPOSITION: u32 = 32;
const OUTPUT: u32 = 64;
const OPAQUE_ONLY: u32 = 128;
const REQUIRED: u32 = COMMAND_LIST | DEPTH | MOTION_VECTORS | OUTPUT;

#[derive(Clone, Copy)]
enum RenderSize {
    Quality(FfxFsr2QualityMode),
    Explicit(u32, u32),
}

#[derive(Clone, Copy)]
enum Jitter {
    Sequence(i32),
    Explicit(f32, f32),
}

#[derive(Clone, Copy)]
struct Dispatch {
    present: u32,
    render: RenderSize,
    jitter: Jitter,
    motion_vector_scale: (f32, f32),
    sharpen: bool,
    sharpness: f32,
    frame_time_delta: f32,
    pre_exposure: f32,
    reset: bool,
    camera_near: f32,
    camera_far: f32,
    fov: f32,
    view_space_to_meters: f32,
    auto_reactive: bool,
    auto_tc: (f32, f32),
    auto_reactive_scale_max: (f32, f32),
}

impl Dispatch {
    /// Present bits; render size (`0`, width, height or a quality mode);
    /// jitter (`0` and the index into the SDK sequence, or `1`, x, y); motion
    /// vector scale; sharpening and sharpness; frame time; pre-exposure;
    /// reset; camera near, far and vertical field of view; view space to
    /// meters; auto-reactive; its TC threshold and scale and reactive scale and
    /// maximum.
    fn words(&self, words: &mut Vec<u32>) {
        words.extend([0, self.present]);
        match self.render {
            RenderSize::Quality(mode) => words.push(mode as u32),
            RenderSize::Explicit(width, height) => words.extend([0, width, height]),
        }
        match self.jitter {
            Jitter::Sequence(index) => words.extend([0, index as u32]),
            Jitter::Explicit(x, y) => words.extend([1, x.to_bits(), y.to_bits()]),
        }
        words.extend([
            self.motion_vector_scale.0.to_bits(),
            self.motion_vector_scale.1.to_bits(),
            u32::from(self.sharpen),
            self.sharpness.to_bits(),
            self.frame_time_delta.to_bits(),
            self.pre_exposure.to_bits(),
            u32::from(self.reset),
            self.camera_near.to_bits(),
            self.camera_far.to_bits(),
            self.fov.to_bits(),
            self.view_space_to_meters.to_bits(),
            u32::from(self.auto_reactive),
            self.auto_tc.0.to_bits(),
            self.auto_tc.1.to_bits(),
            self.auto_reactive_scale_max.0.to_bits(),
            self.auto_reactive_scale_max.1.to_bits(),
        ]);
    }
}

#[derive(Clone, Copy)]
struct Generate {
    command_list: bool,
    render: (u32, u32),
    scale: f32,
    cutoff_threshold: f32,
    binary_value: f32,
    flags: u32,
}

impl Generate {
    /// Command list present, render size, scale, cutoff threshold, binary
    /// value and flags.
    fn words(&self, words: &mut Vec<u32>) {
        words.extend([
            1,
            u32::from(self.command_list),
            self.render.0,
            self.render.1,
            self.scale.to_bits(),
            self.cutoff_threshold.to_bits(),
            self.binary_value.to_bits(),
            self.flags,
        ]);
    }
}

enum Op {
    Dispatch(Dispatch),
    Generate(Generate),
}

struct Case {
    flags: u32,
    max_render: (u32, u32),
    display: (u32, u32),
    color: (u32, u32),
    ops: Vec<Op>,
}

impl Case {
    fn words(&self) -> Vec<u32> {
        let mut words = vec![
            1,
            self.flags,
            self.max_render.0,
            self.max_render.1,
            self.display.0,
            self.display.1,
            self.color.0,
            self.color.1,
            u32::try_from(self.ops.len()).unwrap(),
        ];
        for op in &self.ops {
            match op {
                Op::Dispatch(dispatch) => dispatch.words(&mut words),
                Op::Generate(generate) => generate.words(&mut words),
            }
        }
        words
    }
}

/// A typical frame `index` of an application at `render` size: the SDK jitter
/// sequence, varying frame time and pre-exposure, a regular camera.
fn frame(index: usize, render: RenderSize) -> Dispatch {
    let i = index as f32;
    Dispatch {
        present: REQUIRED,
        render,
        jitter: Jitter::Sequence(index as i32),
        motion_vector_scale: (1280.0 - i, -(720.0 - i)),
        sharpen: false,
        sharpness: 0.8,
        frame_time_delta: 16.6 + (index % 7) as f32 * 0.37,
        pre_exposure: 1.0 + (index % 5) as f32 * 0.125,
        reset: false,
        camera_near: 0.1,
        camera_far: 1000.0,
        fov: 1.0 + i * 0.001,
        view_space_to_meters: 1.0,
        auto_reactive: false,
        auto_tc: (0.05, 1.0),
        auto_reactive_scale_max: (5.0, 0.9),
    }
}

fn generate(render: (u32, u32), flags: u32) -> Generate {
    Generate {
        command_list: true,
        render,
        scale: 1.0,
        cutoff_threshold: 0.2,
        binary_value: 0.9,
        flags,
    }
}

#[test]
fn helpers_match_the_sdk() {
    let mut words = vec![0];
    let displays = [(1920, 1080), (3840, 2160), (1283, 719), (1, 1), (7, 3)];
    words.push(u32::try_from(displays.len() * 4).unwrap());
    for mode in 1..=4 {
        for (width, height) in displays {
            words.extend([mode, width, height]);
        }
    }
    let phases: Vec<(i32, i32)> = [
        (1280, 1920),
        (1129, 1920),
        (960, 1920),
        (640, 1920),
        (1920, 1920),
        (857, 1283),
        (1, 3),
        (3, 1),
        (1000, 1001),
    ]
    .into();
    words.push(u32::try_from(phases.len()).unwrap());
    for (render, display) in phases {
        words.extend([render as u32, display as u32]);
    }
    let mut jitters = Vec::new();
    for phase_count in [18, 23, 32, 72, 8, 1] {
        for index in [
            0, 1, 2, 5, 17, 18, 19, 22, 23, 31, 32, 71, 72, 73, 100, 1000, 12345,
        ] {
            jitters.push((index, phase_count));
        }
    }
    jitters.extend([(-1, 18), (-19, 18), (0, 0), (5, 0), (5, -4), (i32::MAX, 72)]);
    words.push(u32::try_from(jitters.len()).unwrap());
    for (index, phase_count) in jitters {
        words.extend([index as u32, phase_count as u32]);
    }
    compare("helpers", rdna(), &words);
}

/// wgpu-like device, HDR with auto exposure: 1080p Quality, 120 frames
/// (jitter phase 18 wraps), sharpening toggles, optional inputs, a reset.
#[test]
fn wgpu_hdr_auto_exposure_quality() {
    let render = RenderSize::Quality(FfxFsr2QualityMode::Quality);
    let ops = (0..120)
        .map(|index| {
            let mut f = frame(index, render);
            f.sharpen = (index / 10) % 2 == 1;
            f.sharpness = (index % 11) as f32 / 10.0;
            f.reset = index == 60;
            if index % 3 == 0 {
                f.present |= EXPOSURE | REACTIVE;
            }
            if index % 4 == 1 {
                f.present |= TRANSPARENCY_AND_COMPOSITION;
            }
            if index % 9 == 4 {
                f.view_space_to_meters = 0.0;
            }
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE | FFX_FSR2_ENABLE_AUTO_EXPOSURE,
        max_render: (1280, 720),
        display: (1920, 1080),
        color: (1280, 720),
        ops,
    };
    compare("wgpu_hdr_auto_exposure_quality", wgpu(), &case.words());
}

/// wgpu-like device, HDR with dynamic resolution: render size changes every
/// frame (explicit and quality presets), so the jitter phase count steps.
#[test]
fn wgpu_hdr_dynamic_resolution() {
    let ops = (0..110)
        .map(|index| {
            let render = match index % 13 {
                0 => RenderSize::Quality(FfxFsr2QualityMode::Performance),
                5 => RenderSize::Quality(FfxFsr2QualityMode::Balanced),
                _ => {
                    let scale = 0.5 + ((index * 37) % 50) as f32 / 100.0;
                    RenderSize::Explicit((2560.0 * scale) as u32, (1440.0 * scale) as u32)
                }
            };
            let mut f = frame(index, render);
            f.sharpen = index % 4 == 0;
            f.frame_time_delta = if index % 17 == 3 {
                2500.0
            } else {
                8.3 + index as f32
            };
            f.reset = index == 45 || index == 46;
            f.camera_near = 1000.0;
            f.camera_far = 0.5;
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE | FFX_FSR2_ENABLE_DYNAMIC_RESOLUTION,
        max_render: (2560, 1440),
        display: (2560, 1440),
        color: (2560, 1440),
        ops,
    };
    compare("wgpu_hdr_dynamic_resolution", wgpu(), &case.words());
}

/// RDNA-like device (Lanczos LUT, forced wave64, FP16), default flags: 4K
/// Performance with an application exposure, auto-reactive (TCR autogen) and
/// reactive-mask generation.
#[test]
fn rdna_performance_auto_reactive() {
    let render = RenderSize::Quality(FfxFsr2QualityMode::Performance);
    let ops = (0..100)
        .map(|index| {
            if index % 25 == 12 {
                return Op::Generate(generate((1920, 1080), index as u32 % 16));
            }
            let mut f = frame(index, render);
            f.present |= EXPOSURE;
            f.auto_reactive = index % 3 != 0;
            if index % 2 == 0 {
                f.present |= OPAQUE_ONLY;
            }
            f.auto_tc = (0.01 * (index % 7) as f32, 1.0 + index as f32 * 0.01);
            f.auto_reactive_scale_max = (1.0 + index as f32, 0.5 + (index % 4) as f32 * 0.1);
            f.sharpen = index % 5 == 0;
            f.pre_exposure = if index % 8 == 7 {
                0.0
            } else {
                0.5 + index as f32 * 0.01
            };
            f.view_space_to_meters = 2.5;
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: 0,
        max_render: (1920, 1080),
        display: (3840, 2160),
        color: (1920, 1080),
        ops,
    };
    compare("rdna_performance_auto_reactive", rdna(), &case.words());
}

/// RDNA-like device with debug checking, auto exposure and an infinite far
/// plane: frames that trigger every `fsr2DebugCheckDispatch` message, and
/// dispatches the SDK rejects.
#[test]
fn rdna_debug_checking() {
    let render = RenderSize::Quality(FfxFsr2QualityMode::Balanced);
    let ops = (0..104)
        .map(|index| {
            let mut f = frame(index, render);
            f.camera_far = f32::MAX;
            match index % 14 {
                0 => f.present = 0,
                1 => f.present = REQUIRED | EXPOSURE,
                2 => f.jitter = Jitter::Explicit(1.5, -2.0),
                3 => f.motion_vector_scale = (5000.0, 0.0),
                4 => f.render = RenderSize::Explicit(0, 540),
                5 => f.render = RenderSize::Explicit(4000, 540),
                6 => f.sharpness = 1.5,
                7 => {
                    f.sharpness = -0.25;
                    f.frame_time_delta = 0.5;
                }
                8 => {
                    f.pre_exposure = 0.0;
                    f.frame_time_delta = if index % 2 == 0 { f32::NAN } else { -5.0 };
                }
                9 => {
                    f.camera_near = 2000.0;
                    f.camera_far = 1000.0;
                }
                10 => f.camera_near = 0.01,
                11 => f.fov = 0.0,
                12 => f.fov = 3.5,
                _ => f.camera_far = f32::NAN,
            }
            f.sharpen = index % 2 == 0;
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_DEBUG_CHECKING
            | FFX_FSR2_ENABLE_AUTO_EXPOSURE
            | FFX_FSR2_ENABLE_DEPTH_INFINITE,
        max_render: (2259, 1270),
        display: (3840, 2160),
        color: (2259, 1270),
        ops,
    };
    compare("rdna_debug_checking", rdna(), &case.words());
}

/// Wave64 FP32 device (LUT, no forced wave64) with every initialization flag:
/// display-resolution and jitter-cancelled motion vectors, inverted infinite
/// depth, debug checking; Quality and native (render = display) frames.
#[test]
fn wave64_fp32_all_flags_native() {
    let ops = (0..100)
        .map(|index| {
            let render = if index % 2 == 0 {
                RenderSize::Quality(FfxFsr2QualityMode::Quality)
            } else {
                RenderSize::Explicit(1920, 1080)
            };
            let mut f = frame(index, render);
            f.camera_near = f32::MAX;
            f.camera_far = 0.1;
            f.sharpen = index % 3 == 0;
            f.reset = index == 50;
            f.auto_reactive = index % 10 == 9;
            f.present |= OPAQUE_ONLY | REACTIVE | TRANSPARENCY_AND_COMPOSITION;
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE
            | FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
            | FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
            | FFX_FSR2_ENABLE_DEPTH_INVERTED
            | FFX_FSR2_ENABLE_DEPTH_INFINITE
            | FFX_FSR2_ENABLE_AUTO_EXPOSURE
            | FFX_FSR2_ENABLE_DYNAMIC_RESOLUTION
            | FFX_FSR2_ENABLE_TEXTURE1D_USAGE
            | FFX_FSR2_ENABLE_DEBUG_CHECKING,
        max_render: (1920, 1080),
        display: (1920, 1080),
        color: (1920, 1080),
        ops,
    };
    compare("wave64_fp32_all_flags_native", wave64_fp32(), &case.words());
}

/// Wave64 FP32 device, Ultra Performance: 130 frames wrap the 72-phase jitter
/// sequence; display-resolution jitter-cancelled motion vectors, inverted depth.
#[test]
fn wave64_fp32_ultra_performance() {
    let render = RenderSize::Quality(FfxFsr2QualityMode::UltraPerformance);
    let ops = (0..130)
        .map(|index| {
            let mut f = frame(index, render);
            f.camera_near = 500.0;
            f.camera_far = 0.2;
            f.sharpen = true;
            f.sharpness = 1.0 - index as f32 / 130.0;
            f.reset = index == 100;
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE
            | FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
            | FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
            | FFX_FSR2_ENABLE_DEPTH_INVERTED,
        max_render: (1280, 720),
        display: (3840, 2160),
        color: (1280, 720),
        ops,
    };
    compare(
        "wave64_fp32_ultra_performance",
        wave64_fp32(),
        &case.words(),
    );
}

/// Wave32 FP32 device, jitter-cancelled low-resolution motion vectors and
/// inverted depth at odd sizes: Balanced gives partial 8x8 and 64x64 tiles; the
/// input color resource is larger than the render size.
#[test]
fn wave32_fp32_odd_sizes_balanced() {
    let render = RenderSize::Quality(FfxFsr2QualityMode::Balanced);
    let ops = (0..105)
        .map(|index| {
            if index % 30 == 29 {
                return Op::Generate(generate((754, 422), 15));
            }
            let mut f = frame(index, render);
            f.camera_near = 300.0;
            f.camera_far = 0.3;
            f.sharpen = index % 7 < 3;
            f.present |= if index % 2 == 0 {
                REACTIVE
            } else {
                TRANSPARENCY_AND_COMPOSITION
            };
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION | FFX_FSR2_ENABLE_DEPTH_INVERTED,
        max_render: (857, 481),
        display: (1283, 719),
        color: (864, 488),
        ops,
    };
    compare(
        "wave32_fp32_odd_sizes_balanced",
        wave32_fp32(),
        &case.words(),
    );
}

/// Wave32 FP32 device at the smallest sizes (1x1 and 2x1 render, 3x2 display),
/// with a dispatch above the maximum render size and a reactive-mask
/// generation without a command list, both rejected by the SDK.
#[test]
fn wave32_fp32_tiny_and_rejected() {
    let ops = (0..100)
        .map(|index| {
            if index % 20 == 10 {
                let mut g = generate((1, 1), 1);
                g.command_list = index % 40 == 10;
                return Op::Generate(g);
            }
            let render = match index % 3 {
                0 => RenderSize::Explicit(1, 1),
                1 => RenderSize::Explicit(2, 1),
                _ if index % 9 == 2 => RenderSize::Explicit(3, 1),
                _ => RenderSize::Quality(FfxFsr2QualityMode::Quality),
            };
            let mut f = frame(index, render);
            f.camera_near = f32::MAX;
            f.camera_far = 0.05;
            f.sharpen = index % 2 == 1;
            f.reset = index % 33 == 32;
            f.auto_reactive = index % 5 == 0;
            Op::Dispatch(f)
        })
        .collect();
    let case = Case {
        flags: FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
            | FFX_FSR2_ENABLE_DEPTH_INVERTED
            | FFX_FSR2_ENABLE_DEPTH_INFINITE,
        max_render: (2, 1),
        display: (3, 2),
        color: (2, 1),
        ops,
    };
    compare(
        "wave32_fp32_tiny_and_rejected",
        wave32_fp32(),
        &case.words(),
    );
}
