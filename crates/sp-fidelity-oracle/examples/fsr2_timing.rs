//! GPU time of FSR2's passes, not conformance: AMD's DXC-compiled HLSL on
//! Metal against the port's WGSL through wgpu, on the same device and inputs.
//!
//! The port runs SGL3D's configuration (HDR, inverted infinite depth,
//! render-size motion vectors, sharpening, the device's FP16 table) for a few
//! frames of noise colour, a depth gradient and small motion at a 1920x1080
//! display, capturing the last frame's pass inputs; AMD's C++ host produces
//! the same frames' trace. Each timed pass then runs `REPETITIONS` times back
//! to back from those inputs, each in its own compute pass between GPU
//! timestamps: the original MSL in the Metal oracle (`--time`, with textures
//! as wgpu allocates them) and the port through the wgpu backend, alternating
//! by round.
//!
//! `cargo run -p sp-fidelity-oracle --release --example fsr2_timing`, with
//! nothing else using the GPU.
use serde_json::{Value, json};
use sp_fidelity::fsr2::private::FSR2_SHADER_PERMUTATION_ALLOW_FP16;
use sp_fidelity::fsr2::*;
use sp_fidelity::interface::{FfxInterface, FfxInterfaceRef};
use sp_fidelity::types::*;
use sp_fidelity_oracle::gpu::{self, Capture, Input};
use sp_fidelity_oracle::host::{build_cpp_host, root, run_cpp_host};
use sp_fidelity_oracle::{FSR2, pass};
use sp_fidelity_wgpu::readback::Readback;
use sp_fidelity_wgpu::{FfxWgpuBackend, FfxWgpuPassTimestamps, ffx_get_interface_wgpu};
use std::cell::{Cell, RefCell};
use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::path::Path;
use std::process::Command;
use std::rc::Rc;

const DISPLAY: [u32; 2] = [1920, 1080];
const RENDERS: [(&str, [u32; 2]); 2] = [("native", [1920, 1080]), ("quality", [1280, 720])];
const FRAMES: usize = 8;
const ROUNDS: usize = 5;
const REPETITIONS: usize = 100;
/// Leading repetitions of each batch left out while the GPU clocks up.
const WARMUP: usize = 10;
const TIMED: &[&str] = &[
    "fsr2_reconstruct_previous_depth",
    "fsr2_depth_clip",
    "fsr2_lock",
    "fsr2_accumulate_sharpen",
    "fsr2_rcas",
];
/// SGL3D's context flags (`sgl-3d/src/stages/antialiasing/fsr2.rs`).
const FLAGS: u32 = FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE
    | FFX_FSR2_ENABLE_DEPTH_INVERTED
    | FFX_FSR2_ENABLE_DEPTH_INFINITE;

struct Random(u32);

impl Random {
    fn unit(&mut self) -> f32 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 17;
        self.0 ^= self.0 << 5;
        (self.0 >> 8) as f32 / (1u32 << 24) as f32
    }
}

fn image(size: [u32; 2], mut texel: impl FnMut(f32, f32, &mut Random) -> Vec<u8>) -> Vec<u8> {
    let mut random = Random(0x9e37_79b9);
    let mut bytes = Vec::new();
    for y in 0..size[1] {
        for x in 0..size[0] {
            let (u, v) = (x as f32 / size[0] as f32, y as f32 / size[1] as f32);
            bytes.extend(texel(u, v, &mut random));
        }
    }
    bytes
}

/// binary16 of normal `f32`s, rounded half up; tiny values flush to zero.
fn halves(values: &[f32]) -> Vec<u8> {
    let half = |value: f32| {
        let bits = value.to_bits();
        let sign = ((bits >> 16) & 0x8000) as u16;
        let exponent = ((bits >> 23) & 0xff) as i32 - 127 + 15;
        if exponent <= 0 {
            return sign;
        }
        let rounded = (u32::try_from(exponent).unwrap() << 10 | (bits & 0x7f_ffff) >> 13)
            + ((bits >> 12) & 1);
        sign | u16::try_from(rounded.min(0x7c00)).unwrap()
    };
    values.iter().flat_map(|&v| half(v).to_le_bytes()).collect()
}

