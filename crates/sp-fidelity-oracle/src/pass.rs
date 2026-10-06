//! One pass of an effect, before its host is ported: the port's WGSL for a
//! blob runs through wgpu, and the same jobs, inputs and constant buffers run
//! through the DXC-compiled unchanged HLSL on Metal.
//!
//! [`run`] writes a case directory in the layout of the full-effect replay
//! ([`crate::gpu`]): `inputs/` (application resources), `cpp.jsonl` with the
//! `resource`, `pipeline`, `frame` and `compute` events AMD's C++ host prints
//! for these jobs, and the WGSL pass's inputs (`wgpu-inputs/`) and outputs
//! (`wgpu/`) as [`crate::gpu::Capture`] writes them. [`crate::gpu::replay`] and
//! [`crate::compare::compare`] then run unchanged; when the effect's host is
//! ported, its captured trace replaces the synthetic one.
//!
//! WGSL bindings come from the DXC reflection of the variant compiled for the
//! pass and options (as the port's blob tables do): register class and number
//! at the `sp_fidelity::shaders` binding offsets.
//!
//! Resources persist from job to job, so a job reads what earlier jobs wrote
//! unless it supplies new contents. [`crate::gpu::replay`] gives the Metal
//! oracle the port's inputs of every job (its captured state included);
//! [`crate::gpu::run_sequence`] runs the trace from the case's inputs alone, so
//! each side carries its own outputs from job to job. For the latter, only
//! application resources may be supplied after the first job that binds a
//! resource: a created resource is initialized with the contents that job
//! supplies (`FFX_RESOURCE_INIT_DATA_TYPE_BUFFER`) and then holds what the
//! jobs write, and an application resource's later contents are per-frame
//! input updates.
//!
//! [`run_backend`] writes the same case but runs the WGSL as the SDK host
//! would, through `sp-fidelity-wgpu`: its pipeline from the blob
//! accessor, the effect's resources from their SDK descriptions (with the
//! backend's allocations, e.g. a texture a pipeline binds as a buffer), and
//! its captures ([`crate::gpu::Capture`]).
use crate::gpu::{Capture, Gpu, Input, upload, write_inputs};
use crate::host::Effect;
use serde_json::{Value, json};
use sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index;
use sp_fidelity::interface::{FfxInterface, FfxPass};
use sp_fidelity::shaders::*;
use sp_fidelity::types::*;
use sp_fidelity_wgpu::readback::Readback;
use sp_fidelity_wgpu::{FfxWgpuJobObservation, FfxWgpuObject, ffx_get_interface_wgpu};
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;
use std::rc::Rc;
use wgpu::util::DeviceExt;

/// A texture a job binds.
pub struct Resource {
    /// The name the host creates or registers it with.
    pub name: &'static str,
    pub format: FfxSurfaceFormat,
    pub width: u32,
    pub height: u32,
    pub mips: u32,
    /// `None` for an application resource (`inputs/inputs.json`); the
    /// `FfxResourceUsage` of one the effect creates (a `resource` event).
    pub created: Option<FfxResourceUsage>,
}

/// One resource binding of a job: the shader's binding name and the bound
/// resource (a UAV at `mip`).
pub struct Binding {
    pub uav: bool,
    pub name: &'static str,
    pub resource: &'static str,
    pub mip: u32,
}

/// One dispatch, in a frame of its own: its bindings, the constant buffers
/// the host staged for it (by constant-buffer name), the contents uploaded
/// before it (all mips, tightly packed; the first job supplies every
/// application resource, and a resource no job has supplied starts zeroed)
/// and its group counts.
pub struct Job {
    pub bindings: Vec<Binding>,
    pub constants: Vec<(&'static str, Vec<u32>)>,
    pub contents: HashMap<&'static str, Vec<u8>>,
    pub dimensions: [u32; 3],
}

/// The pipeline: the pass, the permutation options the host passes to
/// `fpCreatePipeline`, the blob the port's accessor selects for them, and the
/// pipeline description's root-constant sizes and samplers.
pub struct Pipeline {
    pub pass: FfxPass,
    pub options: u32,
    pub blob: FfxShaderBlob,
    pub root_constants: Vec<u32>,
    pub samplers: Vec<FfxSamplerDescription>,
}

/// The contents the first job that binds `name` supplies: a created
/// resource's initialization data, an application resource's first input.
fn initial<'a>(jobs: &'a [Job], name: &str) -> Option<&'a Vec<u8>> {
    jobs.iter()
        .find(|j| j.bindings.iter().any(|b| b.resource == name))
        .and_then(|j| j.contents.get(name))
}

