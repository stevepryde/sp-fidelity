//! Shared FSR 3.1 oracle protocol. After the shared backend capabilities,
//! `0` runs helpers; `1` creates a context (flags, maximum render and upscale
//! sizes, color allocation size, operation count). Operations are dispatch
//! (`0`, [`Dispatch::words`]), reactive generation (`1`, [`Generate::words`]),
//! or configuration (`2`, key, value-present, float bits). A render-size mode
//! of `5` carries explicit dimensions; `0..4` select the SDK quality modes.
#![allow(dead_code)]
use serde_json::{Value, json};
use sp_fidelity::error::FfxErrorCode;
use sp_fidelity::fsr3upscaler::*;
use sp_fidelity::interface::FfxInterfaceRef;
use sp_fidelity::types::*;
use sp_fidelity_oracle::FSR3UPSCALER;
use sp_fidelity_oracle::host::{build_cpp_host, run_cpp_host};
use sp_fidelity_oracle::recorder::{Recorder, record_message};
use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::rc::Rc;
use std::sync::OnceLock;

/// `word()`/`scalar()` of `oracle/host.cpp`.
pub struct Words<'a> {
    pub words: &'a [u32],
    pub at: usize,
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

pub fn quality_mode(value: u32) -> FfxFsr3UpscalerQualityMode {
    match value {
        0 => FfxFsr3UpscalerQualityMode::NativeAa,
        1 => FfxFsr3UpscalerQualityMode::Quality,
        2 => FfxFsr3UpscalerQualityMode::Balanced,
        3 => FfxFsr3UpscalerQualityMode::Performance,
        4 => FfxFsr3UpscalerQualityMode::UltraPerformance,
        _ => panic!("quality mode {value}"),
    }
}

pub fn status<T>(result: &Result<T, FfxErrorCode>) -> FfxErrorCode {
    result.as_ref().err().copied().unwrap_or(0)
}

