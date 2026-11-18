//! Runs the reflected SDK HLSL against the WGSL for every writable resource,
//! first from identical pass inputs, then with each implementation carrying history.
mod framegen_support;
#[allow(dead_code)]
#[path = "framegen_support/gpu.rs"]
mod inputs;

use sp_fidelity::denoiser::*;
use sp_fidelity::interface::{FfxInterface, FfxPass};
use sp_fidelity::types::*;
use sp_fidelity_oracle::{DENOISER, compare, gpu, pass};
use sp_fidelity_wgpu::{ffx_get_interface_wgpu, ffx_get_interface_wgpu_with_adapter};
use std::path::{Path, PathBuf};
use wgpu::util::DeviceExt;

const SIZE: [u32; 2] = [29, 19];
const FRAMES: u32 = 5;
const IDENTITY: [f32; 16] = [
    1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1.,
];

fn pixels<T: IntoIterator<Item = u8>>(f: impl Fn(u32, u32) -> T) -> Vec<u8> {
    let f = &f;
    (0..SIZE[1])
        .flat_map(|y| (0..SIZE[0]).flat_map(move |x| f(x, y)))
        .collect()
}

// A moving three-pixel highlight crosses a depth/normal discontinuity. The
// G-buffer also has mirror, glossy and over-threshold roughness regions.
fn radiance(frame: u32) -> Vec<u8> {
    pixels(|x, y| {
        let bright = (x + 24 - frame * 2) % 25 < 3 && (2..17).contains(&y);
        let r = if bright { 0x4400 } else { 0x3400 };
        let g = if bright { 0x3e00 } else { 0x3800 };
        let b = if (x + y + frame).is_multiple_of(3) {
            0x3c00
        } else {
            0x3000
        };
        [r, g, b, 0x3400u16].into_iter().flat_map(u16::to_le_bytes)
    })
}

fn words_bytes(words: impl IntoIterator<Item = u32>) -> Vec<u8> {
    words.into_iter().flat_map(u32::to_le_bytes).collect()
}

