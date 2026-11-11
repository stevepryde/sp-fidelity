//! Complete FSR 3.1 host sequences through wgpu, replayed pass by pass with
//! AMD's unchanged HLSL from the captured inputs. Every UAV mip is compared.
//!
//! Run explicitly after generating the selected variants:
//! `cargo test -p sp-fidelity-oracle --release --test fsr3upscaler_passes -- --ignored --nocapture`
#[path = "support/fsr3upscaler_gpu.rs"]
mod gpu_support;
#[path = "support/fsr3upscaler.rs"]
mod support;
use serde_json::{Value, json};
use sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index;
use sp_fidelity::fsr3upscaler::*;
use sp_fidelity::interface::FfxInterface;
use sp_fidelity::shaders::ffx_get_wgsl_source;
use sp_fidelity::types::*;
use sp_fidelity_oracle::gpu::{self, Capture, Input};
use sp_fidelity_oracle::{FSR3UPSCALER, compare, pass};
use sp_fidelity_wgpu::ffx_get_interface_wgpu;
use std::collections::{BTreeMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use support::{Case, Op, RenderSize};

fn texture(
    device: &wgpu::Device,
    size: (u32, u32),
    format: wgpu::TextureFormat,
    writable: bool,
) -> wgpu::Texture {
    device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: size.0,
            height: size.1,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage: wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST
            | if writable {
                wgpu::TextureUsages::STORAGE_BINDING
                    | if format == wgpu::TextureFormat::R32Uint {
                        wgpu::TextureUsages::STORAGE_ATOMIC
                    } else {
                        wgpu::TextureUsages::empty()
                    }
            } else {
                wgpu::TextureUsages::empty()
            },
        view_formats: &[],
    })
}

fn half(value: f32) -> u16 {
    let bits = value.to_bits();
    let sign = ((bits >> 16) & 0x8000) as u16;
    let exponent = ((bits >> 23) & 0xff) as i32 - 112;
    if exponent <= 0 {
        return sign;
    }
    sign | (((exponent as u32) << 10 | (bits & 0x7f_ffff) >> 13) + ((bits >> 12) & 1)).min(0x7c00)
        as u16
}

fn image(size: (u32, u32), mut texel: impl FnMut(u32, u32) -> Vec<u8>) -> Vec<u8> {
    let mut bytes = Vec::new();
    for y in 0..size.1 {
        for x in 0..size.0 {
            bytes.extend(texel(x, y));
        }
    }
    bytes
}

fn color(size: (u32, u32), frame: usize, opaque: bool) -> Vec<u8> {
    image(size, |x, y| {
        let stripe = if (x + frame as u32 * 3) % 19 < 7 {
            2.0
        } else {
            0.5
        };
        let alpha = if !opaque && (x + y) % 11 < 3 {
            0.25
        } else {
            1.0
        };
        let rgb = [
            0.125 + (x % 31) as f32 / 32.0,
            0.25 + (y % 23) as f32 / 32.0,
            stripe,
        ];
        [rgb[0] * alpha, rgb[1] * alpha, rgb[2] * alpha, 1.0]
            .into_iter()
            .flat_map(|v| half(v).to_le_bytes())
            .collect()
    })
}

