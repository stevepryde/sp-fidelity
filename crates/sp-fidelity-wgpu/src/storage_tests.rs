//! The core resource set against the SDK's, on one adapter: the same frames
//! through devices requested with different features, and every job's writes
//! compared in the SDK's texel layout (SDK-P38).
use super::*;
use sp_fidelity::fsr2::*;
use sp_fidelity::fsr3upscaler::*;
use std::collections::BTreeMap;
use wgpu::util::DeviceExt;

/// A device with exactly `features` and no more storage textures a stage
/// than `effect` says it needs (`storage_textures_per_stage`), or `None`
/// after printing why. `SP_FIDELITY_REQUIRE_GPU` turns the skip into a
/// failure.
fn device_with(features: wgpu::Features, effect: FfxEffect) -> Option<(wgpu::Device, wgpu::Queue)> {
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
    let result = pollster::block_on(instance.request_adapter(&Default::default()))
        .map_err(|e| e.to_string())
        .and_then(|adapter| {
            pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
                required_features: features,
                required_limits: wgpu::Limits {
                    max_storage_textures_per_shader_stage: storage_textures_per_stage(effect),
                    ..adapter.limits()
                },
                ..Default::default()
            }))
            .map_err(|e| e.to_string())
        });
    match result {
        Ok(device) => Some(device),
        Err(error) => {
            let required =
                std::env::var("SP_FIDELITY_REQUIRE_GPU").is_ok_and(|v| !v.is_empty() && v != "0");
            assert!(
                !required,
                "GPU test cannot run but SP_FIDELITY_REQUIRE_GPU is set: {error}"
            );
            eprintln!("skipping GPU test: {error}");
            None
        }
    }
}

/// What a run's jobs wrote: by frame, job, binding and mip, in the SDK's
/// layout.
type Writes = BTreeMap<(usize, usize, String, u32), Vec<u8>>;

/// Records, after every compute job, each resource it could write.
struct Recorder {
    frame: Rc<std::cell::Cell<usize>>,
    pending: Rc<RefCell<Vec<Pending>>>,
}

struct Pending {
    key: (usize, usize, String, u32),
    readback: readback::Readback,
    /// The SDK's format and the object's, for a texture.
    formats: Option<(FfxSurfaceFormat, wgpu::TextureFormat)>,
}

impl Recorder {
    fn install(backend: &mut FfxWgpuBackend) -> Self {
        let frame = Rc::new(std::cell::Cell::new(0));
        let pending: Rc<RefCell<Vec<Pending>>> = Rc::default();
        let (observed_frame, observed) = (frame.clone(), pending.clone());
        let mut job = (0, 0);
        backend.set_job_observer(Some(Box::new(move |observation| {
            if !observation.after
                || !matches!(observation.job.descriptor, FfxGpuJobDescriptor::Compute(_))
            {
                return;
            }
            let frame = observed_frame.get();
            job = if job.0 == frame {
                (frame, job.1 + 1)
            } else {
                (frame, 0)
            };
            for resource in observation.resources.iter().filter(|r| r.writable) {
                match resource.object {
                    FfxWgpuObject::Texture(texture) => {
                        for mip in 0..texture.mip_level_count() {
                            observed.borrow_mut().push(Pending {
                                key: (frame, job.1, resource.binding.to_owned(), mip),
                                readback: readback::Readback::texture(
                                    observation.device,
                                    observation.encoder,
                                    texture,
                                    mip,
                                ),
                                formats: Some((resource.description.format, texture.format())),
                            });
                        }
                    }
                    FfxWgpuObject::Buffer(buffer) => observed.borrow_mut().push(Pending {
                        key: (frame, job.1, resource.binding.to_owned(), 0),
                        readback: readback::Readback::buffer(
                            observation.device,
                            observation.encoder,
                            buffer,
                        ),
                        formats: None,
                    }),
                }
            }
        })));
        Self { frame, pending }
    }