fn render(fp16: bool, portable: bool) -> PathBuf {
    let gpu = if portable {
        gpu::Gpu::with_features(wgpu::Features::empty(), None)
    } else {
        gpu::Gpu::new(fp16, None)
    };
    let directory = gpu::case_directory(&format!("reflections-fp16-{fp16}-portable-{portable}"));
    let [width, height] = SIZE;
    let size = FfxDimensions2D { width, height };
    use FfxSurfaceFormat as F;
    let input =
        |name, format, bytes, writable| inputs::input(&gpu, name, SIZE, format, bytes, writable);
    // The external variance textures follow the real backend contract while the
    // reference always sees the SDK's native single-channel resource.
    let variance = |name| {
        if portable {
            let mut variance = input(name, F::R16G16B16A16Float, inputs::zeros(SIZE, 8), true);
            variance.format = F::R16Float;
            variance.bytes = inputs::zeros(SIZE, 2);
            variance
        } else {
            input(name, F::R16Float, inputs::zeros(SIZE, 2), true)
        }
    };
    let app = [
        input(
            "depth",
            F::R32Float,
            pixels(|x, _| (if x < 13 { 0.5_f32 } else { 0.25 }).to_le_bytes()),
            false,
        ),
        input(
            "motion",
            F::R16G16Float,
            pixels(|_, _| [0xb800u16, 0].into_iter().flat_map(u16::to_le_bytes)),
            false,
        ),
        input(
            "normal",
            F::R16G16B16A16Float,
            pixels(|x, _| {
                if x < 13 {
                    [0u16, 0, 0x3c00, 0]
                } else {
                    [0x3800u16, 0, 0x3aee, 0]
                }
                .into_iter()
                .flat_map(u16::to_le_bytes)
            }),
            false,
        ),
        input(
            "radiance0",
            F::R16G16B16A16Float,
            inputs::zeros(SIZE, 8),
            true,
        ),
        input(
            "radiance1",
            F::R16G16B16A16Float,
            inputs::zeros(SIZE, 8),
            true,
        ),
        variance("variance0"),
        variance("variance1"),
        input(
            "roughness",
            F::R8Unorm,
            pixels(|_, y| {
                [if y < 3 {
                    0
                } else if y < 13 {
                    72
                } else {
                    225
                }]
            }),
            false,
        ),
        input(
            "output",
            F::R16G16B16A16Float,
            inputs::zeros(SIZE, 8),
            false,
        ),
    ];

    let [
        depth,
        motion,
        normal,
        radiance0,
        radiance1,
        variance0,
        variance1,
        roughness,
        output,
    ] = app.each_ref();
    let radiances = [radiance0, radiance1];
    let variances = [variance0, variance1];
    let tiles = words_bytes(
        (0..height)
            .step_by(8)
            .flat_map(|y| (0..width).step_by(8).rev().map(move |x| x | (y << 16))),
    );
    let tile_count = tiles.len() as u32 / 4;
    // The ray-trace dispatch occupies the first triplet. All three reflection
    // passes use offset 12, including when the classifier produces no tiles.
    let indirect = |count| words_bytes([0, 1, 1, count, 1, 1]);
    let initial_args = indirect(tile_count);
    let buffer = |name, bytes, usage| {
        gpu.device
            .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                label: Some(name),
                contents: bytes,
                usage: wgpu::BufferUsages::STORAGE
                    | wgpu::BufferUsages::COPY_SRC
                    | wgpu::BufferUsages::COPY_DST
                    | usage,
            })
    };
    let tile_buffer = buffer("tiles", &tiles, wgpu::BufferUsages::empty());
    let arg_buffer = buffer("indirect", &initial_args, wgpu::BufferUsages::INDIRECT);

    let (backend, _) = if portable {
        ffx_get_interface_wgpu(&gpu.device)
    } else {
        ffx_get_interface_wgpu_with_adapter(&gpu.device, &gpu.adapter)
    };
    let caps = backend.borrow_mut().get_device_capabilities().unwrap();
    let capture = gpu::Capture::install(&mut backend.borrow_mut(), &directory, &DENOISER);
    let mut context = FfxDenoiserContext::default();
    let flags = FFX_DENOISER_REFLECTIONS | FFX_DENOISER_ENABLE_DEPTH_INVERTED;
    ffx_denoiser_context_create(
        &mut context,
        &FfxDenoiserContextDescription {
            flags,
            window_size: size,
            normals_history_buffer_format: normal.format,
            backend_interface: backend.clone(),
        },
    )
    .unwrap();
    let mut words = vec![flags, width, height, normal.format as u32, FRAMES];
    let mut updates = Vec::new();
    for frame in 0..FRAMES {
        let parity = (frame % 2) as usize;
        let reset = frame == 3;
        let active = match frame {
            2 => tile_count - 2,
            4 => 0,
            _ => tile_count,
        };
        let args = indirect(active);
        let current = radiances[parity];
        let signal = radiance(frame);
        gpu::upload(&gpu.queue, &current.texture, &signal);
        gpu.queue.write_buffer(&arg_buffer, 0, &args);
        updates.push(vec![(current.name, signal), ("indirect", args)]);
        capture.set_frame(frame as usize);
        let command_list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(gpu.device.create_command_encoder(&Default::default()));
        let resource = |input: &gpu::Input| {
            backend.borrow_mut().ffx_get_resource_wgpu(
                &input.texture,
                input.name,
                FFX_RESOURCE_STATE_COMPUTE_READ,
            )
        };
        let external_buffer = |buffer, name, state| {
            backend
                .borrow_mut()
                .ffx_get_buffer_resource_wgpu(buffer, 4, name, state)
                .unwrap()
        };
        // Infinite reverse-Z perspective (near = 1/8) and a lateral camera
        // translation. Identity transforms cannot expose matrix transposition.
        let inv_projection = [
            1., 0., 0., 0., 0., 0.5, 0., 0., 0., 0., 0., 8., 0., 0., -1., 0.,
        ];
        let mut inv_view = IDENTITY;
        inv_view[12] = frame as f32 / 128.;
        let prev_x = frame.saturating_sub(1) as f32 / 128.;
        let prev_view_projection = [
            1., 0., 0., 0., 0., 2., 0., 0., 0., 0., 0., -1., -prev_x, 0., 0.125, 0.,
        ];
        let dispatch = FfxDenoiserReflectionsDispatchDescription {
            command_list,
            depth_hierarchy: resource(depth),
            motion_vectors: resource(motion),
            normal: resource(normal),
            radiance_a: resource(current),
            radiance_b: resource(radiances[1 - parity]),
            variance_a: resource(variances[parity]),
            variance_b: resource(variances[1 - parity]),
            extracted_roughness: resource(roughness),
            output: resource(output),
            denoiser_tile_list: external_buffer(
                &tile_buffer,
                "tiles",
                FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            ),
            indirect_arguments_buffer: external_buffer(
                &arg_buffer,
                "indirect",
                FFX_RESOURCE_STATE_INDIRECT_ARGUMENT,
            ),
            render_size: size,
            motion_vector_scale: FfxFloatCoords2D {
                x: 2. / width as f32,
                y: 1. / height as f32,
            },
            inv_projection,
            inv_view,
            prev_view_projection,
            normals_unpack_mul: 1.,
            normals_unpack_add: 0.,
            is_roughness_perceptual: false,
            roughness_channel: 0,
            temporal_stability_factor: 0.95,
            roughness_threshold: 0.6,
            frame_index: frame,
            reset,
        };
        words.extend([
            frame,
            u32::from(reset),
            parity as u32,
            width,
            height,
            dispatch.motion_vector_scale.x.to_bits(),
            dispatch.motion_vector_scale.y.to_bits(),
        ]);
        for matrix in [
            dispatch.inv_projection,
            dispatch.inv_view,
            dispatch.prev_view_projection,
        ] {
            words.extend(matrix.map(f32::to_bits));
        }
        words.extend([
            1f32.to_bits(),
            0,
            0,
            0,
            dispatch.temporal_stability_factor.to_bits(),
            dispatch.roughness_threshold.to_bits(),
        ]);
        let result = ffx_denoiser_context_dispatch_reflections(&mut context, &dispatch);
        assert_eq!(backend.borrow_mut().take_job_error(), None, "frame {frame}");
        result.unwrap();
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        gpu.queue.submit([encoder.finish()]);
        capture.save(&gpu.device);
    }
    ffx_denoiser_context_destroy(&mut context).unwrap();
    gpu::write_inputs_with_buffers(
        &directory,
        &app,
        &[("tiles", &tiles), ("indirect", &initial_args)],
        &updates,
    );
    framegen_support::cpp(&DENOISER, caps, &words, &directory);
    directory
}