/// An application resource's input: the contents the first job binding it
/// supplies.
fn application_bytes(jobs: &[Job], name: &str) -> Vec<u8> {
    initial(jobs, name)
        .unwrap_or_else(|| panic!("the first job binding {name} supplies no contents"))
        .clone()
}

/// Write `cpp.jsonl`: the `resource`, `pipeline`, `frame` and `compute`
/// events AMD's C++ host prints for these jobs. A created resource is
/// initialized with what the first job binding it supplies.
fn write_trace(directory: &Path, resources: &[Resource], pipeline: &Pipeline, jobs: &[Job]) {
    let initial = |name: &str| initial(jobs, name);
    let mut trace = Vec::new();
    for r in resources.iter().filter(|r| r.created.is_some()) {
        let (init, size) = initial(r.name)
            .map_or((FfxResourceInitDataType::Uninitialized, 0), |b| {
                (FfxResourceInitDataType::Buffer, b.len())
            });
        trace.push(json!([
            "resource",
            r.name,
            FfxResourceType::Texture2D as u32,
            r.format as u32,
            r.width,
            r.height,
            r.mips,
            r.created,
            init as u32,
            size,
            0
        ]));
    }
    let samplers: Vec<_> = pipeline
        .samplers
        .iter()
        .map(|s| {
            json!([
                s.filter as u32,
                s.address_mode_u as u32,
                s.address_mode_v as u32,
                s.address_mode_w as u32
            ])
        })
        .collect();
    trace.push(json!([
        "pipeline",
        pipeline.pass,
        pipeline.options,
        0,
        pipeline.root_constants,
        samplers
    ]));
    for (frame, job) in jobs.iter().enumerate() {
        trace.push(json!(["frame", frame]));
        let bindings: Vec<_> = job
            .bindings
            .iter()
            .map(|b| json!([if b.uav { "uav" } else { "srv" }, b.name, b.resource, b.mip]))
            .collect();
        let constants: Vec<_> = job
            .constants
            .iter()
            .map(|(name, words)| json!([name, words]))
            .collect();
        trace.push(json!([
            "compute",
            pipeline.pass,
            job.dimensions,
            "NULL",
            0,
            bindings,
            constants
        ]));
        trace.push(json!(["dispatch-result", 0]));
    }
    let lines: Vec<String> = trace.iter().map(Value::to_string).collect();
    fs::write(directory.join("cpp.jsonl"), lines.join("\n") + "\n").unwrap();
}

/// Write `inputs/`: the application inputs (`applications`, with the bytes
/// the first job binding each supplies), the contents later jobs supply as
/// that frame's input updates, and the created resources' initialization
/// data.
fn write_case_inputs(
    directory: &Path,
    resources: &[Resource],
    jobs: &[Job],
    applications: &[Input],
) {
    // Application resources a later job supplies are that frame's input updates.
    let updates: Vec<Vec<(&str, Vec<u8>)>> = jobs
        .iter()
        .enumerate()
        .map(|(frame, job)| {
            resources
                .iter()
                .filter(|r| r.created.is_none())
                .filter(|r| {
                    let first = jobs
                        .iter()
                        .position(|j| j.bindings.iter().any(|b| b.resource == r.name));
                    first.is_some_and(|first| frame > first)
                })
                .filter_map(|r| job.contents.get(r.name).map(|b| (r.name, b.clone())))
                .collect()
        })
        .collect();
    write_inputs(directory, applications, &updates);
    for r in resources.iter().filter(|r| r.created.is_some()) {
        if let Some(bytes) = initial(jobs, r.name) {
            fs::write(
                directory.join("inputs").join(format!("{}.bin", r.name)),
                bytes,
            )
            .unwrap();
        }
    }
}