struct Application {
    inputs: Vec<Input>,
}
impl Application {
    fn new(gpu: &gpu::Gpu, render: (u32, u32), display: (u32, u32), display_mv: bool) -> Self {
        let mv_size = if display_mv { display } else { render };
        let resources = [
            (
                "dilated-depth",
                render,
                FfxSurfaceFormat::R32Float,
                wgpu::TextureFormat::R32Float,
                vec![0; (render.0 * render.1 * 4) as usize],
                true,
            ),
            (
                "dilated-motion-vectors",
                render,
                FfxSurfaceFormat::R16G16Float,
                wgpu::TextureFormat::Rg16Float,
                vec![0; (render.0 * render.1 * 4) as usize],
                true,
            ),
            (
                "reconstructed-prev-nearest-depth",
                render,
                FfxSurfaceFormat::R32Uint,
                wgpu::TextureFormat::R32Uint,
                vec![0; (render.0 * render.1 * 4) as usize],
                true,
            ),
            (
                "color",
                render,
                FfxSurfaceFormat::R16G16B16A16Float,
                wgpu::TextureFormat::Rgba16Float,
                color(render, 0, false),
                false,
            ),
            (
                "opaque-only",
                render,
                FfxSurfaceFormat::R16G16B16A16Float,
                wgpu::TextureFormat::Rgba16Float,
                color(render, 0, true),
                false,
            ),
            (
                "depth",
                render,
                FfxSurfaceFormat::R32Float,
                wgpu::TextureFormat::R32Float,
                image(render, |x, y| {
                    (0.1 + (x + y) as f32 / (render.0 + render.1) as f32 * 0.8)
                        .to_le_bytes()
                        .to_vec()
                }),
                false,
            ),
            (
                "motion-vectors",
                mv_size,
                FfxSurfaceFormat::R16G16Float,
                wgpu::TextureFormat::Rg16Float,
                image(mv_size, |x, y| {
                    [
                        half((x % 5) as f32 / 4096.0),
                        half(-((y % 3) as f32) / 4096.0),
                    ]
                    .into_iter()
                    .flat_map(u16::to_le_bytes)
                    .collect()
                }),
                false,
            ),
            (
                "exposure",
                (1, 1),
                FfxSurfaceFormat::R32Float,
                wgpu::TextureFormat::R32Float,
                1f32.to_le_bytes().to_vec(),
                false,
            ),
            (
                "reactive",
                render,
                FfxSurfaceFormat::R8Unorm,
                wgpu::TextureFormat::R8Unorm,
                image(render, |x, y| vec![if (x + y) % 17 < 4 { 192 } else { 0 }]),
                false,
            ),
            (
                "transparency-and-composition",
                render,
                FfxSurfaceFormat::R8Unorm,
                wgpu::TextureFormat::R8Unorm,
                image(render, |x, y| {
                    vec![if (x * 3 + y) % 13 < 2 { 96 } else { 0 }]
                }),
                false,
            ),
            (
                "output",
                display,
                FfxSurfaceFormat::R16G16B16A16Float,
                wgpu::TextureFormat::Rgba16Float,
                vec![0; (display.0 * display.1 * 8) as usize],
                true,
            ),
            (
                "out-reactive",
                render,
                FfxSurfaceFormat::R8Unorm,
                wgpu::TextureFormat::R8Unorm,
                vec![0; (render.0 * render.1) as usize],
                true,
            ),
        ];
        Self {
            inputs: resources
                .into_iter()
                .map(|(name, size, format, native_format, bytes, writable)| {
                    let texture = texture(&gpu.device, size, native_format, writable);
                    gpu::upload(&gpu.queue, &texture, &bytes);
                    Input {
                        name,
                        texture,
                        format,
                        cube: false,
                        bytes,
                    }
                })
                .collect(),
        }
    }
    fn input(&self, name: &str) -> &Input {
        self.inputs.iter().find(|i| i.name == name).unwrap()
    }
}