fn strict_shaders(directory: &Path, options: u32) -> [PathBuf; 2] {
    use sp_fidelity::blob_accessors::denoiser_shaderblobs::denoiser_get_permutation_blob_by_index;
    for pass in [
        FfxDenoiserPass::ReprojectReflections,
        FfxDenoiserPass::PrefilterReflections,
        FfxDenoiserPass::ResolveTemporalReflections,
    ] {
        let blob = denoiser_get_permutation_blob_by_index(pass as FfxPass, options).unwrap();
        let source = sp_fidelity::shaders::ffx_get_wgsl_source(&blob).unwrap();
        pass::strict_variants(
            &DENOISER,
            &pass::Pipeline {
                pass: pass as FfxPass,
                options,
                blob,
                samplers: vec![],
                root_constants: vec![],
            },
            &source,
            directory,
        );
    }
    [directory.join("port"), directory.join("original")]
}

// Maximum absolute channel error and maximum number of differing texels in
// one dump, measured against AMD's original HLSL on this five-frame fixture.
// The strict controls independently require all the same outputs byte-exact.
fn fast_math(
    fp16: bool,
    carried: bool,
    difference: &compare::Difference,
) -> Result<&'static str, String> {
    let (maximum, texels) = match difference.resource.as_str() {
        "radiance0" | "radiance1" | "DENOISER_ReprojectedRadiance" => match (fp16, carried) {
            (false, false) => (0.000244140625, 5),
            (false, true) => (0.00048828125, 9),
            (true, false) => (0.06103515625, 87),
            (true, true) => (0.072021484375, 207),
        },
        "variance0" | "variance1" => match (fp16, carried) {
            (false, false) => (0.000244140625, 72),
            (false, true) => (0.000244140625, 70),
            (true, _) => (0.080078125, if carried { 301 } else { 160 }),
        },
        "DENOISER_AverageRadiance0" | "DENOISER_AverageRadiance1" if fp16 && carried => {
            (0.0078125, 2)
        }
        _ => return Err("this SDK output matched byte-for-byte on the fixture".into()),
    };
    // Resolve writes the application result, whose observed ceiling is tighter
    // than reprojection and prefilter when each side carries its own history.
    let maximum = if difference.stage == "denoiser_resolve_temporal_reflections"
        && matches!(difference.resource.as_str(), "radiance0" | "radiance1")
    {
        if fp16 { 0.06103515625 } else { 0.000244140625 }
    } else {
        maximum
    };
    if difference.maximum <= maximum && difference.texels <= texels {
        Ok("SDK-P22")
    } else {
        Err(format!(
            "exceeds measured Metal fast-math envelope (max {maximum}, {texels} texels)"
        ))
    }
}

