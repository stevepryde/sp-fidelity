//! GPU time of each FSR2 and FSR3 upscaler pass, and each context's GPU
//! memory, on both resource sets: the SDK's on a device with
//! `required_features()`, and the core set on one with
//! `core_required_features()` alone, as a browser's has.
//!
//! ```sh
//! cargo run -p sp-fidelity-wgpu --release --example upscaler_timing [-- WIDTHxHEIGHT]
//! ```
//!
//! Each line gives a context at that display size (and maximum render size)
//! at Native AA or Quality: the median of each compute job's timestamp pair
//! over the measured frames, which spans both of a split SPD's dispatches;
//! the core set's two transfer passes around the depth atomics are not timed.
//! Needs `TIMESTAMP_QUERY`. A measurement, not a test: run it on a quiet
//! machine.
#![cfg_attr(target_arch = "wasm32", allow(unused))]
use sp_fidelity::fsr2::*;
use sp_fidelity::fsr3upscaler::*;
use sp_fidelity::types::*;
use sp_fidelity_wgpu::readback::Readback;
use sp_fidelity_wgpu::{
    FfxWgpuPassTimestamps, core_required_features, ffx_get_interface_wgpu, optional_features,
    required_features,
};
use std::cell::{Cell, RefCell};
use std::rc::Rc;
use wgpu::util::DeviceExt;

/// Timestamp pairs a frame may use, and frames run and discarded.
const PAIRS: u32 = 32;
const FRAMES: i32 = 48;
const WARM_UP: i32 = 8;

/// A deterministic value in [0, 1).
fn noise(x: u32, y: u32, seed: u32) -> f32 {
    let mut v = x
        .wrapping_mul(0x9e37_79b1)
        .wrapping_add(y.wrapping_mul(0x85eb_ca77))
        .wrapping_add(seed.wrapping_mul(0xc2b2_ae3d));
    v ^= v >> 15;
    v = v.wrapping_mul(0x2c1b_3c6d);
    v ^= v >> 12;
    (v >> 8) as f32 / (1 << 24) as f32
}

fn dimensions(size: [u32; 2]) -> FfxDimensions2D {
    FfxDimensions2D {
        width: size[0],
        height: size[1],
    }
}

#[cfg(target_arch = "wasm32")]
fn main() {}

#[cfg(not(target_arch = "wasm32"))]
fn main() {
    let display = std::env::args().nth(1).map_or([1920, 1080], |size| {
        let (width, height) = size.split_once('x').expect("WIDTHxHEIGHT");
        [width.parse().unwrap(), height.parse().unwrap()]
    });
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor::new_without_display_handle());
    let adapter = pollster::block_on(instance.request_adapter(&Default::default())).unwrap();
    println!(
        "{:?}, {}x{}",
        adapter.get_info().name,
        display[0],
        display[1]
    );
    for (set, features) in [
        ("SDK set ", required_features()),
        ("core set", core_required_features()),
    ] {
        let features = features | (adapter.features() & optional_features());
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
            required_features: features | wgpu::Features::TIMESTAMP_QUERY,
            required_limits: adapter.limits(),
            ..Default::default()
        }))
        .expect("the adapter lacks this set's features or TIMESTAMP_QUERY");
        // AMD's Quality ratio, 1.5.
        let quality = display.map(|side| (side as f32 / 1.5) as u32);
        for (render, label) in [(display, "Native AA"), (quality, "Quality  ")] {
            for fsr3 in [false, true] {
                let line = measure(&device, &queue, display, render, fsr3);
                println!(
                    "{set} {} {label} {line}",
                    if fsr3 { "FSR3" } else { "FSR2" }
                );
            }
        }
    }
}