fn run_case(
    gpu: &gpu::Gpu,
    name: &str,
    flags: u32,
    lut: bool,
    render: (u32, u32),
    display: (u32, u32),
) -> (compare::Comparison, PathBuf) {
    let directory = gpu::case_directory(name);
    let application = Application::new(
        gpu,
        render,
        display,
        flags & FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS != 0,
    );
    let (backend, interface) = ffx_get_interface_wgpu(&gpu.device);
    let mut capabilities = backend.borrow_mut().get_device_capabilities().unwrap();
    if lut {
        capabilities.wave_lane_count_min = 32;
        capabilities.wave_lane_count_max = 64;
        capabilities.maximum_supported_shader_model = FfxShaderModel::ShaderModel6_2;
    }
    let interface = gpu_support::with_capabilities(interface, capabilities);
    let mut ops = Vec::new();
    for index in 0..5 {
        if index == 2 {
            ops.push(Op::Generate(support::generate(render, 15)));
        }
        let mut f = support::frame(index, RenderSize::Explicit(render.0, render.1));
        f.motion_vector_scale = (-(render.0 as f32), -(render.1 as f32));
        f.present |= support::EXPOSURE
            | support::REACTIVE
            | support::TRANSPARENCY_AND_COMPOSITION
            | support::SHARED;
        f.sharpen = index % 2 == 1;
        f.sharpness = index as f32 / 4.0;
        f.reset = index == 0 || index == 3;
        if index == 4 {
            f.flags = FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW;
        }
        if flags & FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED != 0 {
            f.camera_near = f32::MAX;
            f.camera_far = 0.1;
        }
        ops.push(Op::Dispatch(f));
    }
    let case = Case {
        flags,
        max_render: render,
        display,
        color: render,
        ops,
    };
    let updates: Vec<Vec<(&str, Vec<u8>)>> = case
        .ops
        .iter()
        .enumerate()
        .map(|(index, _)| {
            vec![
                ("color", color(render, index, false)),
                ("opaque-only", color(render, index, true)),
            ]
        })
        .collect();
    gpu::write_inputs(&directory, &application.inputs, &updates);
    let (events, init_data) = support::run_cpp(name, capabilities, &case.words());
    // Application UAVs need writable allocations in the Metal oracle.
    let mut trace = String::new();
    for name in [
        "output",
        "out-reactive",
        "dilated-depth",
        "dilated-motion-vectors",
        "reconstructed-prev-nearest-depth",
    ] {
        let input = application.input(name);
        let t = &input.texture;
        trace += &json!([
            "resource",
            name,
            FfxResourceType::Texture2D as u32,
            input.format as u32,
            t.width(),
            t.height(),
            1,
            FFX_RESOURCE_USAGE_UAV,
            FfxResourceInitDataType::Uninitialized as u32,
            0,
            0
        ])
        .to_string();
        trace.push('\n');
    }
    for event in &events {
        trace += &event.to_string();
        trace.push('\n');
    }
    fs::write(directory.join("cpp.jsonl"), trace).unwrap();
    for (name, bytes) in init_data {
        fs::write(directory.join("inputs").join(format!("{name}.bin")), bytes).unwrap();
    }
    let mut context = FfxFsr3UpscalerContext::default();
    ffx_fsr3_upscaler_context_create(
        &mut context,
        &FfxFsr3UpscalerContextDescription {
            flags,
            max_render_size: FfxDimensions2D {
                width: render.0,
                height: render.1,
            },
            max_upscale_size: FfxDimensions2D {
                width: display.0,
                height: display.1,
            },
            fp_message: None,
            backend_interface: interface,
        },
    )
    .unwrap();
    let capture = Capture::install(&mut backend.borrow_mut(), &directory, &FSR3UPSCALER);
    for (index, op) in case.ops.iter().enumerate() {
        for (name, bytes) in &updates[index] {
            gpu::upload(&gpu.queue, &application.input(name).texture, bytes);
        }
        capture.set_frame(index);
        let command_list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(gpu.device.create_command_encoder(&Default::default()));
        let resource = |name: &str, write| {
            backend.borrow_mut().ffx_get_resource_wgpu(
                &application.input(name).texture,
                name,
                if write {
                    FFX_RESOURCE_STATE_UNORDERED_ACCESS
                } else {
                    FFX_RESOURCE_STATE_COMPUTE_READ
                },
            )
        };
        match op {
            Op::Dispatch(f) => {
                let phase =
                    ffx_fsr3_upscaler_get_jitter_phase_count(render.0 as i32, display.0 as i32);
                let support::Jitter::Sequence(jitter_index) = f.jitter else {
                    unreachable!()
                };
                let (x, y) = ffx_fsr3_upscaler_get_jitter_offset(jitter_index, phase).unwrap();
                ffx_fsr3_upscaler_context_dispatch(
                    &mut context,
                    &FfxFsr3UpscalerDispatchDescription {
                        command_list,
                        color: resource("color", false),
                        depth: resource("depth", false),
                        motion_vectors: resource("motion-vectors", false),
                        exposure: resource("exposure", false),
                        reactive: resource("reactive", false),
                        transparency_and_composition: resource(
                            "transparency-and-composition",
                            false,
                        ),
                        output: resource("output", true),
                        dilated_depth: resource("dilated-depth", true),
                        dilated_motion_vectors: resource("dilated-motion-vectors", true),
                        reconstructed_prev_nearest_depth: resource(
                            "reconstructed-prev-nearest-depth",
                            true,
                        ),
                        jitter_offset: FfxFloatCoords2D { x, y },
                        motion_vector_scale: FfxFloatCoords2D {
                            x: f.motion_vector_scale.0,
                            y: f.motion_vector_scale.1,
                        },
                        render_size: FfxDimensions2D {
                            width: render.0,
                            height: render.1,
                        },
                        enable_sharpening: f.sharpen,
                        sharpness: f.sharpness,
                        frame_time_delta: f.frame_time_delta,
                        pre_exposure: f.pre_exposure,
                        reset: f.reset,
                        camera_near: f.camera_near,
                        camera_far: f.camera_far,
                        camera_fov_angle_vertical: f.fov,
                        view_space_to_meters_factor: f.view_space_to_meters,
                        flags: f.flags,
                        ..Default::default()
                    },
                )
                .unwrap();
            }
            Op::Generate(g) => ffx_fsr3_upscaler_context_generate_reactive_mask(
                &mut context,
                &FfxFsr3UpscalerGenerateReactiveDescription {
                    command_list,
                    color_opaque_only: resource("opaque-only", false),
                    color_pre_upscale: resource("color", false),
                    out_reactive: resource("out-reactive", true),
                    render_size: FfxDimensions2D {
                        width: g.render.0,
                        height: g.render.1,
                    },
                    scale: g.scale,
                    cutoff_threshold: g.cutoff_threshold,
                    binary_value: g.binary_value,
                    flags: g.flags,
                },
            )
            .unwrap(),
            Op::Configure(_, _) => unreachable!(),
        }
        // The SDK ignores backend execution failures, so inspect the actual
        // boundary: a rejected bind group must fail the oracle case here.
        let error = backend.borrow_mut().take_job_error();
        assert!(error.is_none(), "GPU operation {index} failed: {error:?}");
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        gpu.queue.submit([encoder.finish()]);
        capture.save(&gpu.device);
    }
    ffx_fsr3_upscaler_context_destroy(&mut context).unwrap();
    gpu::replay(&directory, &FSR3UPSCALER);
    let mut frame = 0usize;
    let mut epilogues = HashSet::new();
    for event in &events {
        if event[0] == "frame" {
            frame = event[1].as_u64().unwrap() as usize;
        }
        if event[0] == "compute" && event[1] == FfxFsr3UpscalerPass::LumaPyramid as u32 {
            let spd = event[6]
                .as_array()
                .unwrap()
                .iter()
                .find(|cb| cb[0] == "cbSPD")
                .unwrap();
            if spd[1][0].as_u64().unwrap() > 6 {
                epilogues.insert(frame);
            }
        }
    }
    // Normal wgpu math is diagnostic at these documented compiler/race
    // boundaries. Each caller independently requires the aligned strict
    // accumulator controls, and the temporal suite requires exact strict
    // single-workgroup pyramid controls. Other outputs must remain exact.
    let comparison = compare::compare(&directory, FSR3UPSCALER.stages, &|d| {
        if matches!(
            d.stage.as_str(),
            "fsr3upscaler_accumulate" | "fsr3upscaler_accumulate_sharpen"
        ) && (d.resource == "output" || d.resource.starts_with("FSR3UPSCALER_InternalUpscaled"))
        {
            return Ok("SDK-P22: checked separately with builtin-aligned strict compilation");
        }
        if d.stage == "fsr3upscaler_shading_change_pyramid" && d.resource == "FSR3UPSCALER_SpdMips"
        {
            return Ok("SDK-P22: strict one-workgroup pyramid control is exact");
        }
        if d.stage == "fsr3upscaler_luma_pyramid" && d.resource == "FSR3UPSCALER_FrameInfo" {
            let component = d.path.iter().next().unwrap().to_str().unwrap();
            let frame: usize = component.strip_prefix("frame-").unwrap().parse().unwrap();
            return Ok(if epilogues.contains(&frame) {
                "SDK-P14: cross-workgroup SPD publication is not guaranteed"
            } else {
                "SDK-P22: strict one-workgroup exposure-fold control is exact"
            });
        }
        Err("no declared SDK compiler/race exception covers this output".into())
    });
    println!("{}: {}", directory.display(), comparison.summary());
    let executed: HashSet<_> = events
        .iter()
        .filter(|e| e[0] == "compute")
        .map(|e| e[1].as_u64().unwrap() as usize)
        .collect();
    // The SDK's supported pass IDs end at GenerateReactive; TcrAutogenerate
    // is the deprecated identifier after it. This catches a scenario that
    // silently stops exercising sharpening, debug view or reactive generation.
    assert_eq!(
        executed,
        (0..=FfxFsr3UpscalerPass::GenerateReactive as usize).collect()
    );
    for pass in executed {
        assert!(
            comparison
                .dumps
                .get(FSR3UPSCALER.stages[pass])
                .is_some_and(|(total, _)| *total > 0),
            "missing output evidence for pass {pass}"
        );
    }
    (comparison, directory)
}

