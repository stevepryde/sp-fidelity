use serde_json::{Value, json};
use sp_fidelity::error::{FFX_OK, FfxErrorCode};
use sp_fidelity::fsr3::*;
use sp_fidelity::interface::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::host::{build_cpp_composite_host, run_cpp_host};
use sp_fidelity_oracle::recorder::{Recorder, record_message};
use sp_fidelity_oracle::{FRAMEINTERPOLATION, FSR3, FSR3UPSCALER, OPTICALFLOW};
use std::cell::RefCell;
use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::PathBuf;
use std::rc::Rc;
use std::sync::OnceLock;

struct Words<'a> {
    words: &'a [u32],
    at: usize,
}
impl Words<'_> {
    fn word(&mut self) -> u32 {
        let value = self.words[self.at];
        self.at += 1;
        value
    }
    fn scalar(&mut self) -> f32 {
        f32::from_bits(self.word())
    }
    fn frame_id(&mut self) -> u64 {
        u64::from(self.word()) | (u64::from(self.word()) << 32)
    }
    fn dimensions(&mut self) -> FfxDimensions2D {
        FfxDimensions2D {
            width: self.word(),
            height: self.word(),
        }
    }
    fn coords(&mut self) -> FfxFloatCoords2D {
        FfxFloatCoords2D {
            x: self.scalar(),
            y: self.scalar(),
        }
    }
    fn rect(&mut self) -> FfxRect2D {
        FfxRect2D {
            left: self.word() as i32,
            top: self.word() as i32,
            width: self.word() as i32,
            height: self.word() as i32,
        }
    }
}
fn status<T>(result: &Result<T, FfxErrorCode>) -> FfxErrorCode {
    result.as_ref().err().copied().unwrap_or(FFX_OK)
}