/// Run `jobs` (frame `i` is job `i`) through the port's WGSL and write the
/// case into `directory`; replay and compare it with [`crate::gpu::replay`]
/// and [`crate::compare::compare`].
#[allow(clippy::too_many_lines)] // Trace, wgpu objects and captures of one case.
pub fn run(
    gpu: &Gpu,
    effect: &Effect,
    directory: &Path,
    resources: &[Resource],
    pipeline: &Pipeline,
    jobs: &[Job],
) {
    let stage = effect.stages[pipeline.pass as usize];
    let device = &gpu.device;
    let reflection: Value = serde_json::from_slice(
        &fs::read(
            effect
                .shaders()
                .join(format!("options-{:#04x}", pipeline.options))
                .join(format!("{stage}.reflection.json")),
        )
        .expect("a variant compiled for the pass and options"),
    )
    .unwrap();

    write_trace(directory, resources, pipeline, jobs);

    // The port's WGSL for the blob, with the layout its bindings derive.
    let source = ffx_get_wgsl_source(&pipeline.blob).expect("a ported pass");
    fs::write(directory.join(format!("{stage}.wgsl")), &source).unwrap();
    let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some(stage),
        source: wgpu::ShaderSource::Wgsl(source.into()),
    });
    let compute = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some(stage),
        layout: None,
        module: &module,
        entry_point: Some(FFX_WGSL_ENTRY_POINT),
        compilation_options: wgpu::PipelineCompilationOptions::default(),
        cache: None,
    });
    let layout = compute.get_bind_group_layout(0);
    let samplers: Vec<wgpu::Sampler> = pipeline
        .samplers
        .iter()
        .map(|s| device.create_sampler(&sampler(s)))
        .collect();

    let textures: HashMap<&str, wgpu::Texture> = resources
        .iter()
        .map(|r| {
            let written = jobs
                .iter()
                .flat_map(|j| &j.bindings)
                .any(|b| b.uav && b.resource == r.name);
            let texture = device.create_texture(&wgpu::TextureDescriptor {
                label: Some(r.name),
                size: wgpu::Extent3d {
                    width: r.width,
                    height: r.height,
                    depth_or_array_layers: 1,
                },
                mip_level_count: r.mips,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: texture_format(r.format),
                usage: wgpu::TextureUsages::TEXTURE_BINDING
                    | wgpu::TextureUsages::COPY_SRC
                    | wgpu::TextureUsages::COPY_DST
                    | if written {
                        wgpu::TextureUsages::STORAGE_BINDING
                    } else {
                        wgpu::TextureUsages::empty()
                    },
                view_formats: &[],
            });
            (r.name, texture)
        })
        .collect();
    let applications: Vec<Input> = resources
        .iter()
        .filter(|r| r.created.is_none())
        .map(|r| Input {
            name: r.name,
            texture: textures[r.name].clone(),
            format: r.format,
            cube: false,
            bytes: application_bytes(jobs, r.name),
        })
        .collect();
    write_case_inputs(directory, resources, jobs, &applications);

    for (frame, job) in jobs.iter().enumerate() {
        let frame_directory = |side: &str| {
            directory
                .join(side)
                .join(format!("frame-{frame}"))
                .join(stage)
        };
        // The job's inputs: the contents it supplies over what earlier jobs
        // left, captured for every bound resource, all mips.
        for (name, bytes) in &job.contents {
            upload(&gpu.queue, &textures[name], bytes);
        }
        let mut encoder = device.create_command_encoder(&Default::default());
        let inputs = frame_directory("wgpu-inputs");
        let mut pending = Vec::new();
        let mut captured = HashSet::new();
        for binding in job.bindings.iter().filter(|b| captured.insert(b.resource)) {
            let texture = &textures[binding.resource];
            for mip in 0..texture.mip_level_count() {
                pending.push((
                    inputs.join(format!("{}.mip-{mip}.bin", binding.resource)),
                    Readback::texture(device, &mut encoder, texture, mip),
                ));
            }
        }

        let mut views = Vec::new();
        let mut buffers = Vec::new();
        for reflected in reflection["resources"].as_array().unwrap() {
            let name = reflected["name"].as_str().unwrap();
            let register = u32::try_from(reflected["register"].as_u64().unwrap()).unwrap();
            match reflected["registerClass"].as_str().unwrap() {
                "b" => {
                    let size = usize::try_from(reflected["byteSize"].as_u64().unwrap()).unwrap();
                    let words = &job.constants.iter().find(|(n, _)| *n == name).unwrap().1;
                    let mut bytes: Vec<u8> = words.iter().flat_map(|w| w.to_le_bytes()).collect();
                    assert!(bytes.len() <= size, "{name} exceeds its constant buffer");
                    bytes.resize(size, 0);
                    let buffer = device.create_buffer(&wgpu::BufferDescriptor {
                        label: Some(name),
                        size: size as u64,
                        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                        mapped_at_creation: false,
                    });
                    gpu.queue.write_buffer(&buffer, 0, &bytes);
                    buffers.push((FFX_WGSL_BINDING_OFFSET_CBV + register, buffer));
                }
                class @ ("t" | "u") => {
                    let uav = class == "u";
                    let binding = job
                        .bindings
                        .iter()
                        .find(|b| b.name == name && b.uav == uav)
                        .unwrap_or_else(|| panic!("job binds no {name}"));
                    let view =
                        textures[binding.resource].create_view(&wgpu::TextureViewDescriptor {
                            base_mip_level: if uav { binding.mip } else { 0 },
                            mip_level_count: uav.then_some(1),
                            ..Default::default()
                        });
                    let offset = if uav {
                        FFX_WGSL_BINDING_OFFSET_UAV
                    } else {
                        FFX_WGSL_BINDING_OFFSET_SRV
                    };
                    views.push((offset + register, view));
                }
                "s" => {}
                class => panic!("unsupported register class {class}"),
            }
        }
        let mut entries: Vec<wgpu::BindGroupEntry> = views
            .iter()
            .map(|(binding, view)| wgpu::BindGroupEntry {
                binding: *binding,
                resource: wgpu::BindingResource::TextureView(view),
            })
            .chain(
                buffers
                    .iter()
                    .map(|(binding, buffer)| wgpu::BindGroupEntry {
                        binding: *binding,
                        resource: buffer.as_entire_binding(),
                    }),
            )
            .collect();
        for reflected in reflection["resources"].as_array().unwrap() {
            if reflected["registerClass"] == "s" {
                let register = u32::try_from(reflected["register"].as_u64().unwrap()).unwrap();
                entries.push(wgpu::BindGroupEntry {
                    binding: FFX_WGSL_BINDING_OFFSET_SAMPLER + register,
                    resource: wgpu::BindingResource::Sampler(&samplers[register as usize]),
                });
            }
        }
        let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some(stage),
            layout: &layout,
            entries: &entries,
        });

        {
            let mut pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some(stage),
                timestamp_writes: None,
            });
            pass.set_pipeline(&compute);
            pass.set_bind_group(0, &group, &[]);
            let [x, y, z] = job.dimensions;
            pass.dispatch_workgroups(x, y, z);
        }
        // Its outputs: every UAV-bound resource, all mips.
        let outputs = frame_directory("wgpu");
        for binding in job.bindings.iter().filter(|b| b.uav) {
            let texture = &textures[binding.resource];
            for mip in 0..texture.mip_level_count() {
                pending.push((
                    outputs.join(format!("{}.mip-{mip}.bin", binding.resource)),
                    Readback::texture(device, &mut encoder, texture, mip),
                ));
            }
        }
        gpu.queue.submit([encoder.finish()]);
        let (paths, readbacks): (Vec<_>, Vec<_>) = pending.into_iter().unzip();
        fs::create_dir_all(&inputs).unwrap();
        fs::create_dir_all(&outputs).unwrap();
        for (path, bytes) in paths.iter().zip(Readback::read_all(device, readbacks)) {
            fs::write(path, bytes).unwrap();
        }
    }
}