    /// The writes recorded since the last call, once their encoder is
    /// submitted.
    fn read(&self, device: &wgpu::Device, into: &mut Writes) {
        let pending: Vec<Pending> = self.pending.borrow_mut().drain(..).collect();
        let (keys, readbacks): (Vec<_>, Vec<_>) = pending
            .into_iter()
            .map(|p| ((p.key, p.formats), p.readback))
            .unzip();
        for ((key, formats), bytes) in keys
            .into_iter()
            .zip(readback::Readback::read_all(device, readbacks))
        {
            let bytes = match formats {
                Some((sdk, allocation)) => ffx_sdk_texels_wgpu(sdk, allocation, &bytes),
                None => bytes,
            };
            assert!(into.insert(key.clone(), bytes).is_none(), "{key:?} twice");
        }
    }
}

/// A deterministic value in [0, 1).
fn noise(x: u32, y: u32, seed: u32) -> f32 {
    let mut v = x
        .wrapping_mul(0x9e37_79b1)
        .wrapping_add(y.wrapping_mul(0x85eb_ca77))
        .wrapping_add(seed.wrapping_mul(0xc2b2_ae3d));
    v ^= v >> 15;
    v = v.wrapping_mul(0x2c1b_3c6d);
    v ^= v >> 12;
    v = v.wrapping_mul(0x297a_2d39);
    v ^= v >> 15;
    (v >> 8) as f32 / (1 << 24) as f32
}

/// One frame's application inputs at `render`, with content that moves,
/// depth edges, masks and an exposure: enough for every pass to do work.
struct Inputs {
    color: wgpu::Texture,
    opaque: wgpu::Texture,
    depth: wgpu::Texture,
    motion: wgpu::Texture,
    reactive: wgpu::Texture,
    composition: wgpu::Texture,
    exposure: wgpu::Texture,
}

impl Inputs {
    fn new(device: &wgpu::Device, queue: &wgpu::Queue, render: [u32; 2], frame: u32) -> Self {
        let texture = |format, size: [u32; 2], data: &[u8]| {
            device.create_texture_with_data(
                queue,
                &wgpu::TextureDescriptor {
                    label: None,
                    size: wgpu::Extent3d {
                        width: size[0],
                        height: size[1],
                        depth_or_array_layers: 1,
                    },
                    mip_level_count: 1,
                    sample_count: 1,
                    dimension: wgpu::TextureDimension::D2,
                    format,
                    usage: wgpu::TextureUsages::TEXTURE_BINDING,
                    view_formats: &[],
                },
                wgpu::util::TextureDataOrder::LayerMajor,
                data,
            )
        };
        let texels = |f: &dyn Fn(u32, u32) -> Vec<f32>| -> Vec<f32> {
            (0..render[1])
                .flat_map(|y| (0..render[0]).flat_map(move |x| f(x, y)))
                .collect()
        };
        // A bright block that crosses the frame over a noisy HDR ground, in
        // front of it in reversed-Z depth and with its own motion.
        let block = |x: u32, y: u32| {
            let left = (frame * 5) % render[0];
            (left..left + render[0] / 4).contains(&x) && (render[1] / 4..render[1] / 2).contains(&y)
        };
        let color = |opaque: bool| {
            texels(&|x, y| {
                let ground = 0.02 + 6. * noise(x / 3, y / 3, 1).powi(3);
                let spark = if !opaque && noise(x, y, 40 + frame) > 0.97 {
                    30.
                } else {
                    0.
                };
                let v = if block(x, y) { 12. } else { ground } + spark;
                vec![v, v * 0.7 + 0.01, v * noise(x, y, 2), 1.]
            })
        };
        let bytes_u8 = |f: &dyn Fn(u32, u32) -> u8| -> Vec<u8> {
            (0..render[1])
                .flat_map(|y| (0..render[0]).map(move |x| f(x, y)))
                .collect()
        };
        Self {
            color: texture(
                wgpu::TextureFormat::Rgba32Float,
                render,
                bytemuck::cast_slice(&color(false)),
            ),
            opaque: texture(
                wgpu::TextureFormat::Rgba32Float,
                render,
                bytemuck::cast_slice(&color(true)),
            ),
            depth: texture(
                wgpu::TextureFormat::R32Float,
                render,
                bytemuck::cast_slice(&texels(&|x, y| {
                    vec![if block(x, y) {
                        0.5
                    } else {
                        0.002 + 0.05 * noise(x / 7, y / 7, 3)
                    }]
                })),
            ),
            motion: texture(
                wgpu::TextureFormat::Rg32Float,
                render,
                bytemuck::cast_slice(&texels(&|x, y| {
                    if block(x, y) {
                        vec![-5. / render[0] as f32, 0.]
                    } else {
                        vec![
                            0.004 * (noise(x / 9, y / 9, 4) - 0.5),
                            0.004 * (noise(x / 9, y / 9, 5) - 0.5),
                        ]
                    }
                })),
            ),
            reactive: texture(
                wgpu::TextureFormat::R8Unorm,
                render,
                &bytes_u8(&|x, y| (230. * noise(x / 2, y / 2, 6).powi(4)) as u8),
            ),
            composition: texture(
                wgpu::TextureFormat::R8Unorm,
                render,
                &bytes_u8(&|x, y| (255. * noise(x / 4, y / 4, 7).powi(6)) as u8),
            ),
            exposure: texture(
                wgpu::TextureFormat::R32Float,
                [1, 1],
                bytemuck::cast_slice(&[0.6 + 0.05 * frame as f32]),
            ),
        }
    }
}