fn sequence(recorder: &Rc<RefCell<Recorder>>, w: &mut Words<'_>) {
    let backend: FfxInterfaceRef = recorder.clone();
    let description = FfxFsr3ContextDescription {
        flags: w.word(),
        max_render_size: w.dimensions(),
        max_upscale_size: w.dimensions(),
        display_size: w.dimensions(),
        back_buffer_format: FfxSurfaceFormat::R16G16B16A16Float,
        fp_message: None,
        backend_interface_shared_resources: backend.clone(),
        backend_interface_upscaling: backend.clone(),
        backend_interface_frame_interpolation: backend,
    };
    sp_fidelity::fsr3upscaler::ffx_fsr3_upscaler_set_global_debug_message(Some(record_message), 0)
        .unwrap();
    Recorder::record_messages(recorder);
    let r = description.max_render_size;
    let d = description.display_size;
    let external = |name, width, height| recorder.borrow_mut().external(name, width, height);
    let color = external("color", r.width, r.height);
    let depth = external("depth", r.width, r.height);
    let motion = external("motion-vectors", r.width, r.height);
    let exposure = external("exposure", 1, 1);
    let reactive = external("reactive", r.width, r.height);
    let transparency = external("transparency", r.width, r.height);
    let upscaled = external("upscaled", d.width, d.height);
    let mut present = external("present", d.width, d.height);
    let mut hudless = external("hudless", d.width, d.height);
    present.description.format = description.back_buffer_format;
    hudless.description.format = description.back_buffer_format;
    hudless.name = "hudless".into();
    let interpolated = external("interpolated", d.width, d.height);
    let opaque = external("opaque", r.width, r.height);
    let out_reactive = external("out-reactive", r.width, r.height);
    let mut context = FfxFsr3Context::default();
    let created = ffx_fsr3_context_create(&mut context, &description);
    recorder.borrow_mut().result("create-result", created);
    if created.is_ok() {
        let callback = ffx_fsr3_get_frame_generation_callback(&context).unwrap();
        for index in 0..w.word() {
            recorder.borrow_mut().frame(index as usize);
            match w.word() {
                0 => {
                    let frame_id = w.frame_id();
                    let optional = w.word();
                    let p = FfxFsr3DispatchUpscaleDescription {
                        frame_id,
                        command_list: 1,
                        color: color.clone(),
                        depth: depth.clone(),
                        motion_vectors: motion.clone(),
                        exposure: if optional & 1 != 0 {
                            exposure.clone()
                        } else {
                            FfxResource::default()
                        },
                        reactive: if optional & 2 != 0 {
                            reactive.clone()
                        } else {
                            FfxResource::default()
                        },
                        transparency_and_composition: if optional & 4 != 0 {
                            transparency.clone()
                        } else {
                            FfxResource::default()
                        },
                        upscale_output: upscaled.clone(),
                        render_size: w.dimensions(),
                        upscale_size: w.dimensions(),
                        jitter_offset: w.coords(),
                        motion_vector_scale: w.coords(),
                        enable_sharpening: w.word() != 0,
                        sharpness: w.scalar(),
                        frame_time_delta: w.scalar(),
                        pre_exposure: w.scalar(),
                        reset: w.word() != 0,
                        camera_near: w.scalar(),
                        camera_far: w.scalar(),
                        camera_fov_angle_vertical: w.scalar(),
                        view_space_to_meters_factor: w.scalar(),
                        flags: w.word(),
                    };
                    let result = ffx_fsr3_context_dispatch_upscale(&mut context, &p);
                    recorder.borrow_mut().result("upscale-result", result);
                }
                1 => {
                    let p = FfxFsr3DispatchFrameGenerationPrepareDescription {
                        frame_id: w.frame_id(),
                        command_list: 1,
                        depth: depth.clone(),
                        motion_vectors: motion.clone(),
                        render_size: w.dimensions(),
                        jitter_offset: w.coords(),
                        motion_vector_scale: w.coords(),
                        frame_time_delta: w.scalar(),
                        camera_near: w.scalar(),
                        camera_far: w.scalar(),
                        view_space_to_meters_factor: w.scalar(),
                        camera_fov_angle_vertical: w.scalar(),
                    };
                    let result =
                        ffx_fsr3_context_dispatch_frame_generation_prepare(&mut context, &p);
                    recorder.borrow_mut().result("prepare-result", result);
                }
                2 => {
                    let p = FfxFrameGenerationConfig {
                        frame_id: w.frame_id(),
                        flags: w.word(),
                        frame_generation_enabled: w.word() != 0,
                        allow_async_workloads: w.word() != 0,
                        allow_async_present: w.word() != 0,
                        hudless_color: if w.word() != 0 {
                            hudless.clone()
                        } else {
                            FfxResource::default()
                        },
                        interpolation_rect: w.rect(),
                        swap_chain: 7,
                        frame_generation_callback: Some(callback.clone()),
                        present_callback: Some(Rc::new(|_| Ok(()))),
                        ..Default::default()
                    };
                    let result = ffx_fsr3_configure_frame_generation(&mut context, &p);
                    recorder.borrow_mut().result("configure-result", result);
                }
                3 => {
                    let frame_id = w.frame_id();
                    let reset = w.word() != 0;
                    let back_buffer_transfer_function = match w.word() {
                        0 => FfxBackbufferTransferFunction::Srgb,
                        1 => FfxBackbufferTransferFunction::Pq,
                        2 => FfxBackbufferTransferFunction::Scrgb,
                        other => panic!("transfer {other}"),
                    };
                    let p = FfxFrameGenerationDispatchDescription {
                        frame_id,
                        command_list: 1,
                        present_color: present.clone(),
                        outputs: [
                            interpolated.clone(),
                            FfxResource::default(),
                            FfxResource::default(),
                            FfxResource::default(),
                        ],
                        num_interpolated_frames: 1,
                        reset,
                        back_buffer_transfer_function,
                        min_max_luminance: [w.scalar(), w.scalar()],
                        interpolation_rect: w.rect(),
                    };
                    let result = callback(&p);
                    recorder
                        .borrow_mut()
                        .result("frame-generation-result", result);
                }
                4 => {
                    let p = FfxFsr3GenerateReactiveDescription {
                        command_list: 1,
                        color_opaque_only: opaque.clone(),
                        color_pre_upscale: color.clone(),
                        out_reactive: out_reactive.clone(),
                        render_size: w.dimensions(),
                        scale: w.scalar(),
                        cutoff_threshold: w.scalar(),
                        binary_value: w.scalar(),
                        flags: w.word(),
                    };
                    let result = ffx_fsr3_context_generate_reactive_mask(&mut context, &p);
                    recorder.borrow_mut().result("reactive-result", result);
                }
                5 => {
                    let result = ffx_fsr3_context_get_gpu_memory_usage(&context);
                    let (up, of, fi) = result.unwrap_or_default();
                    recorder.borrow_mut().events.push(json!([
                        "memory-usage-result",
                        status(&result),
                        up.total_usage_in_bytes,
                        up.aliasable_usage_in_bytes,
                        of.total_usage_in_bytes,
                        of.aliasable_usage_in_bytes,
                        fi.total_usage_in_bytes,
                        fi.aliasable_usage_in_bytes
                    ]));
                }
                op => panic!("op {op}"),
            }
        }
        let result = ffx_fsr3_context_destroy(&mut context);
        recorder.borrow_mut().result("destroy-result", result);
        if description.flags & FFX_FSR3_ENABLE_UPSCALING_ONLY == 0 {
            recorder.borrow_mut().result(
                "destroyed-callback-result",
                callback(&FfxFrameGenerationDispatchDescription::default()),
            );
        }
    }
}

