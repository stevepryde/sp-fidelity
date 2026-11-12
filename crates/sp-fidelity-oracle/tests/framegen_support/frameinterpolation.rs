use crate::framegen_support::*;
use serde_json::json;
use sp_fidelity::frameinterpolation::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::recorder::Recorder;
use std::cell::RefCell;
use std::rc::Rc;

pub fn run_rust(caps: FfxDeviceCapabilities, words: &[u32]) -> Recorded {
    let recorder = Rc::new(RefCell::new(Recorder::new(caps)));
    let mut w = Words { words, at: 0 };
    for _ in 0..w.word() {
        sequence(&recorder, &mut w);
    }
    take(&recorder)
}

fn sequence(recorder: &Rc<RefCell<Recorder>>, w: &mut Words) {
    let description = FfxFrameInterpolationContextDescription {
        flags: w.word(),
        max_render_size: w.size(),
        display_size: w.size(),
        back_buffer_format: surface_format(w.word()),
        previous_interpolation_source_format: surface_format(w.word()),
        backend_interface: recorder.clone(),
    };
    let (render, display) = (description.max_render_size, description.display_size);
    let external = |name, w, h| recorder.borrow_mut().external(name, w, h);
    let depth = external("depth", render.width, render.height);
    let motion = external("motion-vectors", display.width, display.height);
    let dilated_depth = external("dilated-depth", render.width, render.height);
    let dilated_motion = external("dilated-motion-vectors", render.width, render.height);
    let reconstructed = external("reconstructed-depth", render.width, render.height);
    let mut color = external("color", display.width, display.height);
    let mut hudless = external("hudless", display.width, display.height);
    color.description.format = description.back_buffer_format;
    hudless.description.format = description.previous_interpolation_source_format;
    let output = external("output", display.width, display.height);
    let optical = external(
        "optical-flow",
        display.width.div_ceil(8),
        display.height.div_ceil(8),
    );
    let scd = external("scene-change", 3, 1);
    let distortion = external("distortion", display.width, display.height);
    let mut context = FfxFrameInterpolationContext::default();
    let created = ffx_frame_interpolation_context_create(&mut context, &description);
    recorder.borrow_mut().result("create-result", created);
    if created.is_err() {
        return;
    }
    // SDK host parity selects original reconstruction; correction has separate GPU tests.
    ffx_frame_interpolation_set_outgoing_reconstruction(&mut context, false).unwrap();
    recorder.borrow_mut().events.push(json!([
        "version",
        ffx_frame_interpolation_get_effect_version()
    ]));
    let queried = ffx_frame_interpolation_context_get_gpu_memory_usage(&context);
    let usage = queried.unwrap_or_default();
    recorder.borrow_mut().events.push(json!([
        "memory-usage-result",
        status(&queried),
        usage.total_usage_in_bytes,
        usage.aliasable_usage_in_bytes
    ]));
    let resources = ffx_frame_interpolation_get_shared_resource_descriptions(&context);
    recorder
        .borrow_mut()
        .events
        .push(json!(["shared-result", status(&resources)]));
    let resources = resources.unwrap();
    shared(recorder, &resources.reconstructed_prev_nearest_depth);
    shared(recorder, &resources.dilated_depth);
    shared(recorder, &resources.dilated_motion_vectors);
    for index in 0..w.word() as usize {
        recorder.borrow_mut().frame(index);
        let op = w.word();
        let flags = w.word();
        let present = w.word();
        let render_size = w.size();
        let frame_id = w.id();
        if op == 0 {
            let prepare = FfxFrameInterpolationPrepareDescription {
                flags,
                command_list: usize::from(present & 1 != 0),
                render_size,
                frame_id,
                jitter_offset: w.coords(),
                motion_vector_scale: w.coords(),
                frame_time_delta: w.scalar(),
                camera_near: w.scalar(),
                camera_far: w.scalar(),
                view_space_to_meters_factor: w.scalar(),
                camera_fov_angle_vertical: w.scalar(),
                depth: depth.clone(),
                motion_vectors: motion.clone(),
                dilated_depth: dilated_depth.clone(),
                dilated_motion_vectors: dilated_motion.clone(),
                reconstructed_prev_depth: reconstructed.clone(),
                camera_position: std::array::from_fn(|_| w.scalar()),
                camera_up: std::array::from_fn(|_| w.scalar()),
                camera_right: std::array::from_fn(|_| w.scalar()),
                camera_forward: std::array::from_fn(|_| w.scalar()),
            };
            let prepared = ffx_frame_interpolation_prepare(&mut context, &prepare);
            recorder.borrow_mut().result("prepare-result", prepared);
        } else {
            let optional = |mask, r: &FfxResource| {
                if present & mask != 0 {
                    r.clone()
                } else {
                    FfxResource::default()
                }
            };
            let dispatch = FfxFrameInterpolationDispatchDescription {
                flags,
                command_list: usize::from(present & 1 != 0),
                render_size,
                frame_id,
                display_size: w.size(),
                current_back_buffer: color.clone(),
                current_back_buffer_hud_less: optional(2, &hudless),
                output: output.clone(),
                interpolation_rect: FfxRect2D {
                    left: w.word() as i32,
                    top: w.word() as i32,
                    width: w.word() as i32,
                    height: w.word() as i32,
                },
                optical_flow_vector: optional(4, &optical),
                optical_flow_scene_change_detection: optional(4, &scd),
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
                dilated_depth: dilated_depth.clone(),
                dilated_motion_vectors: dilated_motion.clone(),
                reconstructed_prev_depth: reconstructed.clone(),
                distortion_field: optional(8, &distortion),
            };
            let dispatched = ffx_frame_interpolation_dispatch(&mut context, &dispatch);
            recorder.borrow_mut().result("dispatch-result", dispatched);
        }
    }
    let destroyed = ffx_frame_interpolation_context_destroy(&mut context);
    recorder.borrow_mut().result("destroy-result", destroyed);
}