const FRAMES: u32 = 5;

#[derive(Clone, Copy, Debug)]
struct Case {
    display: [u32; 2],
    render: [u32; 2],
    fp16: bool,
    auto_exposure: bool,
    /// Sharpening, and FSR2's generated reactivity.
    extras: bool,
}

const CASES: [Case; 4] = [
    // SPD reduces above mip 5: both of its dispatches run.
    Case {
        display: [200, 120],
        render: [133, 80],
        fp16: true,
        auto_exposure: false,
        extras: false,
    },
    Case {
        display: [200, 120],
        render: [133, 80],
        fp16: false,
        auto_exposure: true,
        extras: true,
    },
    // Native AA.
    Case {
        display: [150, 90],
        render: [150, 90],
        fp16: true,
        auto_exposure: true,
        extras: false,
    },
    // Six mips: SPD stops at mip 5 and stores the exposure there.
    Case {
        display: [80, 60],
        render: [40, 30],
        fp16: true,
        auto_exposure: true,
        extras: true,
    },
];

fn output(device: &wgpu::Device, size: [u32; 2]) -> wgpu::Texture {
    device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: size[0],
            height: size[1],
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba16Float,
        usage: wgpu::TextureUsages::STORAGE_BINDING | wgpu::TextureUsages::COPY_SRC,
        view_formats: &[],
    })
}

fn dimensions(size: [u32; 2]) -> FfxDimensions2D {
    FfxDimensions2D {
        width: size[0],
        height: size[1],
    }
}