/// Linear HDR noise over a gradient, with sparse bright texels.
fn colour(size: [u32; 2]) -> Vec<u8> {
    image(size, |u, v, r| {
        let bright = if r.unit() < 0.01 { 16.0 } else { 1.0 };
        let [a, b, c] = [r.unit(), r.unit(), r.unit()];
        halves(&[
            bright * (0.2 + 0.6 * u + 0.3 * a),
            bright * (0.2 + 0.5 * v + 0.3 * b),
            bright * (0.3 + 0.2 * (u + v) + 0.3 * c),
            1.0,
        ])
    })
}

/// Reversed infinite depth (near / distance): a floor from 1 m at the bottom
/// to 200 m at the top, with small noise.
fn depth(size: [u32; 2]) -> Vec<u8> {
    image(size, |_, v, r| {
        let distance = 1.0 + 199.0 * (1.0 - v).powi(3) + 0.01 * r.unit();
        (0.1 / distance).to_le_bytes().to_vec()
    })
}

/// UV motion of about a pixel, and a block moving eight pixels.
fn motion(size: [u32; 2]) -> Vec<u8> {
    let [w, h] = size.map(|s| s as f32);
    image(size, |u, v, r| {
        let pixels = if (0.3..0.5).contains(&u) && (0.4..0.6).contains(&v) {
            [8.0, -3.0]
        } else {
            [1.0 + 0.5 * r.unit(), 0.5 * r.unit() - 0.25]
        };
        halves(&[pixels[0] / w, pixels[1] / h])
    })
}

fn texture(
    device: &wgpu::Device,
    size: [u32; 2],
    format: wgpu::TextureFormat,
    usage: wgpu::TextureUsages,
) -> wgpu::Texture {
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
        format,
        usage: usage
            | wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    })
}

fn device() -> (wgpu::Device, wgpu::Queue) {
    let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::METAL,
        ..wgpu::InstanceDescriptor::new_without_display_handle()
    });
    let adapter = pollster::block_on(instance.request_adapter(&Default::default())).unwrap();
    pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
        required_features: sp_fidelity_wgpu::required_features()
            | wgpu::Features::SHADER_F16
            | wgpu::Features::TIMESTAMP_QUERY,
        required_limits: adapter.limits(),
        ..Default::default()
    }))
    .unwrap()
}

/// The application's textures, named as `oracle/fsr2_host.cpp` names them.
struct Application {
    inputs: Vec<Input>,
    output: wgpu::Texture,
}

impl Application {
    fn new(device: &wgpu::Device, queue: &wgpu::Queue, render: [u32; 2]) -> Self {
        let inputs = [
            (
                "color",
                FfxSurfaceFormat::R16G16B16A16Float,
                DISPLAY,
                colour(render),
            ),
            ("depth", FfxSurfaceFormat::R32Float, DISPLAY, depth(render)),
            (
                "motion-vectors",
                FfxSurfaceFormat::R16G16Float,
                DISPLAY,
                motion(render),
            ),
            (
                "exposure",
                FfxSurfaceFormat::R32Float,
                [1, 1],
                1f32.to_le_bytes().to_vec(),
            ),
        ]
        .map(|(name, format, size, render_bytes)| {
            let wgpu_format = match format {
                FfxSurfaceFormat::R16G16B16A16Float => wgpu::TextureFormat::Rgba16Float,
                FfxSurfaceFormat::R32Float => wgpu::TextureFormat::R32Float,
                _ => wgpu::TextureFormat::Rg16Float,
            };
            let texture = texture(device, size, wgpu_format, wgpu::TextureUsages::empty());
            // The rendered region; the rest of the allocation stays zero.
            let texel =
                render_bytes.len() / (render[0].min(size[0]) * render[1].min(size[1])) as usize;
            let mut bytes = vec![0; (size[0] * size[1]) as usize * texel];
            let row = render[0].min(size[0]) as usize * texel;
            for (y, source) in render_bytes.chunks(row).enumerate() {
                let start = y * size[0] as usize * texel;
                bytes[start..start + row].copy_from_slice(source);
            }
            gpu::upload(queue, &texture, &bytes);
            Input {
                name,
                texture,
                format,
                cube: false,
                bytes,
            }
        });
        let output = texture(
            device,
            DISPLAY,
            wgpu::TextureFormat::Rgba16Float,
            wgpu::TextureUsages::STORAGE_BINDING,
        );
        Self {
            inputs: inputs.into(),
            output,
        }
    }

