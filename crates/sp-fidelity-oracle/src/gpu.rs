//! Runs the port (host plus WGSL through `sp-fidelity-wgpu`) with a
//! capture of every job's resources, and replays each pass of AMD's C++ host
//! trace with the DXC-compiled unchanged HLSL on Metal from the captured
//! inputs.
//!
//! A case directory holds `inputs/` ([`write_inputs`] plus the C++ host's
//! exported initialization data), the C++ trace `cpp.jsonl`, the port's
//! captures `wgpu-inputs/` and `wgpu/` ([`Capture`]) and the Metal replay
//! `metal-replay/` ([`replay`]); [`crate::compare::compare`] compares them.
use crate::host::{Effect, root};
use serde_json::json;
use sp_fidelity::types::*;
use sp_fidelity_wgpu::readback::Readback;
use sp_fidelity_wgpu::{FfxWgpuBackend, FfxWgpuJobObservation, FfxWgpuObject};
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::rc::Rc;
use std::sync::OnceLock;

/// A Metal device with the backend's required features, `SHADER_F16` when
/// `fp16`, and optionally a lowered workgroup-count limit.
pub struct Gpu {
    pub adapter: wgpu::Adapter,
    pub device: wgpu::Device,
    pub queue: wgpu::Queue,
}

impl Gpu {
    pub fn new(fp16: bool, max_workgroups_per_dimension: Option<u32>) -> Self {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::METAL,
            ..wgpu::InstanceDescriptor::new_without_display_handle()
        });
        let adapter = pollster::block_on(instance.request_adapter(&Default::default()))
            .expect("Metal adapter");
        let mut limits = adapter.limits();
        if let Some(limit) = max_workgroups_per_dimension {
            limits.max_compute_workgroups_per_dimension = limit;
        }
        let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
            required_features: sp_fidelity_wgpu::required_features()
                | if fp16 {
                    wgpu::Features::SHADER_F16
                } else {
                    wgpu::Features::empty()
                },
            required_limits: limits,
            ..Default::default()
        }))
        .unwrap();
        Self {
            adapter,
            device,
            queue,
        }
    }
}

/// An application input texture, its oracle name and its initial bytes
/// (tightly packed, every mip and layer).
pub struct Input {
    pub name: &'static str,
    pub texture: wgpu::Texture,
    pub format: FfxSurfaceFormat,
    pub cube: bool,
    pub bytes: Vec<u8>,
}

/// Upload every mip and layer of `texture` from tightly packed `data`.
pub fn upload(queue: &wgpu::Queue, texture: &wgpu::Texture, data: &[u8]) {
    let mut offset = 0;
    for mip in 0..texture.mip_level_count() {
        let extent = texture.size().mip_level_size(mip, texture.dimension());
        let row_bytes = extent.width * texture.format().block_copy_size(None).unwrap();
        let len = (row_bytes * extent.height * extent.depth_or_array_layers) as usize;
        queue.write_texture(
            wgpu::TexelCopyTextureInfo {
                mip_level: mip,
                ..texture.as_image_copy()
            },
            &data[offset..offset + len],
            wgpu::TexelCopyBufferLayout {
                offset: 0,
                bytes_per_row: Some(row_bytes),
                rows_per_image: Some(extent.height),
            },
            extent,
        );
        offset += len;
    }
    assert_eq!(offset, data.len(), "input bytes must cover the texture");
}

/// Write `inputs/inputs.json` and the input files the Metal oracle loads:
/// every application input, and per frame the inputs that change then.
pub fn write_inputs(directory: &Path, inputs: &[Input], updates: &[Vec<(&str, Vec<u8>)>]) {
    let input_directory = directory.join("inputs");
    fs::create_dir_all(&input_directory).unwrap();
    let textures: Vec<_> = inputs
        .iter()
        .map(|input| {
            let file = format!("{}.bin", input.name);
            fs::write(input_directory.join(&file), &input.bytes).unwrap();
            let t = &input.texture;
            json!({"name": input.name, "format": input.format as u32, "width": t.width(),
                   "height": t.height(), "layers": t.depth_or_array_layers(),
                   "mipCount": t.mip_level_count(), "cube": input.cube, "file": file})
        })
        .collect();
    let frames: Vec<Vec<_>> = updates
        .iter()
        .enumerate()
        .map(|(i, updates)| {
            updates
                .iter()
                .map(|(resource, data)| {
                    let file = format!("frame-{i}/{resource}.bin");
                    fs::create_dir_all(input_directory.join(format!("frame-{i}"))).unwrap();
                    fs::write(input_directory.join(&file), data).unwrap();
                    json!({"name": resource, "file": file})
                })
                .collect()
        })
        .collect();
    fs::write(
        input_directory.join("inputs.json"),
        serde_json::to_vec_pretty(&json!({"textures": textures, "frames": frames})).unwrap(),
    )
    .unwrap();
}