/// `helpers()` of `oracle/fsr3upscaler_host.cpp`.
pub fn helpers(recorder: &Rc<RefCell<Recorder>>, w: &mut Words) {
    let push = |event: Value| recorder.borrow_mut().events.push(event);
    for _ in 0..w.word() {
        let mode = quality_mode(w.word());
        let (display_width, display_height) = (w.word(), w.word());
        let result = ffx_fsr3_upscaler_get_render_resolution_from_quality_mode(
            display_width,
            display_height,
            mode,
        );
        let (render_width, render_height) = result.unwrap_or((0, 0));
        push(json!([
            "quality",
            mode as u32,
            display_width,
            display_height,
            ffx_fsr3_upscaler_get_upscale_ratio_from_quality_mode(mode).to_bits(),
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
            ffx_fsr3_upscaler_get_jitter_phase_count(render_width, display_width)
        ]));
    }
    for _ in 0..w.word() {
        let (index, phase_count) = (w.word() as i32, w.word() as i32);
        let result = ffx_fsr3_upscaler_get_jitter_offset(index, phase_count);
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
    let null = ffx_fsr3_upscaler_resource_is_null(&FfxResource::default());
    let color = recorder.borrow_mut().external("color", 1, 1);
    push(json!([
        "resource-is-null",
        u8::from(null),
        u8::from(ffx_fsr3_upscaler_resource_is_null(&color))
    ]));
    push(json!(["version", ffx_fsr3_upscaler_get_effect_version()]));
}

pub fn optional(present: bool, resource: &FfxResource) -> FfxResource {
    if present {
        resource.clone()
    } else {
        FfxResource::default()
    }
}

/// `sequence()` of `oracle/fsr3upscaler_host.cpp`.
pub fn sequence(recorder: &Rc<RefCell<Recorder>>, w: &mut Words) {
    let backend: FfxInterfaceRef = recorder.clone();
    let description = FfxFsr3UpscalerContextDescription {
        flags: w.word(),
        max_render_size: FfxDimensions2D {
            width: w.word(),
            height: w.word(),
        },
        max_upscale_size: FfxDimensions2D {
            width: w.word(),
            height: w.word(),
        },
        fp_message: None,
        backend_interface: backend,
    };
    let (color_width, color_height) = (w.word(), w.word());
    ffx_fsr3_upscaler_set_global_debug_message(Some(record_message), 0).unwrap();
    Recorder::record_messages(recorder);

    let (max_render, display) = (description.max_render_size, description.max_upscale_size);
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

    let dilated_depth = external("dilated-depth", max_render.width, max_render.height);
    let dilated_motion_vectors = external(
        "dilated-motion-vectors",
        max_render.width,
        max_render.height,
    );
    let reconstructed_prev_nearest_depth = external(
        "reconstructed-prev-nearest-depth",
        max_render.width,
        max_render.height,
    );
    let mut context = FfxFsr3UpscalerContext::default();
    let created = ffx_fsr3_upscaler_context_create(&mut context, &description);
    recorder.borrow_mut().result("create-result", created);
    if created.is_err() {
        return;
    }

    let queried = ffx_fsr3_upscaler_context_get_gpu_memory_usage(&mut context);
    let usage = queried.unwrap_or_default();
    recorder.borrow_mut().events.push(json!([
        "memory-usage-result",
        status(&queried),
        usage.total_usage_in_bytes,
        usage.aliasable_usage_in_bytes
    ]));

    let shared = ffx_fsr3_upscaler_get_shared_resource_descriptions(&context);
    recorder
        .borrow_mut()
        .events
        .push(json!(["shared-result", status(&shared)]));
    let shared = shared.unwrap();
    for d in [
        &shared.reconstructed_prev_nearest_depth,
        &shared.dilated_depth,
        &shared.dilated_motion_vectors,
    ] {
        let r = d.resource_description;
        recorder.borrow_mut().events.push(json!([
            "shared-resource",
            d.name,
            d.heap_type as u32,
            r.r#type as u32,
            r.format as u32,
            r.width,
            r.height,
            r.depth,
            r.mip_count,
            r.flags,
            r.usage,
            d.initial_state,
            d.id,
            d.init_data.r#type as u32,
            d.init_data.size
        ]));
    }

    for index in 0..w.word() as usize {
        recorder.borrow_mut().frame(index);
        let op = w.word();
        if op == 0 {
            let present = w.word();
            let mut dispatch = FfxFsr3UpscalerDispatchDescription {
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
                dilated_depth: optional(present & 128 != 0, &dilated_depth),
                dilated_motion_vectors: optional(present & 256 != 0, &dilated_motion_vectors),
                reconstructed_prev_nearest_depth: optional(
                    present & 512 != 0,
                    &reconstructed_prev_nearest_depth,
                ),
                ..Default::default()
            };
            let render_mode = w.word();
            if render_mode == 5 {
                dispatch.render_size.width = w.word();
                dispatch.render_size.height = w.word();
            } else {
                let (width, height) = ffx_fsr3_upscaler_get_render_resolution_from_quality_mode(
                    display.width,
                    display.height,
                    quality_mode(render_mode),
                )
                .expect("quality mode rejected");
                dispatch.render_size = FfxDimensions2D { width, height };
            }
            if w.word() == 0 {
                let jitter_index = w.word() as i32;
                let phase_count = ffx_fsr3_upscaler_get_jitter_phase_count(
                    dispatch.render_size.width as i32,
                    display.width as i32,
                );
                if let Ok((x, y)) = ffx_fsr3_upscaler_get_jitter_offset(jitter_index, phase_count) {
                    dispatch.jitter_offset = FfxFloatCoords2D { x, y };
                }
            } else {
                dispatch.jitter_offset.x = w.scalar();
                dispatch.jitter_offset.y = w.scalar();
            }
            dispatch.upscale_size = FfxDimensions2D {
                width: w.word(),
                height: w.word(),
            };
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
            dispatch.flags = w.word();
            let dispatched = ffx_fsr3_upscaler_context_dispatch(&mut context, &dispatch);
            recorder.borrow_mut().result("dispatch-result", dispatched);
        } else if op == 2 {
            let key = configure_key(w.word());
            let present = w.word() != 0;
            let value = w.scalar();
            let configured =
                ffx_fsr3_upscaler_set_constant(&mut context, key, present.then_some(value));
            recorder.borrow_mut().result("configure-result", configured);
        } else {
            let generate = FfxFsr3UpscalerGenerateReactiveDescription {
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
            let generated =
                ffx_fsr3_upscaler_context_generate_reactive_mask(&mut context, &generate);
            recorder
                .borrow_mut()
                .result("generate-reactive-result", generated);
        }
    }
    let destroyed = ffx_fsr3_upscaler_context_destroy(&mut context);
    recorder.borrow_mut().result("destroy-result", destroyed);
}

/// The port's events and initialization data for `words`.
pub fn run_rust(
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
pub fn run_cpp(
    name: &str,
    capabilities: FfxDeviceCapabilities,
    words: &[u32],
) -> (Vec<Value>, HashMap<String, Vec<u8>>) {
    static HOST: OnceLock<(PathBuf, PathBuf)> = OnceLock::new();
    let root = PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join("fsr3upscaler-host");
    let host = HOST.get_or_init(|| build_cpp_host(&root.join("build"), &FSR3UPSCALER));
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
pub fn compare(name: &str, capabilities: FfxDeviceCapabilities, words: &[u32]) -> usize {
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
pub fn capabilities(
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

pub fn rdna() -> FfxDeviceCapabilities {
    capabilities(true, 32, 64, FfxShaderModel::ShaderModel6_6)
}

pub fn wgpu() -> FfxDeviceCapabilities {
    capabilities(true, 32, 32, FfxShaderModel::ShaderModel6_2)
}

pub fn wave64_fp32() -> FfxDeviceCapabilities {
    capabilities(false, 64, 64, FfxShaderModel::ShaderModel6_5)
}

pub fn wave32_fp32() -> FfxDeviceCapabilities {
    capabilities(false, 32, 32, FfxShaderModel::ShaderModel6_0)
}

/// Present bits of a dispatch: command list, depth, motion vectors, exposure,
/// reactive, transparency and composition, output, and the three shared outputs.
pub const COMMAND_LIST: u32 = 1;
pub const DEPTH: u32 = 2;
pub const MOTION_VECTORS: u32 = 4;
pub const EXPOSURE: u32 = 8;
pub const REACTIVE: u32 = 16;
pub const TRANSPARENCY_AND_COMPOSITION: u32 = 32;
pub const OUTPUT: u32 = 64;
pub const DILATED_DEPTH: u32 = 128;
pub const DILATED_MOTION_VECTORS: u32 = 256;
pub const RECONSTRUCTED_DEPTH: u32 = 512;
pub const SHARED: u32 = DILATED_DEPTH | DILATED_MOTION_VECTORS | RECONSTRUCTED_DEPTH;
pub const REQUIRED: u32 = COMMAND_LIST | DEPTH | MOTION_VECTORS | OUTPUT;

#[derive(Clone, Copy)]
pub enum RenderSize {
    Quality(FfxFsr3UpscalerQualityMode),
    Explicit(u32, u32),
}

#[derive(Clone, Copy)]
pub enum Jitter {
    Sequence(i32),
    Explicit(f32, f32),
}

#[derive(Clone, Copy)]
pub struct Dispatch {
    pub present: u32,
    pub render: RenderSize,
    pub jitter: Jitter,
    pub motion_vector_scale: (f32, f32),
    pub sharpen: bool,
    pub sharpness: f32,
    pub frame_time_delta: f32,
    pub pre_exposure: f32,
    pub reset: bool,
    pub camera_near: f32,
    pub camera_far: f32,
    pub fov: f32,
    pub view_space_to_meters: f32,
    pub upscale: (u32, u32),
    pub flags: u32,
}

impl Dispatch {
    /// Present bits; render size (`5`, width, height or quality mode `0..4`);
    /// jitter (`0`, SDK sequence index or `1`, x, y); upscale size; motion
    /// vector scale; sharpening and sharpness; frame time; pre-exposure;
    /// reset; camera near, far and vertical field of view; view space to
    /// meters; dispatch flags.
    pub fn words(&self, words: &mut Vec<u32>) {
        words.extend([0, self.present]);
        match self.render {
            RenderSize::Quality(mode) => words.push(mode as u32),
            RenderSize::Explicit(width, height) => words.extend([5, width, height]),
        }
        match self.jitter {
            Jitter::Sequence(index) => words.extend([0, index as u32]),
            Jitter::Explicit(x, y) => words.extend([1, x.to_bits(), y.to_bits()]),
        }
        words.extend([
            self.upscale.0,
            self.upscale.1,
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
            self.flags,
        ]);
    }
}

#[derive(Clone, Copy)]
pub struct Generate {
    pub command_list: bool,
    pub render: (u32, u32),
    pub scale: f32,
    pub cutoff_threshold: f32,
    pub binary_value: f32,
    pub flags: u32,
}

impl Generate {
    /// Command list present, render size, scale, cutoff threshold, binary
    /// value and flags.
    pub fn words(&self, words: &mut Vec<u32>) {
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

pub enum Op {
    Dispatch(Dispatch),
    Generate(Generate),
    Configure(FfxFsr3UpscalerConfigureKey, Option<f32>),
}

pub struct Case {
    pub flags: u32,
    pub max_render: (u32, u32),
    pub display: (u32, u32),
    pub color: (u32, u32),
    pub ops: Vec<Op>,
}

impl Case {
    pub fn words(&self) -> Vec<u32> {
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
                Op::Configure(key, value) => words.extend([
                    2,
                    *key as u32,
                    u32::from(value.is_some()),
                    value.unwrap_or(0.0).to_bits(),
                ]),
            }
        }
        words
    }
}

/// A typical frame `index` of an application at `render` size: the SDK jitter
/// sequence, varying frame time and pre-exposure, a regular camera.
pub fn frame(index: usize, render: RenderSize) -> Dispatch {
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
        upscale: (0, 0),
        flags: 0,
    }
}

pub fn generate(render: (u32, u32), flags: u32) -> Generate {
    Generate {
        command_list: true,
        render,
        scale: 1.0,
        cutoff_threshold: 0.2,
        binary_value: 0.9,
        flags,
    }
}

pub fn configure_key(value: u32) -> FfxFsr3UpscalerConfigureKey {
    match value {
        0 => FfxFsr3UpscalerConfigureKey::VelocityFactor,
        1 => FfxFsr3UpscalerConfigureKey::ReactivenessScale,
        2 => FfxFsr3UpscalerConfigureKey::ShadingChangeScale,
        3 => FfxFsr3UpscalerConfigureKey::AccumulationAddedPerFrame,
        4 => FfxFsr3UpscalerConfigureKey::MinDisocclusionAccumulation,
        _ => panic!("configure key {value}"),
    }
}