    fn input(&self, name: &str) -> &wgpu::Texture {
        &self.inputs.iter().find(|i| i.name == name).unwrap().texture
    }
}

/// Frame `index`'s jitter, SGL3D's (and `oracle/fsr2_host.cpp`'s) sequence.
fn jitter(index: usize, render: [u32; 2]) -> [f32; 2] {
    let phases = ffx_fsr2_get_jitter_phase_count(render[0] as i32, DISPLAY[0] as i32);
    let (x, y) = ffx_fsr2_get_jitter_offset(index as i32, phases).unwrap();
    [x, y]
}

/// The word stream of `oracle/fsr2_host.cpp` for the frames.
fn host_words(render: [u32; 2]) -> Vec<u32> {
    let mut words = vec![1, FLAGS, DISPLAY[0], DISPLAY[1], DISPLAY[0], DISPLAY[1]];
    words.extend([DISPLAY[0], DISPLAY[1], FRAMES as u32]);
    for index in 0..FRAMES {
        // Command list, depth, motion vectors, exposure, output; the jitter
        // sequence at the frame's index.
        words.extend([0, 1 | 2 | 4 | 8 | 64, 0, render[0], render[1], 0]);
        words.push(index as u32);
        words.extend([-(render[0] as f32), -(render[1] as f32)].map(f32::to_bits));
        words.extend([1, 0.8f32.to_bits(), 16.6f32.to_bits(), 1f32.to_bits()]);
        words.push(u32::from(index == 0));
        words.extend([f32::MAX, 0.1, 1.0, 1.0].map(f32::to_bits));
        words.extend([0, 0, 0, 0, 0]);
    }
    words
}