/// Run `jobs` (frame `i` is job `i`) as the SDK host drives the pass, through
/// the wgpu backend, and write the case into `directory` as [`run`] does.
///
/// The backend creates the pipeline for `pipeline.options` from the blob its
/// accessor selects (which must be `pipeline.blob`), creates each
/// `Resource::created` resource from its SDK description (uninitialized: the
/// first job binding it writes the contents the trace initializes it with),
/// and each frame
/// registers the application's resources and records the job. Before a job's
/// inputs are captured, each bound resource with `contents` receives them in
/// the backend's layout (a texture it backs with a buffer, an `R32G32_FLOAT`
/// UAV it allocates as RGBA); the captures keep the SDK's layouts. Resources
/// persist from job to job, as the SDK's do from frame to frame, so one
/// without contents holds what the previous jobs left (the first job that
/// binds an application resource gives its contents).
#[allow(clippy::too_many_lines)] // Pipeline, resources, jobs and captures of one case.
pub fn run_backend(
    gpu: &Gpu,
    effect: &Effect,
    directory: &Path,
    resources: &[Resource],
    pipeline: &Pipeline,
    jobs: &[Job],
) {
    let stage = effect.stages[pipeline.pass as usize];
    let device = &gpu.device;
    let ffx_effect = match effect.name {
        "fsr2" => FfxEffect::Fsr2,
        name => panic!("no SDK effect for {name}"),
    };
    assert_eq!(
        ffx_get_permutation_blob_by_index(
            ffx_effect,
            pipeline.pass,
            FFX_BIND_COMPUTE_SHADER_STAGE,
            pipeline.options
        ),
        Ok(pipeline.blob),
        "the blob the SDK selects for the options"
    );
    write_trace(directory, resources, pipeline, jobs);
    let source = ffx_get_wgsl_source(&pipeline.blob).expect("a ported pass");
    fs::write(directory.join(format!("{stage}.wgsl")), source).unwrap();

    let (backend, _) = ffx_get_interface_wgpu(device);
    let mut backend = backend.borrow_mut();
    let context = backend.create_backend_context(ffx_effect, None).unwrap();
    let root_constants: Vec<_> = pipeline
        .root_constants
        .iter()
        .map(|&size| FfxRootConstantDescription {
            size,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        })
        .collect();
    let state = backend
        .create_pipeline(
            ffx_effect,
            pipeline.pass,
            pipeline.options,
            &FfxPipelineDescription {
                context_flags: 0,
                samplers: &pipeline.samplers,
                root_constants: &root_constants,
                name: stage.into(),
                stage: FFX_BIND_COMPUTE_SHADER_STAGE,
                indirect_workload: 0,
                backbuffer_format: FfxSurfaceFormat::Unknown,
            },
            context,
        )
        .expect("the backend's pipeline for the pass and options");

    let mut internal: HashMap<&str, FfxResourceInternal> = HashMap::new();
    let mut applications = Vec::new();
    for r in resources {
        if let Some(usage) = r.created {
            let created = backend
                .create_resource(
                    &FfxCreateResourceDescription {
                        heap_type: FfxHeapType::Default,
                        resource_description: FfxResourceDescription {
                            r#type: FfxResourceType::Texture2D,
                            format: r.format,
                            width: r.width,
                            height: r.height,
                            depth: 1,
                            mip_count: r.mips,
                            flags: FFX_RESOURCE_FLAGS_NONE,
                            usage,
                        },
                        initial_state: if usage & FFX_RESOURCE_USAGE_UAV != 0 {
                            FFX_RESOURCE_STATE_UNORDERED_ACCESS
                        } else {
                            FFX_RESOURCE_STATE_COMPUTE_READ
                        },
                        name: r.name,
                        id: 0,
                        init_data: FfxResourceInitData {
                            r#type: FfxResourceInitDataType::Uninitialized,
                            ..Default::default()
                        },
                    },
                    context,
                )
                .unwrap();
            internal.insert(r.name, created);
            continue;
        }
        let written = jobs
            .iter()
            .flat_map(|j| &j.bindings)
            .any(|b| b.uav && b.resource == r.name);
        let texture = device.create_texture(&wgpu::TextureDescriptor {
            label: Some(r.name),
            size: wgpu::Extent3d {
                width: r.width,
                height: r.height,
                depth_or_array_layers: 1,
            },
            mip_level_count: r.mips,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: texture_format(r.format),
            usage: wgpu::TextureUsages::TEXTURE_BINDING
                | wgpu::TextureUsages::COPY_SRC
                | wgpu::TextureUsages::COPY_DST
                | if written {
                    wgpu::TextureUsages::STORAGE_BINDING
                } else {
                    wgpu::TextureUsages::empty()
                },
            view_formats: &[],
        });
        applications.push(Input {
            name: r.name,
            texture,
            format: r.format,
            cube: false,
            bytes: application_bytes(jobs, r.name),
        });
    }
    write_case_inputs(directory, resources, jobs, &applications);

    let contents: Rc<RefCell<HashMap<&'static str, Vec<u8>>>> = Rc::default();
    let capture = Capture::install_with(
        &mut backend,
        directory,
        effect,
        Some(Box::new({
            let contents = contents.clone();
            move |observation| write_contents(observation, &contents.borrow())
        })),
    );
    for (frame, job) in jobs.iter().enumerate() {
        capture.set_frame(frame);
        contents.borrow_mut().clone_from(&job.contents);
        let command_list =
            backend.ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        // The application's resources, registered for the dispatch.
        for input in &applications {
            let resource = backend.ffx_get_resource_wgpu(
                &input.texture,
                input.name,
                FFX_RESOURCE_STATE_COMPUTE_READ,
            );
            let registered = backend.register_resource(&resource, context).unwrap();
            internal.insert(input.name, registered);
        }
        let bound = |uav: bool, name: &str| {
            let binding = job
                .bindings
                .iter()
                .find(|b| b.uav == uav && b.name == name)
                .unwrap_or_else(|| panic!("job binds no {name}"));
            (internal[binding.resource], binding.mip)
        };
        let compute = FfxComputeJobDescription {
            pipeline: state.clone(),
            dimensions: job.dimensions,
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
                    let words = &job
                        .constants
                        .iter()
                        .find(|(name, _)| *name == b.name)
                        .unwrap_or_else(|| panic!("job has no {}", b.name))
                        .1;
                    FfxConstantBuffer {
                        num_32bit_entries: u32::try_from(words.len()).unwrap(),
                        data: words.clone(),
                    }
                })
                .collect(),
            ..Default::default()
        };
        backend
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: stage.into(),
                descriptor: FfxGpuJobDescriptor::Compute(Box::new(compute)),
            })
            .unwrap();
        backend.execute_gpu_jobs(command_list, context).unwrap();
        backend.unregister_resources(command_list, context).unwrap();
        let encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
        gpu.queue.submit([encoder.finish()]);
        capture.save(device);
    }
}