/// `FRAMES` frames of FSR2 on `device`: what every job wrote, and the
/// context's GPU memory.
fn fsr2(device: &wgpu::Device, queue: &wgpu::Queue, case: Case, spd: Spd) -> (Writes, u64) {
    let (backend, interface) = ffx_get_interface_wgpu(device);
    backend.borrow_mut().set_fp16_supported(case.fp16);
    backend.borrow_mut().capabilities.split_spd |= spd == Spd::Split;
    let recorder = Recorder::install(&mut backend.borrow_mut());
    let mut context = FfxFsr2Context::default();
    let mut flags = FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE
        | FFX_FSR2_ENABLE_DEPTH_INVERTED
        | FFX_FSR2_ENABLE_DEPTH_INFINITE;
    if case.auto_exposure {
        flags |= FFX_FSR2_ENABLE_AUTO_EXPOSURE;
    }
    ffx_fsr2_context_create(
        &mut context,
        &FfxFsr2ContextDescription {
            flags,
            max_render_size: dimensions(case.display),
            display_size: dimensions(case.display),
            fp_message: None,
            backend_interface: interface,
        },
    )
    .unwrap();
    let memory = ffx_fsr2_context_get_gpu_memory_usage(&mut context)
        .unwrap()
        .total_usage_in_bytes;
    let output = output(device, case.display);
    let phases = ffx_fsr2_get_jitter_phase_count(case.render[0] as i32, case.display[0] as i32);
    let mut writes = Writes::new();
    for frame in 0..FRAMES {
        recorder.frame.set(frame as usize);
        let inputs = Inputs::new(device, queue, case.render, frame);
        let (x, y) = ffx_fsr2_get_jitter_offset(frame as i32, phases).unwrap();
        let mut description = FfxFsr2DispatchDescription {
            jitter_offset: FfxFloatCoords2D { x, y },
            motion_vector_scale: FfxFloatCoords2D {
                x: case.render[0] as f32,
                y: case.render[1] as f32,
            },
            render_size: dimensions(case.render),
            enable_sharpening: case.extras,
            sharpness: 0.6,
            frame_time_delta: 16.6,
            pre_exposure: 1.,
            reset: frame == 0,
            camera_near: f32::MAX,
            camera_far: 0.1,
            camera_fov_angle_vertical: 1.,
            view_space_to_meters_factor: 1.,
            enable_auto_reactive: case.extras,
            auto_tc_threshold: 0.05,
            auto_tc_scale: 1.,
            auto_reactive_scale: 5.,
            auto_reactive_max: 0.9,
            ..Default::default()
        };
        {
            let mut backend = backend.borrow_mut();
            let read = FFX_RESOURCE_STATE_COMPUTE_READ;
            description.command_list = backend
                .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
            description.color = backend.ffx_get_resource_wgpu(&inputs.color, "color", read);
            description.color_opaque_only =
                backend.ffx_get_resource_wgpu(&inputs.opaque, "opaque", read);
            description.depth = backend.ffx_get_resource_wgpu(&inputs.depth, "depth", read);
            description.motion_vectors =
                backend.ffx_get_resource_wgpu(&inputs.motion, "motion", read);
            description.reactive =
                backend.ffx_get_resource_wgpu(&inputs.reactive, "reactive", read);
            description.transparency_and_composition =
                backend.ffx_get_resource_wgpu(&inputs.composition, "composition", read);
            if !case.auto_exposure {
                description.exposure =
                    backend.ffx_get_resource_wgpu(&inputs.exposure, "exposure", read);
            }
            description.output = backend.ffx_get_resource_wgpu(
                &output,
                "output",
                FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            );
        }
        ffx_fsr2_context_dispatch(&mut context, &description).unwrap();
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(description.command_list)
            .unwrap();
        assert_eq!(backend.borrow_mut().take_job_error(), None);
        queue.submit([encoder.finish()]);
        recorder.read(device, &mut writes);
    }
    ffx_fsr2_context_destroy(&mut context).unwrap();
    (writes, memory)
}