/// Hold the captured inputs fixed and compile both implementations with the
/// same Metal compiler, without fast math or contraction. This distinguishes
/// translation defects from the ordinary wgpu compilation's float evaluation.
fn strict_pass(directory: &Path, selected: FfxFsr3UpscalerPass) -> compare::Comparison {
    let selected = selected as u32;
    let events: Vec<Value> = fs::read_to_string(directory.join("cpp.jsonl"))
        .unwrap()
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    let event = events
        .iter()
        .find(|e| e[0] == "pipeline" && e[1] == selected)
        .unwrap();
    let options = event[2].as_u64().unwrap() as u32;
    let blob = ffx_get_permutation_blob_by_index(
        FfxEffect::Fsr3Upscaler,
        selected,
        FFX_BIND_COMPUTE_SHADER_STAGE,
        options,
    )
    .unwrap();
    let pipeline = pass::Pipeline {
        pass: selected,
        options,
        blob,
        root_constants: Vec::new(),
        samplers: Vec::new(),
    };
    let strict = directory.join(format!("strict-{selected}"));
    // DXC folds these divisions to multiplication by the rounded f32
    // reciprocal before SPIRV-Cross emits Metal. Apply those evidenced folds
    // only to the strict control, keeping the runtime WGSL SDK-shaped.
    let mut source = ffx_get_wgsl_source(&pipeline.blob)
        .unwrap()
        .replace("params.f4KVelocity / 20.0f", "params.f4KVelocity * 0.05f")
        .replace(
            "params.fFarthestDepthInMeters / 20.0f",
            "params.fFarthestDepthInMeters * 0.05f",
        );
    if selected == FfxFsr3UpscalerPass::LumaPyramid as u32 {
        // Original DXC Metal emits 100/12.5 as8 and moves the rounded
        // reciprocal of78/(0.65*100) ahead of the final division.
        source = source
            .replace("log2((Lavg * S) / K)", "log2(Lavg * 8.0f)")
            .replace(
                "return 1 / Lmax;",
                "return 0.833333313465118408203125f / ffxPow_f32_f32(2.0f, ExposureISO100);",
            );
    }
    if selected == FfxFsr3UpscalerPass::ShadingChangePyramid as u32
        || selected == FfxFsr3UpscalerPass::LumaPyramid as u32
    {
        // A single workgroup does not enter SPD's cross-workgroup epilogue.
        // Remove its unreachable buffer atomic operations so both strict
        // variants can use the SDK's native texture-counter binding table.
        assert!(
            events
                .iter()
                .filter(|e| e[0] == "compute" && e[1] == selected)
                .all(|e| e[2][0] == 1 && e[2][1] == 1)
        );
        source = source
            .replace(
                "*spdCounter = atomicAdd(&rw_spd_global_atomic[0], 1u);",
                "*spdCounter = 0u;",
            )
            .replace("atomicStore(&rw_spd_global_atomic[0], 0u);", "");
    }
    let [port, original] = pass::strict_variants(&FSR3UPSCALER, &pipeline, &source, &strict);
    gpu::link_case(directory, &strict, &["inputs", "wgpu-inputs"]);
    let trace = events
        .into_iter()
        .filter(|e| match e[0].as_str().unwrap() {
            "resource" | "frame" => true,
            "pipeline" | "compute" => e[1] == selected,
            _ => false,
        })
        .map(|e| e.to_string() + "\n")
        .collect::<String>();
    fs::write(strict.join("cpp.jsonl"), trace).unwrap();
    gpu::replay_strict(&strict, &port, &strict.join("wgpu"));
    gpu::replay_strict(&strict, &original, &strict.join("metal-replay"));
    let comparison = compare::compare(&strict, FSR3UPSCALER.stages, &|_| {
        Err("strict compilation must match".into())
    });
    println!("{}: {}", strict.display(), comparison.summary());
    comparison
}