/// One context's memory and the median GPU time of each of its jobs.
#[cfg(not(target_arch = "wasm32"))]
fn measure(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    display: [u32; 2],
    render: [u32; 2],
    fsr3: bool,
) -> String {
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
    let floats = |f: &dyn Fn(u32, u32) -> Vec<f32>| -> Vec<f32> {
        (0..render[1])
            .flat_map(|y| (0..render[0]).flat_map(move |x| f(x, y)))
            .collect()
    };
    let bytes = |seed: u32| -> Vec<u8> {
        (0..render[1])
            .flat_map(|y| {
                (0..render[0]).map(move |x| (200. * noise(x / 3, y / 3, seed).powi(4)) as u8)
            })
            .collect()
    };
    // A noisy HDR frame with depth edges and small motion.
    let color = texture(
        wgpu::TextureFormat::Rgba16Float,
        render,
        &floats(&|x, y| {
            let v = 0.02 + 6. * noise(x / 3, y / 3, 1).powi(3);
            vec![v, v * 0.7, v * noise(x, y, 2), 1.]
        })
        .iter()
        .flat_map(|v| half(*v).to_le_bytes())
        .collect::<Vec<u8>>(),
    );
    let depth = texture(
        wgpu::TextureFormat::R32Float,
        render,
        bytemuck::cast_slice(&floats(&|x, y| vec![0.002 + 0.3 * noise(x / 9, y / 9, 3)])),
    );
    let motion = texture(
        wgpu::TextureFormat::Rg32Float,
        render,
        bytemuck::cast_slice(&floats(&|x, y| {
            vec![
                0.004 * (noise(x / 9, y / 9, 4) - 0.5),
                0.004 * (noise(x / 9, y / 9, 5) - 0.5),
            ]
        })),
    );
    let reactive = texture(wgpu::TextureFormat::R8Unorm, render, &bytes(6));
    let composition = texture(wgpu::TextureFormat::R8Unorm, render, &bytes(7));
    let exposure = texture(
        wgpu::TextureFormat::R32Float,
        [1, 1],
        bytemuck::cast_slice(&[0.6f32]),
    );
    let output = device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width: display[0],
            height: display[1],
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba16Float,
        usage: wgpu::TextureUsages::STORAGE_BINDING,
        view_formats: &[],
    });

    let (backend, interface) = ffx_get_interface_wgpu(device);
    let labels: Rc<RefCell<Vec<String>>> = Rc::default();
    let observed = labels.clone();
    backend
        .borrow_mut()
        .set_job_observer(Some(Box::new(move |observation| {
            if !observation.after
                && matches!(observation.job.descriptor, FfxGpuJobDescriptor::Compute(_))
            {
                observed
                    .borrow_mut()
                    .push(observation.job.job_label.clone());
            }
        })));
    let mut fsr2_context = FfxFsr2Context::default();
    let mut fsr3_context = FfxFsr3UpscalerContext::default();
    let mut shared = Vec::new();
    let memory = if fsr3 {
        ffx_fsr3_upscaler_context_create(
            &mut fsr3_context,
            &FfxFsr3UpscalerContextDescription {
                flags: FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE
                    | FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED
                    | FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE,
                max_render_size: dimensions(display),
                max_upscale_size: dimensions(display),
                fp_message: None,
                backend_interface: interface,
            },
        )
        .unwrap();
        let descriptions =
            ffx_fsr3_upscaler_get_shared_resource_descriptions(&fsr3_context).unwrap();
        for description in [
            descriptions.dilated_depth,
            descriptions.dilated_motion_vectors,
            descriptions.reconstructed_prev_nearest_depth,
        ] {
            let texture = backend
                .borrow()
                .ffx_create_texture_wgpu(FfxEffect::Fsr3Upscaler, &description)
                .unwrap();
            shared.push((texture, description));
        }
        ffx_fsr3_upscaler_context_get_gpu_memory_usage(&mut fsr3_context)
    } else {
        ffx_fsr2_context_create(
            &mut fsr2_context,
            &FfxFsr2ContextDescription {
                flags: FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE
                    | FFX_FSR2_ENABLE_DEPTH_INVERTED
                    | FFX_FSR2_ENABLE_DEPTH_INFINITE,
                max_render_size: dimensions(display),
                display_size: dimensions(display),
                fp_message: None,
                backend_interface: interface,
            },
        )
        .unwrap();
        ffx_fsr2_context_get_gpu_memory_usage(&mut fsr2_context)
    }
    .unwrap()
    .total_usage_in_bytes;

    let query_set = device.create_query_set(&wgpu::QuerySetDescriptor {
        label: None,
        ty: wgpu::QueryType::Timestamp,
        count: PAIRS * 2,
    });
    let resolved = device.create_buffer(&wgpu::BufferDescriptor {
        label: None,
        size: u64::from(PAIRS) * 16,
        usage: wgpu::BufferUsages::QUERY_RESOLVE | wgpu::BufferUsages::COPY_SRC,
        mapped_at_creation: false,
    });
    let period_ms = f64::from(queue.get_timestamp_period()) * 1e-6;
    let mut samples: Vec<Vec<f64>> = Vec::new();
    for frame in 0..FRAMES {
        labels.borrow_mut().clear();
        backend
            .borrow_mut()
            .set_pass_timestamps(Some(FfxWgpuPassTimestamps {
                query_set: query_set.clone(),
                first: 0,
                count: PAIRS,
                used: Cell::new(0),
            }));
        let command_list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        let read = FFX_RESOURCE_STATE_COMPUTE_READ;
        let write = FFX_RESOURCE_STATE_UNORDERED_ACCESS;
        let resource = |texture: &wgpu::Texture, name: &str, state| {
            backend
                .borrow_mut()
                .ffx_get_resource_wgpu(texture, name, state)
        };
        let motion_vector_scale = FfxFloatCoords2D {
            x: render[0] as f32,
            y: render[1] as f32,
        };
        if fsr3 {
            let phases =
                ffx_fsr3_upscaler_get_jitter_phase_count(render[0] as i32, display[0] as i32);
            let (x, y) = ffx_fsr3_upscaler_get_jitter_offset(frame, phases).unwrap();
            let register = |index: usize| {
                let (texture, description): &(wgpu::Texture, FfxCreateResourceDescription) =
                    &shared[index];
                backend.borrow_mut().ffx_get_described_resource_wgpu(
                    texture,
                    description.resource_description,
                    description.name,
                    write,
                )
            };
            ffx_fsr3_upscaler_context_dispatch(
                &mut fsr3_context,
                &FfxFsr3UpscalerDispatchDescription {
                    command_list,
                    color: resource(&color, "color", read),
                    depth: resource(&depth, "depth", read),
                    motion_vectors: resource(&motion, "motion", read),
                    exposure: resource(&exposure, "exposure", read),
                    reactive: resource(&reactive, "reactive", read),
                    transparency_and_composition: resource(&composition, "composition", read),
                    dilated_depth: register(0),
                    dilated_motion_vectors: register(1),
                    reconstructed_prev_nearest_depth: register(2),
                    output: resource(&output, "output", write),
                    jitter_offset: FfxFloatCoords2D { x, y },
                    motion_vector_scale,
                    render_size: dimensions(render),
                    upscale_size: dimensions(display),
                    frame_time_delta: 16.6,
                    pre_exposure: 1.,
                    reset: frame == 0,
                    camera_near: f32::MAX,
                    camera_far: 0.1,
                    camera_fov_angle_vertical: 1.,
                    view_space_to_meters_factor: 1.,
                    ..Default::default()
                },
            )
            .unwrap();
        } else {
            let phases = ffx_fsr2_get_jitter_phase_count(render[0] as i32, display[0] as i32);
            let (x, y) = ffx_fsr2_get_jitter_offset(frame, phases).unwrap();
            ffx_fsr2_context_dispatch(
                &mut fsr2_context,
                &FfxFsr2DispatchDescription {
                    command_list,
                    color: resource(&color, "color", read),
                    depth: resource(&depth, "depth", read),
                    motion_vectors: resource(&motion, "motion", read),
                    exposure: resource(&exposure, "exposure", read),
                    reactive: resource(&reactive, "reactive", read),
                    transparency_and_composition: resource(&composition, "composition", read),
                    output: resource(&output, "output", write),
                    jitter_offset: FfxFloatCoords2D { x, y },
                    motion_vector_scale,
                    render_size: dimensions(render),
                    frame_time_delta: 16.6,
                    pre_exposure: 1.,
                    reset: frame == 0,
                    camera_near: f32::MAX,
                    camera_far: 0.1,
                    camera_fov_angle_vertical: 1.,
                    view_space_to_meters_factor: 1.,
                    ..Default::default()
                },
            )
            .unwrap();
        }
        let used = backend
            .borrow_mut()
            .set_pass_timestamps(None)
            .unwrap()
            .used
            .get();
        let mut encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        assert_eq!(backend.borrow_mut().take_job_error(), None);
        encoder.resolve_query_set(&query_set, 0..used * 2, &resolved, 0);
        let readback = Readback::buffer(device, &mut encoder, &resolved);
        queue.submit([encoder.finish()]);
        let read = Readback::read_all(device, vec![readback]).remove(0);
        let ticks: &[u64] = bytemuck::cast_slice(&read[..used as usize * 16]);
        if frame >= WARM_UP {
            samples.push(
                ticks
                    .chunks(2)
                    .map(|pair| pair[1].saturating_sub(pair[0]) as f64 * period_ms)
                    .collect(),
            );
        }
    }
    if fsr3 {
        ffx_fsr3_upscaler_context_destroy(&mut fsr3_context).unwrap();
    } else {
        ffx_fsr2_context_destroy(&mut fsr2_context).unwrap();
    }
    let median = |job: usize| {
        let mut times: Vec<f64> = samples.iter().map(|frame| frame[job]).collect();
        times.sort_by(f64::total_cmp);
        times[times.len() / 2]
    };
    let jobs = samples[0].len();
    let labels = labels.borrow();
    let each: Vec<String> = (0..jobs)
        .map(|job| format!("{} {:.3}", labels[job], median(job)))
        .collect();
    format!(
        "{:6.1} MB, {:.3} ms: {}",
        memory as f64 / 1_048_576.,
        (0..jobs).map(median).sum::<f64>(),
        each.join(", ")
    )
}

/// The nearest binary16 at or below `value`'s magnitude, for inputs in range.
#[cfg(not(target_arch = "wasm32"))]
fn half(value: f32) -> u16 {
    let bits = value.to_bits();
    let exponent = ((bits >> 23) & 0xff) as i32 - 127;
    if value == 0. || exponent < -14 {
        return 0;
    }
    ((bits >> 16) & 0x8000) as u16
        | (((exponent + 15).min(30) as u16) << 10)
        | ((bits >> 13) & 0x3ff) as u16
}