/// As `fsr2`, for the standalone FSR3 upscaler and its shared resources.
fn fsr3(device: &wgpu::Device, queue: &wgpu::Queue, case: Case, spd: Spd) -> (Writes, u64) {
    let (backend, interface) = ffx_get_interface_wgpu(device);
    backend.borrow_mut().set_fp16_supported(case.fp16);
    backend.borrow_mut().capabilities.split_spd |= spd == Spd::Split;
    let recorder = Recorder::install(&mut backend.borrow_mut());
    let mut context = FfxFsr3UpscalerContext::default();
    let mut flags = FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE
        | FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED
        | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE;
    if case.auto_exposure {
        flags |= FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE;
    }
    ffx_fsr3_upscaler_context_create(
        &mut context,
        &FfxFsr3UpscalerContextDescription {
            flags,
            max_render_size: dimensions(case.display),
            max_upscale_size: dimensions(case.display),
            fp_message: None,
            backend_interface: interface,
        },
    )
    .unwrap();
    let memory = ffx_fsr3_upscaler_context_get_gpu_memory_usage(&mut context)
        .unwrap()
        .total_usage_in_bytes;
    let shared = ffx_fsr3_upscaler_get_shared_resource_descriptions(&context).unwrap();
    let shared = [
        shared.dilated_depth,
        shared.dilated_motion_vectors,
        shared.reconstructed_prev_nearest_depth,
    ]
    .map(|description| {
        let texture = backend
            .borrow()
            .ffx_create_texture_wgpu(FfxEffect::Fsr3Upscaler, &description)
            .unwrap();
        (texture, description)
    });
    let output = output(device, case.display);
    let phases =
        ffx_fsr3_upscaler_get_jitter_phase_count(case.render[0] as i32, case.display[0] as i32);
    let mut writes = Writes::new();
    for frame in 0..FRAMES {
        recorder.frame.set(frame as usize);
        let inputs = Inputs::new(device, queue, case.render, frame);
        let (x, y) = ffx_fsr3_upscaler_get_jitter_offset(frame as i32, phases).unwrap();
        let mut description = FfxFsr3UpscalerDispatchDescription {
            jitter_offset: FfxFloatCoords2D { x, y },
            motion_vector_scale: FfxFloatCoords2D {
                x: case.render[0] as f32,
                y: case.render[1] as f32,
            },
            render_size: dimensions(case.render),
            upscale_size: dimensions(case.display),
            enable_sharpening: case.extras,
            sharpness: 0.6,
            frame_time_delta: 16.6,
            pre_exposure: 1.,
            reset: frame == 0,
            camera_near: f32::MAX,
            camera_far: 0.1,
            camera_fov_angle_vertical: 1.,
            view_space_to_meters_factor: 1.,
            ..Default::default()
        };
        {
            let mut backend = backend.borrow_mut();
            let read = FFX_RESOURCE_STATE_COMPUTE_READ;
            let write = FFX_RESOURCE_STATE_UNORDERED_ACCESS;
            description.command_list = backend
                .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
            description.color = backend.ffx_get_resource_wgpu(&inputs.color, "color", read);
            description.depth = backend.ffx_get_resource_wgpu(&inputs.depth, "depth", read);
            description.motion_vectors =
                backend.ffx_get_resource_wgpu(&inputs.motion, "motion", read);
            description.reactive =
                backend.ffx_get_resource_wgpu(&inputs.reactive, "reactive", read);
            description.transparency_and_composition =
                backend.ffx_get_resource_wgpu(&inputs.composition, "composition", read);
            if !case.auto_exposure {
                description.exposure =
                    backend.ffx_get_resource_wgpu(&inputs.exposure, "exposure", read);
            }
            let mut register = |index: usize| {
                let (texture, description) = &shared[index];
                backend.ffx_get_described_resource_wgpu(
                    texture,
                    description.resource_description,
                    description.name,
                    write,
                )
            };
            description.dilated_depth = register(0);
            description.dilated_motion_vectors = register(1);
            description.reconstructed_prev_nearest_depth = register(2);
            description.output = backend.ffx_get_resource_wgpu(&output, "output", write);
        }
        ffx_fsr3_upscaler_context_dispatch(&mut context, &description).unwrap();
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(description.command_list)
            .unwrap();
        assert_eq!(backend.borrow_mut().take_job_error(), None);
        queue.submit([encoder.finish()]);
        recorder.read(device, &mut writes);
    }
    ffx_fsr3_upscaler_context_destroy(&mut context).unwrap();
    (writes, memory)
}

/// Each write of `expected` that `actual` holds differently, as the first
/// texel that differs; an empty list where both wrote the same things.
fn differences(expected: &Writes, actual: &Writes, keep: impl Fn(&str) -> bool) -> Vec<String> {
    let keys =
        |writes: &Writes| -> Vec<_> { writes.keys().filter(|key| keep(&key.2)).cloned().collect() };
    if keys(expected) != keys(actual) {
        return vec![format!(
            "the runs wrote different resources: {} against {}",
            keys(expected).len(),
            keys(actual).len()
        )];
    }
    keys(expected)
        .into_iter()
        .filter_map(|key| {
            let (a, b) = (&expected[&key], &actual[&key]);
            (a != b).then(|| {
                let at = a.iter().zip(b).position(|(a, b)| a != b);
                let words = |bytes: &[u8]| -> Vec<String> {
                    bytes
                        .chunks(4)
                        .take(4)
                        .map(|word| {
                            let mut padded = [0; 4];
                            padded[..word.len()].copy_from_slice(word);
                            format!("{:#010x}", u32::from_le_bytes(padded))
                        })
                        .collect()
                };
                let from = at.unwrap_or(0) / 4 * 4;
                format!(
                    "frame {} job {} {} mip {}: {} bytes against {}, first difference at byte \
                     {at:?}: {:?} against {:?}",
                    key.0,
                    key.1,
                    key.2,
                    key.3,
                    a.len(),
                    b.len(),
                    words(&a[from.min(a.len())..]),
                    words(&b[from.min(b.len())..])
                )
            })
        })
        .collect()
}