/// Write the job's contents (every mip, tightly packed in the SDK format)
/// into each resource a compute job binds that has contents, in the
/// backend's layout.
pub fn write_contents(
    observation: &mut FfxWgpuJobObservation<'_>,
    contents: &HashMap<&str, Vec<u8>>,
) {
    if !matches!(observation.job.descriptor, FfxGpuJobDescriptor::Compute(_)) {
        return;
    }
    let mut seen = HashSet::new();
    for resource in &observation.resources {
        if !seen.insert(resource.name) {
            continue;
        }
        // Without contents the resource keeps what earlier jobs left.
        let Some(bytes) = contents.get(resource.name) else {
            continue;
        };
        let staging = |data: &[u8]| {
            observation
                .device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("job contents"),
                    contents: data,
                    usage: wgpu::BufferUsages::COPY_SRC,
                })
        };
        match resource.object {
            // A texture the backend backs with a buffer of its texels.
            FfxWgpuObject::Buffer(buffer) => {
                let source = staging(bytes);
                observation.encoder.copy_buffer_to_buffer(
                    &source,
                    0,
                    buffer,
                    0,
                    bytes.len() as u64,
                );
            }
            FfxWgpuObject::Texture(texture) => {
                let sdk_texel = texture_format(resource.description.format)
                    .block_copy_size(None)
                    .unwrap() as usize;
                let texel = texture.format().block_copy_size(None).unwrap() as usize;
                let mut offset = 0;
                for mip in 0..texture.mip_level_count() {
                    let extent = texture.size().mip_level_size(mip, texture.dimension());
                    let (width, height) = (extent.width as usize, extent.height as usize);
                    let padded = (width * texel).next_multiple_of(256);
                    let mut data = vec![0; padded * height];
                    for y in 0..height {
                        for x in 0..width {
                            let from = offset + (y * width + x) * sdk_texel;
                            let to = y * padded + x * texel;
                            // An RGBA32Float allocation of an R32G32_FLOAT
                            // texture gains zero .zw.
                            data[to..to + sdk_texel]
                                .copy_from_slice(&bytes[from..from + sdk_texel]);
                        }
                    }
                    offset += width * height * sdk_texel;
                    let source = staging(&data);
                    observation.encoder.copy_buffer_to_texture(
                        wgpu::TexelCopyBufferInfo {
                            buffer: &source,
                            layout: wgpu::TexelCopyBufferLayout {
                                offset: 0,
                                bytes_per_row: Some(u32::try_from(padded).unwrap()),
                                rows_per_image: Some(extent.height),
                            },
                        },
                        wgpu::TexelCopyTextureInfo {
                            mip_level: mip,
                            ..texture.as_image_copy()
                        },
                        extent,
                    );
                }
                assert_eq!(offset, bytes.len(), "contents of {}", resource.name);
            }
        }
    }
}