/// One-context word stream: context count, flags, max render/display dimensions,
/// backbuffer/history formats, operation count. Each operation starts with kind (0 prepare, 1
/// interpolate), dispatch flags, resource-present bits, render dimensions, u64 ID
/// (low/high); remaining words follow the corresponding SDK description.
pub fn words(
    flags: u32,
    render: [u32; 2],
    display: [u32; 2],
    formats: [FfxSurfaceFormat; 2],
    frames: u32,
) -> Vec<u32> {
    let mut words = vec![
        1,
        flags,
        render[0],
        render[1],
        display[0],
        display[1],
        formats[0] as u32,
        formats[1] as u32,
        frames * 2,
    ];
    for i in 0..frames {
        let size = if i % 5 == 3 {
            [render[0] * 3 / 4, render[1] * 3 / 4]
        } else {
            render
        };
        // Skip an ID and later decrease it under an explicit reset. This also
        // exercises async preparation's ring selection beyond 32-bit frame IDs.
        let id = (1u64 << 32)
            + u64::from(if i > 14 {
                i - 8
            } else if i > 7 {
                i + 2
            } else {
                i
            });
        let reset = i == 15 || i == 10 || i == 11;
        words.extend([0, 0, 1, size[0], size[1], id as u32, (id >> 32) as u32]);
        words.extend(
            [
                0.25,
                -0.375,
                display[0] as f32,
                -(display[1] as f32),
                16.6 + i as f32 * 0.1,
                0.1,
                1000.0,
                1.0,
                1.0,
            ]
            .map(f32::to_bits),
        );
        words.extend(
            [
                i as f32 * 0.1,
                0.5,
                -2.0,
                0.0,
                1.0,
                0.0,
                1.0,
                0.0,
                0.0,
                0.0,
                0.0,
                1.0,
            ]
            .map(f32::to_bits),
        );
        let debug = match i % 7 {
            3 => FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW,
            4 => 3,
            5 => 8,
            _ => 0,
        };
        let present =
            1 | if i % 3 == 1 || formats[0] != formats[1] {
                2
            } else {
                0
            } | 4
                | if i % 4 == 2 { 8 } else { 0 };
        words.extend([
            1,
            debug,
            present,
            size[0],
            size[1],
            id as u32,
            (id >> 32) as u32,
            display[0],
            display[1],
        ]);
        let rect = if i % 4 == 1 {
            [2, 3, display[0] - 4, display[1] - 6]
        } else {
            [0, 0, display[0], display[1]]
        };
        words.extend(rect);
        words.extend([display[0].div_ceil(8), display[1].div_ceil(8)]);
        words.extend([1.0 / display[0] as f32, 1.0 / display[1] as f32].map(f32::to_bits));
        words.push(8);
        words.extend([0.1, 1000.0, 1.0, 1.0, 16.6 + i as f32 * 0.1].map(f32::to_bits));
        words.extend([
            u32::from(reset),
            i % 3,
            0.01f32.to_bits(),
            1000.0f32.to_bits(),
        ]);
    }
    words
}