/// How a run's backend is set up beyond its device's features.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Spd {
    /// As the device's features select.
    Selected,
    /// Two dispatches on a device with the SDK's storage formats, where the
    /// backend otherwise keeps the SDK's one. The reference for what SPD's
    /// reduction above mip 5 writes: in one dispatch it reads mip 5 while
    /// other workgroups write it, which is a race on Metal (SDK-P14).
    Split,
}

type Run = fn(&wgpu::Device, &wgpu::Queue, Case, Spd) -> (Writes, u64);

/// A run, the effect it runs and its name.
type Effect = (Run, FfxEffect, &'static str);
const FSR2: Effect = (fsr2, FfxEffect::Fsr2, "FSR2");
const FSR3: Effect = (fsr3, FfxEffect::Fsr3Upscaler, "FSR3");

/// The writes SDK-P14's race reaches in a one-dispatch SPD: what it stores at
/// the 1x1 mip.
fn handed_off(binding: &str) -> bool {
    ["rw_auto_exposure", "rw_frame_info"].contains(&binding)
}

fn assert_same(name: &str, case: Case, expected: &Writes, actual: &Writes, keep: fn(&str) -> bool) {
    let compared = expected.keys().filter(|key| keep(&key.2)).count();
    assert!(compared > 0);
    let differences = differences(expected, actual, keep);
    assert!(
        differences.is_empty(),
        "{name} {case:?}: {} of {compared} writes differ:\n{}",
        differences.len(),
        differences[..differences.len().min(12)].join("\n")
    );
}

/// Defects: a core-set allocation, declaration or store that does not hold
/// what the SDK's format would (a widened store the hardware converts
/// differently, a lock that is not the unorm value, a component in the wrong
/// texel); atomics on the buffer that lose a minimum or address another
/// texel. Any of them changes a texel some job writes. The devices differ
/// only in the storage features and both split SPD, so they run the same
/// permutations on the same schedule; a second core-set run would differ from
/// the first if a hand-off between its passes or dispatches raced.
fn core_set_writes_what_the_sdk_set_writes((run, effect, name): Effect) {
    let sdk = (required_features() - wgpu::Features::SUBGROUP) | optional_features();
    let core = core_required_features() | optional_features();
    let (Some(sdk), Some(core)) = (device_with(sdk, effect), device_with(core, effect)) else {
        return;
    };
    for case in CASES {
        let (expected, sdk_memory) = run(&sdk.0, &sdk.1, case, Spd::Split);
        let (actual, core_memory) = run(&core.0, &core.1, case, Spd::Selected);
        assert_same(name, case, &expected, &actual, |_| true);
        let (again, _) = run(&core.0, &core.1, case, Spd::Selected);
        assert_same(name, case, &actual, &again, |_| true);
        eprintln!(
            "{name} {case:?}: {} writes identical; GPU memory {sdk_memory} bytes (SDK set), \
             {core_memory} (core set)",
            expected.len()
        );
    }
}

#[test]
fn fsr2_core_resource_set_writes_what_the_sdk_resource_set_writes() {
    core_set_writes_what_the_sdk_set_writes(FSR2);
}

#[test]
fn fsr3_core_resource_set_writes_what_the_sdk_resource_set_writes() {
    core_set_writes_what_the_sdk_set_writes(FSR3);
}

/// Defect: SPD's two dispatches reducing differently from its one: tiles
/// that store other texels, or a second dispatch that changes what the first
/// stored. One device, without subgroups, runs both. With the application's
/// exposure nothing reads what SPD stores at the 1x1 mip, so every other
/// write of every pass is compared; that store alone is the hand-off the
/// one-dispatch form races on (`handed_off`).
fn split_spd_writes_what_one_dispatch_writes((run, effect, name): Effect) {
    let features = (required_features() - wgpu::Features::SUBGROUP) | optional_features();
    let Some((device, queue)) = device_with(features, effect) else {
        return;
    };
    for case in CASES.into_iter().filter(|case| !case.auto_exposure) {
        let (expected, _) = run(&device, &queue, case, Spd::Selected);
        let (actual, _) = run(&device, &queue, case, Spd::Split);
        assert_same(name, case, &expected, &actual, |binding| {
            !handed_off(binding)
        });
    }
}

#[test]
fn fsr2_split_spd_writes_what_one_dispatch_writes() {
    split_spd_writes_what_one_dispatch_writes(FSR2);
}

#[test]
fn fsr3_split_spd_writes_what_one_dispatch_writes() {
    split_spd_writes_what_one_dispatch_writes(FSR3);
}

/// Defect: SPD without wave operations (the SDK's
/// `FFX_SPD_NO_WAVE_OPERATIONS`) reducing differently from its quad
/// intrinsics. The pyramids read only what the passes before them wrote from
/// the application's inputs, which no permutation the wave lanes select
/// changes, so their writes are compared between a device with subgroups and
/// one without, both in the SDK's one dispatch and so apart from its
/// hand-off (`handed_off`).
fn spd_without_wave_operations_writes_what_its_wave_operations_write((run, effect, name): Effect) {
    let wave = required_features() | optional_features();
    let (Some(wave), Some(none)) = (
        device_with(wave, effect),
        device_with(wave - wgpu::Features::SUBGROUP, effect),
    ) else {
        return;
    };
    let spd = |binding: &str| {
        binding.starts_with("rw_img_mip")
            || binding.starts_with("rw_spd_mip")
            || binding == "rw_farthest_depth_mip1"
    };
    for case in CASES.into_iter().filter(|case| !case.auto_exposure) {
        let (expected, _) = run(&wave.0, &wave.1, case, Spd::Selected);
        let (actual, _) = run(&none.0, &none.1, case, Spd::Selected);
        assert_same(name, case, &expected, &actual, spd);
    }
}

#[test]
fn fsr2_spd_without_wave_operations_writes_what_its_wave_operations_write() {
    spd_without_wave_operations_writes_what_its_wave_operations_write(FSR2);
}

#[test]
fn fsr3_spd_without_wave_operations_writes_what_its_wave_operations_write() {
    spd_without_wave_operations_writes_what_its_wave_operations_write(FSR3);
}

#[test]
fn core_storage_locks_hold_what_an_r8_unorm_texel_returns() {
    // Defect: `ffxWgslUnorm8` rounding a value to another code than the
    // device's typed R8_UNORM store, or holding another float than its load
    // returns. The port's own accessor (FSR3's StoreNewLocks, which stores
    // arbitrary lock strengths) writes the core set's R32Float lock texture,
    // and a typed store writes the SDK's; a second pass reads the latter as
    // any pass would. Values sit on, just under and just over every code and
    // every halfway point, with the clamps and a NaN.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let mut values = vec![-1., -0., 0., 1., 2., f32::NAN, f32::INFINITY, 1e-30, 0.5];
    for code in 0..=255u32 {
        for centre in [code as f32 / 255., (code as f32 + 0.5) / 255.] {
            for step in -3i32..=3 {
                values.push(f32::from_bits(
                    (centre.to_bits() as i32 + step).max(0) as u32
                ));
            }
        }
    }
    let blob = ffx_get_permutation_blob_by_index(
        FfxEffect::Fsr3Upscaler,
        FfxFsr3UpscalerPass::PrepareReactivity as u32,
        FFX_BIND_COMPUTE_SHADER_STAGE,
        0,
    )
    .unwrap();
    let locks = FFX_WGSL_BINDING_OFFSET_UAV
        + blob
            .bound_uav_textures
            .iter()
            .find(|b| b.name == "rw_new_locks")
            .unwrap()
            .binding;
    let mut source = storage::declare(
        ffx_get_upscaler_wgsl_source(
            &blob,
            FfxWgslUpscalerOptions {
                core: true,
                ..Default::default()
            },
        )
        .unwrap(),
    );
    source.push_str(
        "@group(1) @binding(0) var<storage, read> inputs: array<f32>;
         @group(1) @binding(1) var typed: texture_storage_2d<r8unorm, write>;
         @compute @workgroup_size(64) fn store(@builtin(global_invocation_id) id: vec3u) {
             if (id.x < arrayLength(&inputs)) {
                 StoreNewLocks(vec2u(id.x, 0u), inputs[id.x]);
                 textureStore(typed, vec2u(id.x, 0u), vec4f(inputs[id.x]));
             }
         }",
    );
    let load = "@group(0) @binding(0) var typed: texture_2d<f32>;
         @group(0) @binding(1) var loaded: texture_storage_2d<r32float, write>;
         @compute @workgroup_size(64) fn load(@builtin(global_invocation_id) id: vec3u) {
             if (id.x < textureDimensions(typed).x) {
                 textureStore(loaded, vec2u(id.x, 0u), textureLoad(typed, vec2u(id.x, 0u), 0));
             }
         }";
    let width = values.len() as u32;
    let texture = |format| {
        device.create_texture(&wgpu::TextureDescriptor {
            label: None,
            size: wgpu::Extent3d {
                width,
                height: 1,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format,
            usage: wgpu::TextureUsages::STORAGE_BINDING
                | wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        })
    };
    let core = texture(wgpu::TextureFormat::R32Float);
    let typed = texture(wgpu::TextureFormat::R8Unorm);
    let loaded = texture(wgpu::TextureFormat::R32Float);
    let inputs = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: None,
        contents: bytemuck::cast_slice(&values),
        usage: wgpu::BufferUsages::STORAGE,
    });
    let view = |texture: &wgpu::Texture| texture.create_view(&Default::default());
    let (core_view, typed_view, loaded_view) = (view(&core), view(&typed), view(&loaded));
    let pipeline = |source: &str, entry_point| {
        let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: None,
            source: wgpu::ShaderSource::Wgsl(source.into()),
        });
        device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: None,
            layout: None,
            module: &module,
            entry_point: Some(entry_point),
            compilation_options: Default::default(),
            cache: None,
        })
    };
    let group = |pipeline: &wgpu::ComputePipeline, index, entries: &[wgpu::BindGroupEntry]| {
        device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &pipeline.get_bind_group_layout(index),
            entries,
        })
    };
    let texture_entry = |binding, view| wgpu::BindGroupEntry {
        binding,
        resource: wgpu::BindingResource::TextureView(view),
    };
    let store = pipeline(&source, "store");
    let load = pipeline(load, "load");
    let mut encoder = device.create_command_encoder(&Default::default());
    {
        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&store);
        pass.set_bind_group(
            0,
            &group(&store, 0, &[texture_entry(locks, &core_view)]),
            &[],
        );
        pass.set_bind_group(
            1,
            &group(
                &store,
                1,
                &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: inputs.as_entire_binding(),
                    },
                    texture_entry(1, &typed_view),
                ],
            ),
            &[],
        );
        pass.dispatch_workgroups(width.div_ceil(64), 1, 1);
    }
    {
        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&load);
        pass.set_bind_group(
            0,
            &group(
                &load,
                0,
                &[
                    texture_entry(0, &typed_view),
                    texture_entry(1, &loaded_view),
                ],
            ),
            &[],
        );
        pass.dispatch_workgroups(width.div_ceil(64), 1, 1);
    }
    let readbacks = vec![
        readback::Readback::texture(&device, &mut encoder, &core, 0),
        readback::Readback::texture(&device, &mut encoder, &loaded, 0),
    ];
    queue.submit([encoder.finish()]);
    let bytes = readback::Readback::read_all(&device, readbacks);
    let (core, typed): (&[u32], &[u32]) = (
        bytemuck::cast_slice(&bytes[0]),
        bytemuck::cast_slice(&bytes[1]),
    );
    for ((&core, &typed), value) in core.iter().zip(typed).zip(&values) {
        assert_eq!(
            core,
            typed,
            "a store of {value:e} ({:#x}): the core set holds {:e}, the unorm texel returns {:e}",
            value.to_bits(),
            f32::from_bits(core),
            f32::from_bits(typed)
        );
    }
}