/// Run the port for the frames and capture the last one's pass inputs into
/// `directory`; write AMD's trace of the last frame (`timing.jsonl`) and the
/// inputs the Metal oracle loads.
fn case(device: &wgpu::Device, queue: &wgpu::Queue, render: [u32; 2], directory: &Path) {
    let application = Application::new(device, queue, render);
    let (backend, interface): (Rc<RefCell<FfxWgpuBackend>>, FfxInterfaceRef) =
        ffx_get_interface_wgpu(device);
    let capabilities = backend.borrow_mut().get_device_capabilities().unwrap();
    println!("device capabilities {capabilities:?}");

    gpu::write_inputs(directory, &application.inputs, &vec![Vec::new(); FRAMES]);
    let (executable, bindings) = build_cpp_host(&root().join("target/fsr2-timing-host"), &FSR2);
    // The context also creates the luminance pyramid for the FP16 options,
    // which the oracle compiles only for 32-bit ones: the SDK's accessor takes
    // its 32-bit table whatever ALLOW_FP16 says, so the reflection is that
    // variant's. It is not timed.
    let pyramid = stage_pass("fsr2_compute_luminance_pyramid");
    let mut table = fs::read_to_string(&bindings).unwrap();
    let compiled: std::collections::HashSet<(String, String)> = table
        .lines()
        .map(|l| {
            let f: Vec<&str> = l.splitn(3, ' ').collect();
            (f[0].to_owned(), f[1].to_owned())
        })
        .collect();
    for line in table.clone().lines() {
        let fields: Vec<&str> = line.splitn(3, ' ').collect();
        let options = fields[1].parse::<u32>().unwrap() | FSR2_SHADER_PERMUTATION_ALLOW_FP16;
        if fields[0] == pyramid.to_string()
            && !compiled.contains(&(fields[0].to_owned(), options.to_string()))
        {
            table += &format!("{} {options} {}\n", fields[0], fields[2]);
        }
    }
    let bindings = directory.join("shader-bindings.txt");
    fs::write(&bindings, table).unwrap();
    let host = (executable, bindings);
    let trace = run_cpp_host(
        &host,
        &capabilities,
        &host_words(render),
        &directory.join("input.words"),
        &directory.join("inputs"),
    );

    let mut context = FfxFsr2Context::default();
    ffx_fsr2_context_create(
        &mut context,
        &FfxFsr2ContextDescription {
            flags: FLAGS,
            max_render_size: FfxDimensions2D {
                width: DISPLAY[0],
                height: DISPLAY[1],
            },
            display_size: FfxDimensions2D {
                width: DISPLAY[0],
                height: DISPLAY[1],
            },
            fp_message: None,
            backend_interface: interface,
        },
    )
    .unwrap();
    let mut capture = None;
    for index in 0..FRAMES {
        if index == FRAMES - 1 {
            let installed = Capture::install(&mut backend.borrow_mut(), directory, &FSR2);
            installed.set_frame(index);
            capture = Some(installed);
        }
        let [x, y] = jitter(index, render);
        let mut description = FfxFsr2DispatchDescription {
            jitter_offset: FfxFloatCoords2D { x, y },
            motion_vector_scale: FfxFloatCoords2D {
                x: -(render[0] as f32),
                y: -(render[1] as f32),
            },
            render_size: FfxDimensions2D {
                width: render[0],
                height: render[1],
            },
            enable_sharpening: true,
            sharpness: 0.8,
            frame_time_delta: 16.6,
            pre_exposure: 1.0,
            reset: index == 0,
            camera_near: f32::MAX,
            camera_far: 0.1,
            camera_fov_angle_vertical: 1.0,
            view_space_to_meters_factor: 1.0,
            ..Default::default()
        };
        {
            let mut backend = backend.borrow_mut();
            let read = FFX_RESOURCE_STATE_COMPUTE_READ;
            description.command_list = backend
                .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
            description.color =
                backend.ffx_get_resource_wgpu(application.input("color"), "color", read);
            description.depth =
                backend.ffx_get_resource_wgpu(application.input("depth"), "depth", read);
            description.motion_vectors = backend.ffx_get_resource_wgpu(
                application.input("motion-vectors"),
                "motion-vectors",
                read,
            );
            description.exposure =
                backend.ffx_get_resource_wgpu(application.input("exposure"), "exposure", read);
            description.output = backend.ffx_get_resource_wgpu(
                &application.output,
                "output",
                FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            );
        }
        ffx_fsr2_context_dispatch(&mut context, &description).unwrap();
        let encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(description.command_list)
            .unwrap();
        queue.submit([encoder.finish()]);
        if let Some(capture) = &capture {
            capture.save(device);
        }
    }
    ffx_fsr2_context_destroy(&mut context).unwrap();

    // The last frame's compute jobs; its captures replace clears and copies.
    // The output is an application UAV, which the oracle allocates only for
    // effect resources.
    let last = (FRAMES - 1) as u64;
    let mut frame = None;
    let mut events = vec![json!([
        "resource",
        "output",
        FfxResourceType::Texture2D as u32,
        FfxSurfaceFormat::R16G16B16A16Float as u32,
        DISPLAY[0],
        DISPLAY[1],
        1,
        FFX_RESOURCE_USAGE_UAV,
        FfxResourceInitDataType::Uninitialized as u32,
        0,
        0
    ])];
    for line in trace.lines() {
        let event: Value = serde_json::from_str(line).unwrap();
        match event[0].as_str().unwrap() {
            "resource" => events.push(event),
            "pipeline" | "compute" if !TIMED.contains(&FSR2.stages[number(&event[1]) as usize]) => {
            }
            "pipeline" => events.push(event),
            "frame" => {
                frame = event[1].as_u64();
                if frame == Some(last) {
                    events.push(event);
                }
            }
            "compute" if frame == Some(last) => events.push(event),
            "dispatch-result" | "create-result" => assert_eq!(event[1], 0, "{line}"),
            _ => {}
        }
    }
    let lines: Vec<String> = events.iter().map(Value::to_string).collect();
    fs::write(directory.join("timing.jsonl"), lines.join("\n") + "\n").unwrap();
}

fn events(directory: &Path) -> Vec<Value> {
    fs::read_to_string(directory.join("timing.jsonl"))
        .unwrap()
        .lines()
        .map(|l| serde_json::from_str(l).unwrap())
        .collect()
}