fn compare_native(fp16: bool) {
    let directory = render(fp16, false);
    gpu::replay(&directory, &DENOISER);
    let sequence = gpu::run_sequence(&directory, &DENOISER);
    let shaders = strict_shaders(&directory.join("strict-shaders"), if fp16 { 6 } else { 4 });
    let exact =
        |_: &compare::Difference| Err("strict arithmetic differs from AMD's HLSL".to_owned());
    for (label, case, run) in [
        (
            "replay",
            &directory,
            gpu::replay_strict as fn(&Path, &Path, &Path),
        ),
        ("sequence", &sequence, gpu::run_strict_sequence),
    ] {
        let strict = directory.join(format!("strict-{label}"));
        gpu::link_case(&directory, &strict, &["inputs", "cpp.jsonl"]);
        run(&directory, &shaders[0], &strict.join("wgpu"));
        run(&directory, &shaders[1], &strict.join("metal-replay"));
        let control = compare::compare_finite(&strict, DENOISER.stages, &exact);
        let fast = compare::compare_finite(case, DENOISER.stages, &|d| {
            fast_math(fp16, label == "sequence", d)
        });
        println!(
            "{} {label}\nstrict: {}\nMetal fast math: {}",
            directory.display(),
            control.summary(),
            fast.summary()
        );
        assert!(control.accepted() && fast.accepted());
    }
}

#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn reflections_fp32_matches_sdk() {
    compare_native(false);
}

#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn reflections_fp16_matches_sdk() {
    compare_native(true);
}

#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn reflections_core_webgpu_output_matches_sdk() {
    let native = render(false, false);
    let portable = render(false, true);
    // Both runs use the production compiler and independently carry history.
    // Comparing the final application texture isolates the portable format
    // adaptation from the fast-math difference measured against AMD above.
    for frame in 0..FRAMES {
        let copy = format!("wgpu/frame-{frame}/copy/output.mip-0.bin");
        let actual = std::fs::read(portable.join(&copy)).unwrap();
        let expected = std::fs::read(native.join(&copy)).unwrap();
        assert_eq!(actual.len(), (SIZE[0] * SIZE[1] * 8) as usize);
        assert!(
            actual == expected,
            "portable output bytes differ in frame {frame}, {}",
            portable.display()
        );
        assert!(
            actual
                .chunks_exact(2)
                .all(|b| u16::from_le_bytes([b[0], b[1]]) & 0x7c00 != 0x7c00),
            "nonfinite RGBA16F output in frame {frame}, {}",
            portable.display()
        );
    }
}
