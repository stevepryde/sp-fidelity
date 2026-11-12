//! Complete prepare/interpolation sequences against unchanged HLSL, including history.
//! cargo test -p sp-fidelity-oracle --release --test frameinterpolation_passes -- --ignored --nocapture
#[path = "framegen_support/frameinterpolation.rs"]
#[allow(dead_code)]
mod driver;
mod framegen_support;
#[path = "framegen_support/gpu.rs"]
mod inputs;
use framegen_support::Words;
use sp_fidelity::frameinterpolation::*;
use sp_fidelity::interface::FfxInterface;
use sp_fidelity::types::*;
use sp_fidelity_oracle::{FRAMEINTERPOLATION, compare, gpu};
use sp_fidelity_wgpu::ffx_get_interface_wgpu;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;

#[derive(Default)]
struct SpdBoundary {
    epilogues: HashSet<(u32, &'static str)>,
    inherited: HashMap<(u32, &'static str), (u32, &'static str)>,
}

fn compare_outputs(
    directory: &Path,
    captures: &Path,
    boundary: &SpdBoundary,
) -> compare::Comparison {
    compare::compare(directory, FRAMEINTERPOLATION.stages, &|difference| {
        let frame = difference
            .path
            .iter()
            .next()
            .unwrap()
            .to_str()
            .unwrap()
            .strip_prefix("frame-")
            .unwrap()
            .parse::<u32>()
            .unwrap();
        if difference.resource == "FI_InpaintingPyramid"
            && difference.mip == 6
            && difference.size == [1, 1]
        {
            // SDK-P14: the parallel native Metal translation can read mip5
            // before publication. This historical comparison is not proof of
            // the backend split; the full-resolution serialized-HLSL control
            // below admits no differences. One-group controls remain exact.
            let previous = difference
                .path
                .parent()
                .unwrap()
                .join("FI_InpaintingPyramid.mip-5.bin");
            if let (Ok(port), Ok(original)) = (
                fs::read(directory.join("wgpu").join(&previous)),
                fs::read(directory.join("metal-replay").join(&previous)),
            ) && port == original
            {
                if boundary
                    .epilogues
                    .iter()
                    .any(|(index, stage)| *index == frame && *stage == difference.stage)
                {
                    return Ok("SDK-P14");
                }
                if let Some((_, (writer_frame, writer_stage))) = boundary
                    .inherited
                    .iter()
                    .find(|((index, stage), _)| *index == frame && *stage == difference.stage)
                {
                    // The original mip count leaves this level untouched.
                    // Require both sides to preserve their last actual writer;
                    // also require the port's pre-job capture to be unchanged.
                    let previous_writer = format!(
                        "frame-{writer_frame}/{writer_stage}/FI_InpaintingPyramid.mip-6.bin"
                    );
                    let current = &difference.path;
                    let port = fs::read(directory.join("wgpu").join(current)).unwrap();
                    let native = fs::read(directory.join("metal-replay").join(current)).unwrap();
                    if port == fs::read(captures.join("wgpu-inputs").join(current)).unwrap()
                        && port == fs::read(directory.join("wgpu").join(&previous_writer)).unwrap()
                        && native
                            == fs::read(directory.join("metal-replay").join(&previous_writer))
                                .unwrap()
                    {
                        return Ok("SDK-P14 inherited mip6");
                    }
                }
            }
        }
        Err("output must match unchanged HLSL; no arithmetic tolerance is established".into())
    })
}

fn run(flags: u32, render: [u32; 2], display: [u32; 2], serialize_spd: bool) -> bool {
    let gpu = gpu::Gpu::new(false, None);
    let vector = display.map(|n: u32| n.div_ceil(8));
    let directory = gpu::case_directory(&format!(
        "frameinterpolation-flags-{flags}-{}x{}",
        display[0], display[1]
    ));
    let application = [
        inputs::input(
            &gpu,
            "depth",
            render,
            FfxSurfaceFormat::R32Float,
            (0..render[1])
                .flat_map(|y| {
                    (0..render[0]).flat_map(move |x| {
                        (0.2 + ((x / 8 + y / 8) % 4) as f32 * 0.15).to_le_bytes()
                    })
                })
                .collect(),
            false,
        ),
        inputs::input(
            &gpu,
            "motion-vectors",
            display,
            FfxSurfaceFormat::R16G16Float,
            (0..display[0] * display[1])
                .flat_map(|_| [0x1800u16, 0x9400].into_iter().flat_map(u16::to_le_bytes))
                .collect(),
            false,
        ),
        inputs::input(
            &gpu,
            "dilated-depth",
            render,
            FfxSurfaceFormat::R32Float,
            inputs::zeros(render, 4),
            true,
        ),
        inputs::input(
            &gpu,
            "dilated-motion-vectors",
            render,
            FfxSurfaceFormat::R16G16Float,
            inputs::zeros(render, 4),
            true,
        ),
        inputs::input(
            &gpu,
            "reconstructed-depth",
            render,
            FfxSurfaceFormat::R32Uint,
            inputs::zeros(render, 4),
            true,
        ),
        inputs::input(
            &gpu,
            "color",
            display,
            FfxSurfaceFormat::R16G16B16A16Float,
            inputs::color(display, 0),
            false,
        ),
        inputs::input(
            &gpu,
            "hudless",
            display,
            FfxSurfaceFormat::R16G16B16A16Float,
            inputs::color(display, 1),
            false,
        ),
        inputs::input(
            &gpu,
            "output",
            display,
            FfxSurfaceFormat::R16G16B16A16Float,
            inputs::zeros(display, 8),
            true,
        ),
        inputs::input(
            &gpu,
            "optical-flow",
            vector,
            FfxSurfaceFormat::R16G16Sint,
            (0..vector[0] * vector[1])
                .flat_map(|_| [8i16, -4].into_iter().flat_map(i16::to_le_bytes))
                .collect(),
            false,
        ),
        inputs::input(
            &gpu,
            "scene-change",
            [3, 1],
            FfxSurfaceFormat::R32Uint,
            inputs::zeros([3, 1], 4),
            false,
        ),
        inputs::input(
            &gpu,
            "distortion",
            display,
            FfxSurfaceFormat::R16G16Float,
            inputs::zeros(display, 4),
            false,
        ),
    ];
    let (backend, _) = ffx_get_interface_wgpu(&gpu.device);
    let caps = backend.borrow_mut().get_device_capabilities().unwrap();
    let capture = gpu::Capture::install(&mut backend.borrow_mut(), &directory, &FRAMEINTERPOLATION);
    let mut words = driver::words(
        flags,
        render,
        display,
        [FfxSurfaceFormat::R16G16B16A16Float; 2],
        16,
    );
    let mut w = Words {
        words: &words,
        at: 1,
    };
    let description = FfxFrameInterpolationContextDescription {
        flags: w.word(),
        max_render_size: w.size(),
        display_size: w.size(),
        back_buffer_format: framegen_support::surface_format(w.word()),
        previous_interpolation_source_format: framegen_support::surface_format(w.word()),
        backend_interface: backend.clone(),
    };
    let mut context = FfxFrameInterpolationContext::default();
    ffx_frame_interpolation_context_create(&mut context, &description).unwrap();
    let mut updates = Vec::new();
    let mut dispatch_flags = Vec::new();
    for frame in 0..w.word() as usize {
        capture.set_frame(frame);
        let op = w.word();
        dispatch_flags.push(w.at);
        let dispatch_options = w.word();
        let present = w.word();
        let render_size = w.size();
        let frame_id = w.id();
        let command_list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(gpu.device.create_command_encoder(&Default::default()));
        let resource = |index: usize| {
            backend.borrow_mut().ffx_get_resource_wgpu(
                &application[index].texture,
                application[index].name,
                FFX_RESOURCE_STATE_COMPUTE_READ,
            )
        };
        if op == 0 {
            updates.push(Vec::new());
            let prepare = FfxFrameInterpolationPrepareDescription {
                flags: dispatch_options,
                command_list,
                render_size,
                frame_id,
                jitter_offset: w.coords(),
                motion_vector_scale: w.coords(),
                frame_time_delta: w.scalar(),
                camera_near: w.scalar(),
                camera_far: w.scalar(),
                view_space_to_meters_factor: w.scalar(),
                camera_fov_angle_vertical: w.scalar(),
                depth: resource(0),
                motion_vectors: resource(1),
                dilated_depth: resource(2),
                dilated_motion_vectors: resource(3),
                reconstructed_prev_depth: resource(4),
                camera_position: std::array::from_fn(|_| w.scalar()),
                camera_up: std::array::from_fn(|_| w.scalar()),
                camera_right: std::array::from_fn(|_| w.scalar()),
                camera_forward: std::array::from_fn(|_| w.scalar()),
            };
            ffx_frame_interpolation_prepare(&mut context, &prepare).unwrap();
        } else {
            let color = inputs::color(display, (frame / 2) as u32);
            gpu::upload(&gpu.queue, &application[5].texture, &color);
            updates.push(vec![("color", color)]);
            let dispatch = FfxFrameInterpolationDispatchDescription {
                flags: dispatch_options & FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW,
                command_list,
                render_size,
                frame_id,
                display_size: w.size(),
                current_back_buffer: resource(5),
                current_back_buffer_hud_less: if present & 2 != 0 {
                    resource(6)
                } else {
                    FfxResource::default()
                },
                output: resource(7),
                interpolation_rect: FfxRect2D {
                    left: w.word() as i32,
                    top: w.word() as i32,
                    width: w.word() as i32,
                    height: w.word() as i32,
                },
                optical_flow_vector: resource(8),
                optical_flow_scene_change_detection: resource(9),
                optical_flow_buffer_size: w.size(),
                optical_flow_scale: w.coords(),
                optical_flow_block_size: w.word() as i32,
                camera_near: w.scalar(),
                camera_far: w.scalar(),
                camera_fov_angle_vertical: w.scalar(),
                view_space_to_meters_factor: w.scalar(),
                frame_time_delta: w.scalar(),
                reset: w.word() != 0,
                back_buffer_transfer_function: [
                    FfxBackbufferTransferFunction::Srgb,
                    FfxBackbufferTransferFunction::Pq,
                    FfxBackbufferTransferFunction::Scrgb,
                ][w.word() as usize],
                min_max_luminance: [w.scalar(), w.scalar()],
                dilated_depth: resource(2),
                dilated_motion_vectors: resource(3),
                reconstructed_prev_depth: resource(4),
                distortion_field: if present & 8 != 0 {
                    resource(10)
                } else {
                    FfxResource::default()
                },
            };
            ffx_frame_interpolation_dispatch(&mut context, &dispatch).unwrap();
        }
        assert_eq!(
            backend.borrow_mut().take_job_error(),
            None,
            "GPU operation {frame}"
        );
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        gpu.queue.submit([encoder.finish()]);
        capture.save(&gpu.device);
    }
    ffx_frame_interpolation_context_destroy(&mut context).unwrap();
    // Debug-view coverage is retained; tear/pacing flags are independent of
    // interpolation and expose the SDK's process-global diagnostic color index.
    for at in dispatch_flags {
        words[at] &= FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW;
    }
    gpu::write_inputs(&directory, &application, &updates);
    let (events, init) = framegen_support::cpp(&FRAMEINTERPOLATION, caps, &words, &directory);
    for (name, bytes) in init {
        fs::write(directory.join("inputs").join(format!("{name}.bin")), bytes).unwrap();
    }
    if serialize_spd {
        // The original HLSL's Metal translation does not guarantee publication
        // between workgroups. Serialize its original tiles through the existing
        // WorkGroupOffset API. Only the final tile executes AMD's unchanged tail;
        // no port intermediates are imported into this independent sequence.
        let serial = directory.join("serialized-original");
        gpu::link_case(&directory, &serial, &["inputs", "wgpu"]);
        let mut trace = String::new();
        for event in &events {
            if event[0] == "compute" && matches!(event[1].as_u64(), Some(7 | 9)) {
                let cb_index = event[6]
                    .as_array()
                    .unwrap()
                    .iter()
                    .position(|cb| cb[0] == "cbInpaintingPyramid")
                    .unwrap();
                if event[6][cb_index][1][0].as_u64().unwrap() > 6 {
                    assert_eq!(event[2][2], 1, "FI pyramids are two-dimensional");
                    for y in 0..event[2][1].as_u64().unwrap() {
                        for x in 0..event[2][0].as_u64().unwrap() {
                            let mut tile = event.clone();
                            tile[2] = serde_json::json!([1, 1, 1]);
                            tile[6][cb_index][1][2] =
                                (event[6][cb_index][1][2].as_u64().unwrap() + x).into();
                            tile[6][cb_index][1][3] =
                                (event[6][cb_index][1][3].as_u64().unwrap() + y).into();
                            trace.push_str(&serde_json::to_string(&tile).unwrap());
                            trace.push('\n');
                        }
                    }
                    continue;
                }
            }
            trace.push_str(&serde_json::to_string(event).unwrap());
            trace.push('\n');
        }
        fs::write(serial.join("cpp.jsonl"), trace).unwrap();
        let comparison = compare::compare(
            &gpu::run_sequence(&serial, &FRAMEINTERPOLATION),
            FRAMEINTERPOLATION.stages,
            &|_| Err("output must match serialized original HLSL exactly".into()),
        );
        println!(
            "{} original HLSL with serialized tile scheduling: {}",
            directory.display(),
            comparison.summary()
        );
        return comparison.accepted();
    }
    let mut boundary = SpdBoundary::default();
    let mut frame = 0;
    let mut last_mip6_writer = None;
    for event in &events {
        if event[0] == "frame" {
            frame = event[1].as_u64().unwrap() as u32;
        }
        if event[0] == "compute" && matches!(event[1].as_u64(), Some(7 | 9)) {
            let cb = event[6]
                .as_array()
                .unwrap()
                .iter()
                .find(|cb| cb[0] == "cbInpaintingPyramid")
                .unwrap();
            let job = (
                frame,
                FRAMEINTERPOLATION.stages[event[1].as_u64().unwrap() as usize],
            );
            if cb[1][0].as_u64().unwrap() > 6 {
                last_mip6_writer = None;
                if cb[1][0] == 7 && cb[1][1].as_u64().unwrap() > 1 {
                    boundary.epilogues.insert(job);
                    last_mip6_writer = Some(job);
                }
            } else if let Some(writer) = last_mip6_writer {
                boundary.inherited.insert(job, writer);
            }
        }
    }
    gpu::replay(&directory, &FRAMEINTERPOLATION);
    let replay = compare_outputs(&directory, &directory, &boundary);
    println!(
        "{} identical inputs: {}",
        directory.display(),
        replay.summary()
    );
    let carried = compare_outputs(
        &gpu::run_sequence(&directory, &FRAMEINTERPOLATION),
        &directory,
        &boundary,
    );
    println!(
        "{} own temporal history: {}",
        directory.display(),
        carried.summary()
    );
    replay.accepted() && carried.accepted()
}

#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn frameinterpolation_full_sequence_matches_original_hlsl() {
    // One SPD workgroup and at most six mips: no cross-workgroup epilogue.
    // The smaller controls also exercise fixed UAV slots beyond allocation.
    let mut accepted = true;
    for (render, display) in [([6, 6], [8, 8]), ([24, 24], [32, 32]), ([48, 48], [64, 64])] {
        accepted &= run(
            FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT,
            render,
            display,
            false,
        );
    }
    for key in 0..8 {
        let flags = (key & 1)
            | ((key & 2) << 3)
            | ((key & 4) << 3)
            | FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT;
        accepted &= run(flags, [128, 96], [192, 128], false);
    }
    assert!(
        accepted,
        "one or more FI replay/history comparisons differ; see summaries above"
    );
}

#[test]
#[ignore = "requires Metal and compiled DXC variants; captures full-resolution mip chains"]
fn frameinterpolation_game_resolution_matches_serialized_original_hlsl() {
    assert!(run(
        FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED
            | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE
            | FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT,
        [1200, 750],
        [1200, 750],
        true,
    ));
}