fn number(value: &Value) -> u32 {
    u32::try_from(value.as_u64().unwrap()).unwrap()
}

fn stage_pass(stage: &str) -> u32 {
    FSR2.stages.iter().position(|s| *s == stage).unwrap() as u32
}

/// Nanoseconds of each timed stage's repetitions in the Metal oracle.
fn time_metal(directory: &Path, output: &Path) -> BTreeMap<String, Vec<f64>> {
    let _ = fs::remove_dir_all(output);
    let result = Command::new(gpu::metal_oracle())
        .args(["--compiler-mode", "wgpu", "--private-textures", "--time"])
        .arg(REPETITIONS.to_string())
        .arg("--replay")
        .arg(directory.join("wgpu-inputs"))
        .arg(FSR2.shaders())
        .arg(directory.join("timing.jsonl"))
        .arg(directory.join("inputs"))
        .arg(output)
        .output()
        .unwrap();
    assert!(
        result.status.success(),
        "Metal oracle: {}",
        String::from_utf8_lossy(&result.stderr)
    );
    let run: Value = serde_json::from_slice(&fs::read(output.join("run.json")).unwrap()).unwrap();
    let mut times = BTreeMap::new();
    for pass in run["passes"].as_array().unwrap() {
        let stage = pass["stage"].as_str().unwrap();
        if TIMED.contains(&stage) {
            let ns: Vec<f64> = pass["timedNanoseconds"]
                .as_array()
                .unwrap()
                .iter()
                .map(|v| v.as_f64().unwrap())
                .collect();
            times.insert(stage.to_owned(), ns);
        }
    }
    let _ = fs::remove_dir_all(output);
    times
}

fn leak(text: &str) -> &'static str {
    Box::leak(text.to_owned().into_boxed_str())
}

/// Every mip of a captured resource, tightly packed.
fn captured(directory: &Path, stage: &str, name: &str) -> Vec<u8> {
    let inputs = directory
        .join("wgpu-inputs")
        .join(format!("frame-{}", FRAMES - 1))
        .join(stage);
    (0..)
        .map_while(|mip| fs::read(inputs.join(format!("{name}.mip-{mip}.bin"))).ok())
        .flatten()
        .collect()
}

fn surface_format(value: u32) -> FfxSurfaceFormat {
    use FfxSurfaceFormat as F;
    [
        F::R32G32B32A32Float,
        F::R16G16B16A16Float,
        F::R32G32Float,
        F::R32Uint,
        F::R8G8B8A8Unorm,
        F::R11G11B10Float,
        F::R16G16Float,
        F::R16Float,
        F::R16Snorm,
        F::R8Unorm,
        F::R8G8Unorm,
        F::R32Float,
    ]
    .into_iter()
    .find(|f| *f as u32 == value)
    .unwrap_or_else(|| panic!("surface format {value}"))
}

fn sampler(s: &Value) -> FfxSamplerDescription {
    let address = |v: &Value| {
        [
            FfxAddressMode::Wrap,
            FfxAddressMode::Mirror,
            FfxAddressMode::Clamp,
            FfxAddressMode::Border,
            FfxAddressMode::MirrorOnce,
        ][number(v) as usize]
    };
    FfxSamplerDescription {
        filter: [
            FfxFilterType::MinMagMipPoint,
            FfxFilterType::MinMagMipLinear,
            FfxFilterType::MinMagLinearMipPoint,
        ][number(&s[0]) as usize],
        address_mode_u: address(&s[1]),
        address_mode_v: address(&s[2]),
        address_mode_w: address(&s[3]),
        stage: number(&s[4]),
    }
}