/// Readbacks and their dump paths; `true` narrows `Rgba32Float` texels to
/// the SDK's `R32G32_FLOAT` (the backend allocates such UAVs as RGBA).
type Pending = Rc<RefCell<Vec<(PathBuf, Readback, bool)>>>;

/// Prepares a job before its capture, e.g. writes its inputs.
pub type Prepare = Box<dyn FnMut(&mut FfxWgpuJobObservation<'_>)>;

/// A dump of every resource of each compute job the port records (before:
/// all bound resources and indirect arguments into
/// `wgpu-inputs/frame-N/<pass>`; after: every UAV, all mips, into
/// `wgpu/frame-N/<pass>`) and of each SDK copy destination (mip 0, into
/// `wgpu/frame-N/copy`).
pub struct Capture {
    frame: Rc<Cell<usize>>,
    pending: Pending,
}

impl Capture {
    /// Observe `backend`'s jobs into `directory`; passes are named by
    /// `effect.stages`.
    pub fn install(backend: &mut FfxWgpuBackend, directory: &Path, effect: &Effect) -> Self {
        Self::install_with(backend, directory, effect, None)
    }

    /// As [`Self::install`], with `prepare` called before each job's inputs
    /// are captured.
    pub fn install_with(
        backend: &mut FfxWgpuBackend,
        directory: &Path,
        effect: &Effect,
        mut prepare: Option<Prepare>,
    ) -> Self {
        let capture = Self {
            frame: Rc::default(),
            pending: Rc::default(),
        };
        let (directory, stages) = (directory.to_owned(), effect.stages);
        let (frame, pending) = (capture.frame.clone(), capture.pending.clone());
        backend.set_job_observer(Some(Box::new(move |observation| {
            if let (false, Some(prepare)) = (observation.after, prepare.as_mut()) {
                prepare(observation);
            }
            observe(&directory, stages, frame.get(), &pending, observation);
        })));
        capture
    }

    /// The frame whose jobs are recorded next.
    pub fn set_frame(&self, frame: usize) {
        self.frame.set(frame);
    }

    /// Read back and write the dumps recorded so far; call after submitting
    /// the frame's commands.
    pub fn save(&self, device: &wgpu::Device) {
        let (targets, readbacks): (Vec<_>, Vec<_>) = self
            .pending
            .borrow_mut()
            .drain(..)
            .map(|(path, readback, narrow)| ((path, narrow), readback))
            .unzip();
        for ((path, narrow), bytes) in targets.iter().zip(Readback::read_all(device, readbacks)) {
            fs::create_dir_all(path.parent().unwrap()).unwrap();
            let bytes: Vec<u8> = if *narrow {
                bytes
                    .chunks_exact(16)
                    .flat_map(|t| &t[..8])
                    .copied()
                    .collect()
            } else {
                bytes
            };
            fs::write(path, bytes).unwrap();
        }
    }
}

fn observe(
    directory: &Path,
    stages: &[&str],
    frame: usize,
    pending: &Pending,
    observation: &mut FfxWgpuJobObservation<'_>,
) {
    let frame = format!("frame-{frame}");
    let (stage_directory, resources): (PathBuf, Vec<_>) =
        match (&observation.job.descriptor, observation.pass) {
            (FfxGpuJobDescriptor::Compute(_), Some((_, pass))) => (
                directory
                    .join(if observation.after {
                        "wgpu"
                    } else {
                        "wgpu-inputs"
                    })
                    .join(&frame)
                    .join(stages[pass as usize]),
                observation
                    .resources
                    .iter()
                    .filter(|r| !observation.after || r.writable)
                    .copied()
                    .collect(),
            ),
            // Resource initialization copies are the backend's, not jobs of
            // the SDK effect.
            (FfxGpuJobDescriptor::Copy(_), _)
                if observation.after && observation.job.job_label != "Resource initialization" =>
            {
                (
                    directory.join("wgpu").join(&frame).join("copy"),
                    observation
                        .resources
                        .iter()
                        .filter(|r| r.binding == "dst")
                        .copied()
                        .collect(),
                )
            }
            _ => return,
        };
    let base_only = stage_directory.ends_with("copy");
    let mut seen = HashSet::new();
    let mut pending = pending.borrow_mut();
    for resource in resources {
        if !seen.insert(resource.name) {
            continue;
        }
        // Dumps keep the SDK resource's layout, which the Metal oracle
        // allocates, where the backend's object differs.
        match resource.object {
            FfxWgpuObject::Texture(texture) => {
                let mips = if base_only {
                    1
                } else {
                    texture.mip_level_count()
                };
                let narrow = resource.description.format == FfxSurfaceFormat::R32G32Float
                    && texture.format() == wgpu::TextureFormat::Rgba32Float;
                for mip in 0..mips {
                    pending.push((
                        stage_directory.join(format!("{}.mip-{mip}.bin", resource.name)),
                        Readback::texture(observation.device, observation.encoder, texture, mip),
                        narrow,
                    ));
                }
            }
            // A texture the backend backs with a buffer of its texels.
            FfxWgpuObject::Buffer(buffer)
                if resource.description.r#type != FfxResourceType::Buffer =>
            {
                pending.push((
                    stage_directory.join(format!("{}.mip-0.bin", resource.name)),
                    Readback::buffer(observation.device, observation.encoder, buffer),
                    false,
                ));
            }
            FfxWgpuObject::Buffer(buffer) => pending.push((
                stage_directory.join(format!("{}.bin", resource.name)),
                Readback::buffer(observation.device, observation.encoder, buffer),
                false,
            )),
        }
    }
}

/// A fresh case directory under this crate's `target/gpu-oracle`.
pub fn case_directory(name: &str) -> PathBuf {
    let run = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let directory = root()
        .join("target/gpu-oracle")
        .join(format!("{name}-run-{run}"));
    fs::create_dir_all(&directory).unwrap();
    directory
}

/// The Metal oracle executable, built on first use.
pub fn metal_oracle() -> &'static PathBuf {
    static ORACLE: OnceLock<PathBuf> = OnceLock::new();
    ORACLE.get_or_init(|| {
        fs::create_dir_all(root().join("target")).unwrap();
        let oracle = root().join("target/metal-oracle");
        let build = Command::new("clang++")
            .args(["-std=c++17", "-fobjc-arc", "-Wno-deprecated-declarations"])
            .arg(root().join("oracle/metal.mm"))
            .args(["-framework", "Foundation", "-framework", "Metal", "-o"])
            .arg(&oracle)
            .output()
            .unwrap();
        assert!(
            build.status.success(),
            "Metal oracle build: {}",
            String::from_utf8_lossy(&build.stderr)
        );
        oracle
    })
}