/// The SDK formats the Metal oracle allocates.
fn texture_format(format: FfxSurfaceFormat) -> wgpu::TextureFormat {
    use FfxSurfaceFormat as F;
    use wgpu::TextureFormat as T;
    match format {
        F::R32G32B32A32Float => T::Rgba32Float,
        F::R16G16B16A16Float => T::Rgba16Float,
        F::R32G32Float => T::Rg32Float,
        F::R32Uint => T::R32Uint,
        F::R8G8B8A8Unorm => T::Rgba8Unorm,
        F::R11G11B10Float => T::Rg11b10Ufloat,
        F::R10G10B10A2Unorm => T::Rgb10a2Unorm,
        F::R16G16Float => T::Rg16Float,
        F::R16Float => T::R16Float,
        F::R16Snorm => T::R16Snorm,
        F::R8Unorm => T::R8Unorm,
        F::R8G8Unorm => T::Rg8Unorm,
        F::R32Float => T::R32Float,
        format => panic!("the Metal oracle does not allocate {format:?}"),
    }
}

/// An `FfxSamplerDescription` as the SDK's backends create it.
fn sampler(description: &FfxSamplerDescription) -> wgpu::SamplerDescriptor<'static> {
    let address = |mode| match mode {
        FfxAddressMode::Wrap => wgpu::AddressMode::Repeat,
        FfxAddressMode::Mirror => wgpu::AddressMode::MirrorRepeat,
        FfxAddressMode::Clamp => wgpu::AddressMode::ClampToEdge,
        FfxAddressMode::Border => wgpu::AddressMode::ClampToBorder,
        FfxAddressMode::MirrorOnce => panic!("no wgpu mirror-once addressing"),
    };
    let (filter, mipmap_filter) = match description.filter {
        FfxFilterType::MinMagMipPoint => {
            (wgpu::FilterMode::Nearest, wgpu::MipmapFilterMode::Nearest)
        }
        FfxFilterType::MinMagMipLinear => {
            (wgpu::FilterMode::Linear, wgpu::MipmapFilterMode::Linear)
        }
        FfxFilterType::MinMagLinearMipPoint => {
            (wgpu::FilterMode::Linear, wgpu::MipmapFilterMode::Nearest)
        }
    };
    wgpu::SamplerDescriptor {
        label: Some("FfxSamplerDescription"),
        address_mode_u: address(description.address_mode_u),
        address_mode_v: address(description.address_mode_v),
        address_mode_w: address(description.address_mode_w),
        mag_filter: filter,
        min_filter: filter,
        mipmap_filter,
        ..Default::default()
    }
}