/// Nanoseconds of `stage`'s repetitions through the wgpu backend, as the
/// SDK host records it: the pipeline for the trace's options and samplers,
/// the effect's resources from their SDK descriptions, the application's
/// registered, and the captured inputs written before the first job.
#[allow(clippy::too_many_lines)]
fn time_wgpu(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    directory: &Path,
    application: &Application,
    stage: &str,
) -> Vec<f64> {
    let events = events(directory);
    let pass_id = stage_pass(stage);
    let pipeline = events
        .iter()
        .find(|e| e[0] == "pipeline" && number(&e[1]) == pass_id)
        .unwrap();
    let job = events
        .iter()
        .find(|e| e[0] == "compute" && number(&e[1]) == pass_id)
        .unwrap();
    let (backend, _) = ffx_get_interface_wgpu(device);
    let mut backend = backend.borrow_mut();
    let context = backend
        .create_backend_context(FfxEffect::Fsr2, None)
        .unwrap();
    let samplers: Vec<_> = pipeline[5]
        .as_array()
        .unwrap()
        .iter()
        .map(sampler)
        .collect();
    let roots: Vec<_> = pipeline[4]
        .as_array()
        .unwrap()
        .iter()
        .map(|size| FfxRootConstantDescription {
            size: number(size),
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        })
        .collect();
    let state = backend
        .create_pipeline(
            FfxEffect::Fsr2,
            pass_id,
            number(&pipeline[2]),
            &FfxPipelineDescription {
                context_flags: number(&pipeline[7]),
                samplers: &samplers,
                root_constants: &roots,
                name: stage.into(),
                stage: FFX_BIND_COMPUTE_SHADER_STAGE,
                indirect_workload: 0,
                backbuffer_format: FfxSurfaceFormat::Unknown,
            },
            context,
        )
        .unwrap();

    let mut internal: HashMap<String, FfxResourceInternal> = HashMap::new();
    let mut contents: HashMap<&'static str, Vec<u8>> = HashMap::new();
    for binding in job[5].as_array().unwrap() {
        let name = binding[2].as_str().unwrap();
        if internal.contains_key(name) {
            continue;
        }
        let created = events
            .iter()
            .find(|e| e[0] == "resource" && e[1] == name && name != "output");
        let resource = if let Some(r) = created {
            let description = FfxResourceDescription {
                r#type: FfxResourceType::Texture2D,
                format: surface_format(number(&r[3])),
                width: number(&r[4]),
                height: number(&r[5]),
                depth: 1,
                mip_count: number(&r[6]),
                flags: FFX_RESOURCE_FLAGS_NONE,
                usage: number(&r[7]),
            };
            contents.insert(leak(name), captured(directory, stage, name));
            backend
                .create_resource(
                    &FfxCreateResourceDescription {
                        heap_type: FfxHeapType::Default,
                        resource_description: description,
                        initial_state: number(&r[12]),
                        name: leak(name),
                        id: 0,
                        init_data: FfxResourceInitData {
                            r#type: FfxResourceInitDataType::Uninitialized,
                            ..Default::default()
                        },
                    },
                    context,
                )
                .unwrap()
        } else {
            let texture = if name == "output" {
                &application.output
            } else {
                application.input(name)
            };
            contents.insert(leak(name), captured(directory, stage, name));
            let resource =
                backend.ffx_get_resource_wgpu(texture, name, FFX_RESOURCE_STATE_COMPUTE_READ);
            backend.register_resource(&resource, context).unwrap()
        };
        internal.insert(name.to_owned(), resource);
    }
    let bound = |uav: bool, binding_name: &str| {
        let b = job[5]
            .as_array()
            .unwrap()
            .iter()
            .find(|b| b[0] == if uav { "uav" } else { "srv" } && b[1] == binding_name)
            .unwrap_or_else(|| panic!("{stage} binds no {binding_name}"));
        (internal[b[2].as_str().unwrap()], number(&b[3]))
    };
    let constants = |name: &str| {
        job[6]
            .as_array()
            .unwrap()
            .iter()
            .find(|c| c[0] == name)
            .unwrap()[1]
            .as_array()
            .unwrap()
            .iter()
            .map(number)
            .collect::<Vec<_>>()
    };
    let compute = FfxComputeJobDescription {
        pipeline: state.clone(),
        dimensions: [0, 1, 2].map(|i| number(&job[2][i])),
        srv_textures: state
            .srv_texture_bindings
            .iter()
            .map(|b| FfxTextureSRV {
                resource: bound(false, &b.name).0,
            })
            .collect(),
        uav_textures: state
            .uav_texture_bindings
            .iter()
            .map(|b| {
                let (resource, mip) = bound(true, &b.name);
                FfxTextureUAV { mip, resource }
            })
            .collect(),
        cbs: state
            .constant_buffer_bindings
            .iter()
            .map(|b| {
                let data = constants(&b.name);
                FfxConstantBuffer {
                    num_32bit_entries: data.len() as u32,
                    data,
                }
            })
            .collect(),
        ..Default::default()
    };

    let written = Cell::new(false);
    backend.set_job_observer(Some(Box::new(move |observation| {
        if !observation.after && !written.replace(true) {
            pass::write_contents(observation, &contents);
        }
    })));
    let count = REPETITIONS as u32;
    let query_set = device.create_query_set(&wgpu::QuerySetDescriptor {
        label: None,
        ty: wgpu::QueryType::Timestamp,
        count: 2 * count,
    });
    backend.set_pass_timestamps(Some(FfxWgpuPassTimestamps {
        query_set: query_set.clone(),
        first: 0,
        count,
        used: Cell::new(0),
    }));
    let command_list =
        backend.ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
    for _ in 0..REPETITIONS {
        backend
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: stage.into(),
                descriptor: FfxGpuJobDescriptor::Compute(Box::new(compute.clone())),
            })
            .unwrap();
    }
    backend.execute_gpu_jobs(command_list, context).unwrap();
    assert_eq!(backend.set_pass_timestamps(None).unwrap().used.get(), count);
    backend.unregister_resources(command_list, context).unwrap();
    let mut encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
    let resolved = device.create_buffer(&wgpu::BufferDescriptor {
        label: None,
        size: u64::from(2 * count) * 8,
        usage: wgpu::BufferUsages::QUERY_RESOLVE | wgpu::BufferUsages::COPY_SRC,
        mapped_at_creation: false,
    });
    encoder.resolve_query_set(&query_set, 0..2 * count, &resolved, 0);
    let readback = Readback::buffer(device, &mut encoder, &resolved);
    queue.submit([encoder.finish()]);
    let bytes = Readback::read_all(device, vec![readback]).remove(0);
    let stamps: Vec<u64> = bytes
        .chunks_exact(8)
        .map(|c| u64::from_le_bytes(c.try_into().unwrap()))
        .collect();
    let period = f64::from(queue.get_timestamp_period());
    backend.destroy_backend_context(context).unwrap();
    stamps
        .chunks_exact(2)
        .map(|p| (p[1] - p[0]) as f64 * period)
        .collect()
}

