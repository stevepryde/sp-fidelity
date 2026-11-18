//! Compare the reflection host's scheduling, resource bindings and staged
//! constant bytes with the original AMD C++ component.
mod framegen_support;
use framegen_support::*;
use serde_json::json;
use sp_fidelity::denoiser::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::DENOISER;
use sp_fidelity_oracle::recorder::Recorder;
use std::cell::RefCell;
use std::rc::Rc;

fn run_rust(caps: FfxDeviceCapabilities, words: &[u32]) -> Recorded {
    let recorder = Rc::new(RefCell::new(Recorder::new(caps)));
    let mut w = Words { words, at: 0 };
    let description = FfxDenoiserContextDescription {
        backend_interface: recorder.clone(),
        flags: w.word(),
        window_size: w.size(),
        normals_history_buffer_format: surface_format(w.word()),
    };

    let size = description.window_size;
    let input = |name| {
        recorder
            .borrow_mut()
            .external(name, size.width, size.height)
    };
    let depth = input("depth");
    let motion = input("motion");
    let normal = input("normal");
    let radiance = [input("radiance0"), input("radiance1")];
    let variance = [input("variance0"), input("variance1")];
    let roughness = input("roughness");
    let tiles = recorder.borrow_mut().external(
        "tiles",
        size.width.div_ceil(8) * size.height.div_ceil(8),
        1,
    );
    let indirect = recorder.borrow_mut().external("indirect", 6, 1);
    let output = input("output");

    let mut context = FfxDenoiserContext::default();
    let created = ffx_denoiser_context_create(&mut context, &description);
    recorder.borrow_mut().result("create-result", created);
    if created.is_err() {
        return take(&recorder);
    }
    recorder
        .borrow_mut()
        .events
        .push(json!(["version", ffx_denoiser_get_effect_version()]));

    for index in 0..w.word() as usize {
        recorder.borrow_mut().frame(index);
        let frame_index = w.word();
        let reset = w.word() != 0;
        let parity = w.word() as usize;
        let dispatch = FfxDenoiserReflectionsDispatchDescription {
            command_list: 1,
            depth_hierarchy: depth.clone(),
            motion_vectors: motion.clone(),
            normal: normal.clone(),
            radiance_a: radiance[parity].clone(),
            radiance_b: radiance[1 - parity].clone(),
            variance_a: variance[parity].clone(),
            variance_b: variance[1 - parity].clone(),
            extracted_roughness: roughness.clone(),
            denoiser_tile_list: tiles.clone(),
            indirect_arguments_buffer: indirect.clone(),
            output: output.clone(),
            render_size: w.size(),
            motion_vector_scale: w.coords(),
            inv_projection: std::array::from_fn(|_| w.scalar()),
            inv_view: std::array::from_fn(|_| w.scalar()),
            prev_view_projection: std::array::from_fn(|_| w.scalar()),
            normals_unpack_mul: w.scalar(),
            normals_unpack_add: w.scalar(),
            is_roughness_perceptual: w.word() != 0,
            roughness_channel: w.word(),
            temporal_stability_factor: w.scalar(),
            roughness_threshold: w.scalar(),
            frame_index,
            reset,
        };
        let result = ffx_denoiser_context_dispatch_reflections(&mut context, &dispatch);
        recorder.borrow_mut().result("dispatch-result", result);
    }
    let destroyed = ffx_denoiser_context_destroy(&mut context);
    recorder.borrow_mut().result("destroy-result", destroyed);
    take(&recorder)
}

fn case(
    name: &str,
    caps: FfxDeviceCapabilities,
    flags: u32,
    size: [u32; 2],
    format: FfxSurfaceFormat,
) {
    // First frame, consecutive frame, repeated parity, history reset, frame
    // index restart. External resource selection belongs to the caller and can
    // diverge from the internal ping-pong after a reset.
    let frames = [
        (0, false, 0),
        (1, false, 1),
        (3, false, 0),
        (4, true, 1),
        (0, true, 0),
    ];
    let mut words = vec![flags, size[0], size[1], format as u32, frames.len() as u32];
    for (i, (frame, reset, parity)) in frames.into_iter().enumerate() {
        words.extend([frame, u32::from(reset), parity, size[0] - i as u32, size[1]]);
        words.extend([0.25_f32.to_bits(), (-0.5_f32).to_bits()]);
        // Distinct entries expose swapped matrices, transposition and stale constants.
        words.extend((0..48).map(|j| ((i * 48 + j) as f32 * 0.25 - 3.5).to_bits()));
        words.extend([
            2.0_f32.to_bits(),
            (-1.0_f32).to_bits(),
            (i % 2) as u32,
            (i % 4) as u32,
            (0.5 + i as f32 * 0.0625).to_bits(),
            (1.0 - i as f32 * 0.125).to_bits(),
        ]);
    }
    compare(&DENOISER, name, caps, &words, run_rust);
}

#[test]
fn reflection_jobs_and_history_match_sdk() {
    case(
        "fp32",
        capabilities(false, false),
        FFX_DENOISER_REFLECTIONS,
        [65, 33],
        FfxSurfaceFormat::R16G16B16A16Float,
    );
}

#[test]
fn reflection_half_and_wave64_jobs_match_sdk() {
    case(
        "fp16-wave64",
        capabilities(true, true),
        FFX_DENOISER_REFLECTIONS | FFX_DENOISER_ENABLE_DEPTH_INVERTED,
        [1280, 720],
        FfxSurfaceFormat::R10G10B10A2Unorm,
    );
    case(
        "fp16",
        capabilities(false, true),
        FFX_DENOISER_REFLECTIONS,
        [128, 256],
        FfxSurfaceFormat::R8G8B8A8Snorm,
    );
}
