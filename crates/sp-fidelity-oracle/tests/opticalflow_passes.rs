//! Full optical-flow frame sequences, independently replayed with unchanged HLSL.
//! Stable outputs must match exactly. SDK-P32 excludes only the original SCD
//! race's first two words; independently carried history is a tainted diagnostic.
//! Select explicitly: cargo test -p sp-fidelity-oracle --release --test opticalflow_passes -- --ignored --nocapture
mod framegen_support;
#[path = "framegen_support/gpu.rs"]
mod inputs;
use sp_fidelity::interface::FfxInterface;
use sp_fidelity::opticalflow::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::{OPTICALFLOW, compare, gpu};
use sp_fidelity_wgpu::ffx_get_interface_wgpu;
use std::fs;

fn run(size: [u32; 2], flags: u32) {
    let gpu = gpu::Gpu::new(false, None);
    let directory = gpu::case_directory(&format!(
        "opticalflow-{}x{}-flags-{flags}",
        size[0], size[1]
    ));
    let vector_size = size.map(|n| n.div_ceil(8));
    let application = [
        inputs::input(
            &gpu,
            "color",
            size,
            FfxSurfaceFormat::R16G16B16A16Float,
            inputs::color(size, 0),
            false,
        ),
        inputs::input(
            &gpu,
            "optical-flow",
            vector_size,
            FfxSurfaceFormat::R16G16Sint,
            inputs::zeros(vector_size, 4),
            true,
        ),
        inputs::input(
            &gpu,
            "scene-change",
            [3, 1],
            FfxSurfaceFormat::R32Uint,
            inputs::zeros([3, 1], 4),
            true,
        ),
    ];
    let (backend, _) = ffx_get_interface_wgpu(&gpu.device);
    let caps = backend.borrow_mut().get_device_capabilities().unwrap();
    let capture = gpu::Capture::install(&mut backend.borrow_mut(), &directory, &OPTICALFLOW);
    let mut context = FfxOpticalflowContext::default();
    ffx_opticalflow_context_create(
        &mut context,
        &FfxOpticalflowContextDescription {
            backend_interface: backend.clone(),
            flags,
            resolution: FfxDimensions2D {
                width: size[0],
                height: size[1],
            },
        },
    )
    .unwrap();
    let mut words = vec![flags, size[0], size[1], 24];
    let mut updates = Vec::new();
    for frame in 0..24 {
        capture.set_frame(frame as usize);
        let color = inputs::color(size, frame);
        gpu::upload(&gpu.queue, &application[0].texture, &color);
        updates.push(vec![("color", color)]);
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
        let reset = frame == 12 || frame == 13;
        // Keep each transfer function stable long enough for the scene-change
        // warmup to finish and motion history to contribute.
        let transfer = (frame / 8) % 3;
        let dispatched = ffx_opticalflow_context_dispatch(
            &mut context,
            &FfxOpticalflowDispatchDescription {
                command_list,
                color: resource(0),
                optical_flow_vector: resource(1),
                optical_flow_scd: resource(2),
                reset,
                backbuffer_transfer_function: transfer as i32,
                min_max_luminance: FfxFloatCoords2D { x: 0.01, y: 1000.0 },
            },
        );
        assert_eq!(
            backend.borrow_mut().take_job_error(),
            None,
            "GPU frame {frame}"
        );
        dispatched.unwrap();
        words.extend([
            15,
            size[0],
            size[1],
            u32::from(reset),
            transfer,
            0.01f32.to_bits(),
            1000.0f32.to_bits(),
        ]);
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        gpu.queue.submit([encoder.finish()]);
        capture.save(&gpu.device);
    }
    ffx_opticalflow_context_destroy(&mut context).unwrap();
    gpu::write_inputs(&directory, &application, &updates);
    let (_, init) = framegen_support::cpp(&OPTICALFLOW, caps, &words, &directory);
    for (name, bytes) in init {
        fs::write(directory.join("inputs").join(format!("{name}.bin")), bytes).unwrap();
    }
    let stable = |difference: &compare::Difference| {
        // SDK-P32: the original dispatch reads histograms concurrently with
        // another workgroup clearing them. Only its two nondeterministic SCD
        // words are exempt; word 2 is the completed-workgroup counter.
        if difference.stage == OPTICALFLOW.stages[3]
            && difference.resource == "scene-change"
            && difference.mip == 0
            && difference.size == [3, 1]
            && difference.bounds[2] < 2
            && difference.bounds[3] == 0
        {
            Ok("SDK-P32")
        } else {
            Err("stable optical-flow outputs must match the unchanged HLSL exactly".into())
        }
    };
    gpu::replay(&directory, &OPTICALFLOW);
    let replay = compare::compare(&directory, OPTICALFLOW.stages, &stable);
    println!(
        "{} identical inputs: {}",
        directory.display(),
        replay.summary()
    );
    let carried = compare::compare(
        &gpu::run_sequence(&directory, &OPTICALFLOW),
        OPTICALFLOW.stages,
        &|_: &compare::Difference| {
            Err("upstream SCD race taints independently carried history; diagnostic only".into())
        },
    );
    println!(
        "{} upstream-race-tainted own history (diagnostic): {}",
        directory.display(),
        carried.summary()
    );
    assert!(
        replay.accepted()
            && carried.incomplete.is_empty()
            && carried.differences.iter().all(|difference| difference.resource != "scene-change" || difference.bounds[2] < 2),
        "identical inputs: {}\nown history: {}",
        replay.summary(),
        carried.summary()
    );
}

#[test]
#[ignore = "requires Metal and compiled DXC variants"]
fn opticalflow_stable_passes_match_original_hlsl() {
    run([128, 128], 0);
    run([131, 129], FFX_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE);
}