/// Write the Metal oracle variants of `pipeline` that compare the port with
/// the original without compiler freedom: `directory/original` holds the
/// compiled original MSL, `directory/port` the MSL naga emits for `source`
/// (the port's WGSL, possibly edited) with wgpu's options, bound at the Metal
/// slots of the original's DXC reflection. Both turn floating-point
/// contraction off; [`crate::gpu::replay_strict`] also turns fast math off.
/// Returns the port's and the original's shader directories, each laid out
/// as `shaders/generated/<effect>`.
pub fn strict_variants(
    effect: &Effect,
    pipeline: &Pipeline,
    source: &str,
    directory: &Path,
) -> [std::path::PathBuf; 2] {
    use wgpu::naga::back::msl;
    let stage = effect.stages[pipeline.pass as usize];
    let variant = format!("options-{:#04x}", pipeline.options);
    let original = effect.shaders().join(&variant);
    let mut reflection: Value = serde_json::from_slice(
        &fs::read(original.join(format!("{stage}.reflection.json"))).unwrap(),
    )
    .unwrap();
    let mut manifest: Value =
        serde_json::from_slice(&fs::read(original.join("manifest.json")).unwrap()).unwrap();

    let mut resources = msl::BindingMap::default();
    for r in reflection["resources"].as_array().unwrap() {
        let register = u32::try_from(r["register"].as_u64().unwrap()).unwrap();
        let slot = u8::try_from(r["mslIndex"].as_u64().unwrap()).unwrap();
        let (offset, target) = match r["registerClass"].as_str().unwrap() {
            "t" => (
                FFX_WGSL_BINDING_OFFSET_SRV,
                msl::BindTarget {
                    texture: Some(slot),
                    ..Default::default()
                },
            ),
            "u" => (
                FFX_WGSL_BINDING_OFFSET_UAV,
                msl::BindTarget {
                    texture: Some(slot),
                    mutable: true,
                    ..Default::default()
                },
            ),
            "b" => (
                FFX_WGSL_BINDING_OFFSET_CBV,
                msl::BindTarget {
                    buffer: Some(slot),
                    ..Default::default()
                },
            ),
            "s" => (
                FFX_WGSL_BINDING_OFFSET_SAMPLER,
                msl::BindTarget {
                    sampler: Some(msl::BindSamplerTarget::Resource(slot)),
                    ..Default::default()
                },
            ),
            class => panic!("unsupported register class {class}"),
        };
        let binding = wgpu::naga::ResourceBinding {
            group: 0,
            binding: offset + register,
        };
        resources.insert(binding, target);
    }
    let module = wgpu::naga::front::wgsl::parse_str(source).unwrap();
    let info = wgpu::naga::valid::Validator::new(
        wgpu::naga::valid::ValidationFlags::all(),
        wgpu::naga::valid::Capabilities::all(),
    )
    .validate(&module)
    .unwrap();
    // wgpu-hal 30 metal/device.rs with default runtime checks
    // (`ShaderRuntimeChecks::checked`), at the language version its
    // metal/adapter.rs selects on macOS 26 and later.
    let restrict = wgpu::naga::proc::BoundsCheckPolicy::Restrict;
    let options = msl::Options {
        lang_version: (4, 0),
        per_entry_point_map: msl::EntryPointResourceMap::from([(
            FFX_WGSL_ENTRY_POINT.to_owned(),
            msl::EntryPointResources {
                resources,
                ..Default::default()
            },
        )]),
        inline_samplers: Vec::new(),
        spirv_cross_compatibility: false,
        fake_missing_bindings: false,
        bounds_check_policies: wgpu::naga::proc::BoundsCheckPolicies {
            index: restrict,
            buffer: restrict,
            image_load: restrict,
            binding_array: wgpu::naga::proc::BoundsCheckPolicy::Unchecked,
        },
        zero_initialize_workgroup_memory: true,
        force_loop_bounding: true,
        // Task shaders only.
        task_dispatch_limits: None,
        mesh_shader_primitive_indices_clamp: true,
        emit_int_div_checks: true,
        ray_query_initialization_tracking: true,
    };
    let entry_point = (
        wgpu::naga::ShaderStage::Compute,
        FFX_WGSL_ENTRY_POINT.to_owned(),
    );
    let (source, translation) = msl::write_string(
        &module,
        &info,
        &options,
        &msl::PipelineOptions {
            entry_point: Some(entry_point),
            allow_and_force_point_size: false,
            vertex_pulling_transform: true,
            vertex_buffer_mappings: Vec::new(),
            // The port's binding arrays are sized, which the writer takes
            // from the shader.
            binding_array_length_map: Default::default(),
        },
    )
    .unwrap();

    let entry = manifest["passes"][stage].take();
    manifest["passes"] = json!({ stage: entry });
    let original_msl = fs::read_to_string(original.join(format!("{stage}.metal"))).unwrap();
    let port_entry = translation.entry_point_names[0].as_ref().unwrap().clone();
    let original_entry = reflection["metalEntryPoint"].clone();
    [
        ("port", source, json!(port_entry)),
        ("original", original_msl, original_entry),
    ]
    .map(|(name, msl, entry)| {
        let shaders = directory.join(name);
        let variant = shaders.join(&variant);
        fs::create_dir_all(&variant).unwrap();
        fs::write(
            variant.join(format!("{stage}.metal")),
            format!("#pragma clang fp contract(off)\n{msl}"),
        )
        .unwrap();
        reflection["metalEntryPoint"] = entry;
        fs::write(
            variant.join(format!("{stage}.reflection.json")),
            serde_json::to_vec_pretty(&reflection).unwrap(),
        )
        .unwrap();
        fs::write(
            variant.join("manifest.json"),
            serde_json::to_vec_pretty(&manifest).unwrap(),
        )
        .unwrap();
        shaders
    })
}