/// Retain the raw strict result, then align the one evidenced Metal builtin
/// distinction in a separate temporary emitted-MSL copy. Exports, vendor
/// sources and runtime WGSL remain unchanged.
fn aligned_accumulate(directory: &Path, selected: FfxFsr3UpscalerPass) -> compare::Comparison {
    let raw = strict_pass(directory, selected);
    println!("raw strict {}: {}", selected as u32, raw.summary());
    let strict = directory.join(format!("strict-{}", selected as u32));
    let aligned = directory.join(format!("builtin-aligned-{}", selected as u32));
    let shaders = aligned.join("shaders");
    for variant in fs::read_dir(strict.join("original")).unwrap() {
        let variant = variant.unwrap().path();
        let target = shaders.join(variant.file_name().unwrap());
        fs::create_dir_all(&target).unwrap();
        for file in fs::read_dir(variant).unwrap() {
            let file = file.unwrap().path();
            let target = target.join(file.file_name().unwrap());
            if file.extension().is_some_and(|e| e == "metal") {
                let source = fs::read_to_string(&file).unwrap();
                fs::write(
                    target,
                    source.replace("fast::normalize(", "metal::normalize("),
                )
                .unwrap();
            } else {
                fs::copy(file, target).unwrap();
            }
        }
    }
    gpu::link_case(
        &strict,
        &aligned,
        &["cpp.jsonl", "inputs", "wgpu-inputs", "wgpu"],
    );
    gpu::replay_strict(&aligned, &shaders, &aligned.join("metal-replay"));
    let comparison = compare::compare(&aligned, FSR3UPSCALER.stages, &|_| {
        Err("builtin-aligned strict compilation must match".into())
    });
    println!(
        "{} (compiler-builtin-aligned): {}",
        aligned.display(),
        comparison.summary()
    );
    comparison
}