fn median(values: &mut [f64]) -> f64 {
    values.sort_by(f64::total_cmp);
    values[values.len() / 2]
}

fn main() {
    let (device, queue) = device();
    let mut table = Vec::new();
    for (label, render) in RENDERS {
        let directory = gpu::case_directory(&format!("fsr2-timing-{label}"));
        case(&device, &queue, render, &directory);
        let application = Application::new(&device, &queue, render);
        let mut samples: BTreeMap<(&str, String), Vec<f64>> = BTreeMap::new();
        let variants = ["amd-msl", "wgpu"];
        for round in 0..ROUNDS {
            for v in 0..variants.len() {
                let variant = variants[(v + round) % variants.len()];
                let times = match variant {
                    "amd-msl" => time_metal(&directory, &directory.join("metal-timing")),
                    _ => TIMED
                        .iter()
                        .map(|stage| {
                            (
                                (*stage).to_owned(),
                                time_wgpu(&device, &queue, &directory, &application, stage),
                            )
                        })
                        .collect(),
                };
                for (stage, ns) in times {
                    samples
                        .entry((variant, stage))
                        .or_default()
                        .extend(&ns[WARMUP..]);
                }
            }
        }
        for stage in TIMED {
            let mut row = format!("{label:8} {stage:34}");
            for variant in variants {
                let ms = median(samples.get_mut(&(variant, (*stage).to_owned())).unwrap()) / 1e6;
                row += &format!(" {variant} {ms:7.3}");
            }
            table.push(row);
        }
        println!("{}", directory.display());
    }
    println!(
        "median ms over {ROUNDS} rounds of {} repetitions",
        REPETITIONS - WARMUP
    );
    for row in table {
        println!("{row}");
    }
}