fn run_rust(
    capabilities: FfxDeviceCapabilities,
    words: &[u32],
) -> (Vec<Value>, HashMap<String, Vec<u8>>) {
    let recorder = Rc::new(RefCell::new(Recorder::new(capabilities)));
    let mut w = Words { words, at: 0 };
    for _ in 0..w.word() {
        sequence(&recorder, &mut w);
    }
    assert_eq!(
        w.at,
        words.len(),
        "Rust driver must consume the application inputs"
    );
    let mut recorder = recorder.borrow_mut();
    (
        std::mem::take(&mut recorder.events),
        std::mem::take(&mut recorder.init_data),
    )
}

pub fn capabilities(fp16: bool, wave_min: u32, wave_max: u32) -> FfxDeviceCapabilities {
    FfxDeviceCapabilities {
        fp16_supported: fp16,
        wave_lane_count_min: wave_min,
        wave_lane_count_max: wave_max,
        maximum_supported_shader_model: FfxShaderModel::ShaderModel6_6,
        ..Default::default()
    }
}

pub fn compare(name: &str, capabilities: FfxDeviceCapabilities, words: &[u32]) {
    static HOST: OnceLock<(PathBuf, PathBuf)> = OnceLock::new();
    let root = PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join("fsr3-host");
    let host = HOST.get_or_init(|| {
        build_cpp_composite_host(
            &root.join("build"),
            &FSR3,
            &[
                (FfxEffect::Fsr3Upscaler, &FSR3UPSCALER),
                (FfxEffect::OpticalFlow, &OPTICALFLOW),
                (FfxEffect::FrameInterpolation, &FRAMEINTERPOLATION),
            ],
        )
    });
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
    let mut cpp: Vec<Value> = output
        .lines()
        .map(|line| serde_json::from_str(line).unwrap_or_else(|e| panic!("{line}: {e}")))
        .collect();
    // By layout: OpticalFlowSpdConstants' padding words, which the SDK leaves
    // uninitialized.
    sp_fidelity_oracle::host::clear_constant_padding(&mut cpp);
    let (rust, rust_data) = run_rust(capabilities, words);
    fs::write(directory.join("cpp.jsonl"), output).unwrap();
    fs::write(
        directory.join("rust.jsonl"),
        rust.iter()
            .map(Value::to_string)
            .collect::<Vec<_>>()
            .join("\n"),
    )
    .unwrap();
    for (index, (c, r)) in cpp.iter().zip(&rust).enumerate() {
        assert_eq!(
            c,
            r,
            "{name}: event {index} differs; captures in {}",
            directory.display()
        );
    }
    assert_eq!(cpp.len(), rust.len(), "{name}: event counts differ");
    let cpp_data: HashMap<String, Vec<u8>> = fs::read_dir(init_data)
        .unwrap()
        .map(|entry| {
            let path = entry.unwrap().path();
            (
                path.file_stem().unwrap().to_string_lossy().into_owned(),
                fs::read(path).unwrap(),
            )
        })
        .collect();
    assert_eq!(
        cpp_data.keys().collect::<BTreeSet<_>>(),
        rust_data.keys().collect(),
        "{name}: initialization resources differ"
    );
    for (resource, data) in cpp_data {
        assert_eq!(
            data, rust_data[&resource],
            "{name}: {resource} initialization bytes differ"
        );
    }
    println!(
        "{name}: {} composite events match the unchanged SDK",
        cpp.len()
    );
}