#[test]
#[ignore = "needs Metal, clang++ and compiled FSR 3.1 shader variants"]
fn all_passes_match_the_unchanged_hlsl_over_temporal_sequences() {
    let mut maxima = BTreeMap::<String, f64>::new();
    let mut failures = Vec::new();
    for fp16 in [false, true] {
        let gpu = gpu::Gpu::new(fp16, None);
        for (name, flags, render, display) in [
            (
                "one-group",
                FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE | FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE,
                (64, 64),
                (64, 64),
            ),
            (
                "quality",
                FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE,
                (86, 48),
                (129, 72),
            ),
            (
                "native",
                FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
                    | FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
                    | FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED
                    | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE
                    | FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE,
                (129, 73),
                (129, 73),
            ),
        ] {
            let (comparison, directory) = run_case(
                &gpu,
                &format!("fsr3upscaler-{name}-fp16-{fp16}"),
                flags,
                false,
                render,
                display,
            );
            for pass in [
                FfxFsr3UpscalerPass::Accumulate,
                FfxFsr3UpscalerPass::AccumulateSharpen,
            ] {
                let strict = aligned_accumulate(&directory, pass);
                if !strict.accepted() {
                    failures.push(strict.summary());
                }
            }
            if render == (64, 64) {
                for pass in [
                    FfxFsr3UpscalerPass::LumaPyramid,
                    FfxFsr3UpscalerPass::ShadingChangePyramid,
                ] {
                    let strict = strict_pass(&directory, pass);
                    if !strict.accepted() {
                        failures.push(strict.summary());
                    }
                }
            }
            for d in &comparison.differences {
                maxima
                    .entry(format!("{}:{}:{fp16}", d.stage, d.resource))
                    .and_modify(|v| *v = v.max(d.maximum))
                    .or_insert(d.maximum);
            }
            println!("measured maxima: {maxima:?}");
            if !comparison.accepted() {
                failures.push(comparison.summary());
            }
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}

/// All meaningful compile keys: HDR, motion-vector resolution, jitter,
/// inverted depth and Lanczos implementation, in each precision table.
/// Accumulate and accumulate-sharpen supply the sixth key bit themselves.
#[test]
#[ignore = "needs Metal, clang++ and all 128 compiled FSR 3.1 shader variants"]
fn all_meaningful_permutations_match_the_unchanged_hlsl() {
    let mut failures = Vec::new();
    for fp16 in [false, true] {
        let gpu = gpu::Gpu::new(fp16, None);
        for key in 0..32 {
            let flag = |bit, value| if key & bit != 0 { value } else { 0 };
            let flags = flag(2, FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE)
                | if key & 4 == 0 {
                    FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
                } else {
                    0
                }
                | flag(
                    8,
                    FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
                )
                | flag(
                    16,
                    FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE,
                );
            let (comparison, directory) = run_case(
                &gpu,
                &format!("fsr3upscaler-key-{key:#04x}-fp16-{fp16}"),
                flags,
                key & 1 != 0,
                (129, 73),
                (129, 73),
            );
            for pass in [
                FfxFsr3UpscalerPass::Accumulate,
                FfxFsr3UpscalerPass::AccumulateSharpen,
            ] {
                let strict = aligned_accumulate(&directory, pass);
                if !strict.accepted() {
                    failures.push(strict.summary());
                }
            }
            if !comparison.accepted() {
                failures.push(comparison.summary());
            }
        }
    }
    assert!(failures.is_empty(), "{}", failures.join("\n"));
}