/// Execute the case's C++ trace with the DXC-compiled unchanged HLSL of
/// `effect` on Metal, each pass reloading the port's captured inputs, into
/// `metal-replay`. Every pipeline needs a variant compiled for its pass and
/// permutation options.
pub fn replay(directory: &Path, effect: &Effect) {
    let result = Command::new(metal_oracle())
        .args(["--compiler-mode", "wgpu", "--replay"])
        .arg(directory.join("wgpu-inputs"))
        .arg(effect.shaders())
        .arg(directory.join("cpp.jsonl"))
        .arg(directory.join("inputs"))
        .arg(directory.join("metal-replay"))
        .output()
        .unwrap();
    fs::write(
        directory.join("metal-replay.log"),
        [result.stdout.as_slice(), result.stderr.as_slice()].concat(),
    )
    .unwrap();
    assert!(
        result.status.success(),
        "original shader execution failed: {}",
        String::from_utf8_lossy(&result.stderr)
    );
}

/// Execute the case's C++ trace as [`replay`] does, but from the case's
/// `inputs/` alone (application inputs, their per-frame updates and the
/// created resources' initialization data): every pass reads what the Metal
/// run wrote before it, not the port's captures. The results go to
/// `sequence/metal-replay` beside links to the case's trace, inputs and port
/// dumps; [`crate::compare::compare`] on the returned `sequence` directory
/// compares the port's own sequence with the oracle's.
pub fn run_sequence(directory: &Path, effect: &Effect) -> PathBuf {
    let sequence = directory.join("sequence");
    link_case(directory, &sequence, &["cpp.jsonl", "inputs", "wgpu"]);
    oracle(
        &["--compiler-mode", "wgpu"],
        &effect.shaders(),
        directory,
        &sequence.join("metal-replay"),
    );
    sequence
}

/// [`replay`] with the variants in `shaders` (a directory laid out as
/// `shaders/generated/<effect>`) compiled without fast math
/// (`--compiler-mode strict`), into `output`.
pub fn replay_strict(directory: &Path, shaders: &Path, output: &Path) {
    let replay = directory.join("wgpu-inputs");
    oracle(
        &[
            "--compiler-mode",
            "strict",
            "--replay",
            replay.to_str().unwrap(),
        ],
        shaders,
        directory,
        output,
    );
}

/// Links `names` of the case `directory` into `into`.
pub fn link_case(directory: &Path, into: &Path, names: &[&str]) {
    fs::create_dir_all(into).unwrap();
    for name in names {
        std::os::unix::fs::symlink(directory.join(name), into.join(name)).unwrap();
    }
}

/// Run the Metal oracle on the case `directory`'s trace and inputs.
fn oracle(options: &[&str], shaders: &Path, directory: &Path, output: &Path) {
    let result = Command::new(metal_oracle())
        .args(options)
        .arg(shaders)
        .arg(directory.join("cpp.jsonl"))
        .arg(directory.join("inputs"))
        .arg(output)
        .output()
        .unwrap();
    fs::write(
        output.with_extension("log"),
        [result.stdout.as_slice(), result.stderr.as_slice()].concat(),
    )
    .unwrap();
    assert!(
        result.status.success(),
        "original shader execution failed: {}",
        String::from_utf8_lossy(&result.stderr)
    );
}
