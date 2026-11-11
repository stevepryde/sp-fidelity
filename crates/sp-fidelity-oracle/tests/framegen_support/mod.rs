//! Shared recording and trace readers for the optical-flow/interpolation oracles.
#![allow(dead_code)]
use serde_json::{Value, json};
use sp_fidelity::error::FfxErrorCode;
use sp_fidelity::types::*;
use sp_fidelity_oracle::host::{Effect, build_cpp_host, run_cpp_host};
use sp_fidelity_oracle::recorder::Recorder;
use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::sync::{Mutex, OnceLock};

pub struct Words<'a> {
    pub words: &'a [u32],
    pub at: usize,
}

impl Words<'_> {
    pub fn word(&mut self) -> u32 {
        let word = self.words[self.at];
        self.at += 1;
        word
    }

    pub fn scalar(&mut self) -> f32 {
        f32::from_bits(self.word())
    }

    pub fn size(&mut self) -> FfxDimensions2D {
        FfxDimensions2D {
            width: self.word(),
            height: self.word(),
        }
    }

    pub fn coords(&mut self) -> FfxFloatCoords2D {
        FfxFloatCoords2D {
            x: self.scalar(),
            y: self.scalar(),
        }
    }

    pub fn id(&mut self) -> u64 {
        u64::from(self.word()) | u64::from(self.word()) << 32
    }
}

pub fn capabilities(wave64: bool, fp16: bool) -> FfxDeviceCapabilities {
    FfxDeviceCapabilities {
        maximum_supported_shader_model: if wave64 {
            FfxShaderModel::ShaderModel6_6
        } else {
            FfxShaderModel::ShaderModel6_2
        },
        wave_lane_count_min: 32,
        wave_lane_count_max: if wave64 { 64 } else { 32 },
        fp16_supported: fp16,
        ..Default::default()
    }
}

pub fn status<T>(result: &Result<T, FfxErrorCode>) -> FfxErrorCode {
    result.as_ref().err().copied().unwrap_or(0)
}

pub fn shared(recorder: &Rc<RefCell<Recorder>>, r: &FfxCreateResourceDescription<'_>) {
    let d = r.resource_description;
    recorder.borrow_mut().events.push(json!([
        "shared-resource",
        r.name,
        r.heap_type as u32,
        d.r#type as u32,
        d.format as u32,
        d.width,
        d.height,
        d.depth,
        d.mip_count,
        d.flags,
        d.usage,
        r.initial_state,
        r.id,
        r.init_data.r#type as u32,
        r.init_data.size
    ]));
}

pub type Recorded = (Vec<Value>, HashMap<String, Vec<u8>>);

pub fn take(recorder: &Rc<RefCell<Recorder>>) -> Recorded {
    let mut r = recorder.borrow_mut();
    (
        std::mem::take(&mut r.events),
        std::mem::take(&mut r.init_data),
    )
}

pub fn cpp_host(effect: &Effect) -> (PathBuf, PathBuf) {
    static HOSTS: OnceLock<Mutex<HashMap<&'static str, (PathBuf, PathBuf)>>> = OnceLock::new();
    HOSTS
        .get_or_init(Mutex::default)
        .lock()
        .unwrap()
        .entry(effect.name)
        .or_insert_with(|| {
            build_cpp_host(
                &PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join(format!(
                    "{}-host/build-{}",
                    effect.name,
                    std::process::id()
                )),
                effect,
            )
        })
        .clone()
}

pub fn cpp(
    effect: &Effect,
    caps: FfxDeviceCapabilities,
    words: &[u32],
    directory: &Path,
) -> Recorded {
    fs::create_dir_all(directory.join("init-data")).unwrap();
    let trace = run_cpp_host(
        &cpp_host(effect),
        &caps,
        words,
        &directory.join("input.words"),
        &directory.join("init-data"),
    );
    fs::write(directory.join("cpp.jsonl"), &trace).unwrap();
    let events = trace
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    let data = fs::read_dir(directory.join("init-data"))
        .unwrap()
        .map(|entry| {
            let path = entry.unwrap().path();
            (
                path.file_stem().unwrap().to_str().unwrap().to_owned(),
                fs::read(path).unwrap(),
            )
        })
        .collect();
    (events, data)
}

pub fn compare(
    effect: &Effect,
    name: &str,
    caps: FfxDeviceCapabilities,
    words: &[u32],
    rust: impl FnOnce(FfxDeviceCapabilities, &[u32]) -> Recorded,
) {
    let directory =
        PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join(format!("{}-host/{name}", effect.name));
    let _ = fs::remove_dir_all(&directory);
    let (mut original, original_data) = cpp(effect, caps, words, &directory);
    let (port, port_data) = rust(caps, words);
    if effect.name == "opticalflow" {
        // The SDK stages OpticalFlowSpdConstants' three uninitialized padding
        // words. They have no shader meaning; retain every initialized word.
        let mut staged = 0;
        for event in &mut original {
            if event[0] == "frame" {
                staged = 0;
            }
            if event[0] == "constants" {
                staged += 1;
                // dispatch() stages cbOF then OpticalFlowSpdConstants before
                // scheduling any pass. DXC drops the unused SPD binding.
                if staged == 2 {
                    for word in &mut event[1].as_array_mut().unwrap()[5..8] {
                        *word = json!(0);
                    }
                }
            }
            if event[0] == "compute" {
                for cb in event[6].as_array_mut().unwrap() {
                    if cb[0] == "cbOF_SPD" {
                        for word in &mut cb[1].as_array_mut().unwrap()[5..8] {
                            *word = json!(0);
                        }
                    }
                }
            }
        }
    }
    for (index, (c, r)) in original.iter().zip(&port).enumerate() {
        assert_eq!(
            c,
            r,
            "{name}: event {index}; preceding original events {:?}",
            &original[index.saturating_sub(3)..index]
        );
    }
    assert_eq!(original.len(), port.len(), "{name}: event counts differ");
    assert_eq!(
        original_data, port_data,
        "{name}: resource initialization differs"
    );
    println!("{name}: {} identical events", original.len());
}

pub fn surface_format(word: u32) -> FfxSurfaceFormat {
    // This is an ABI enum read from the unchanged C++ trace.
    [
        FfxSurfaceFormat::Unknown,
        FfxSurfaceFormat::R32G32B32A32Typeless,
        FfxSurfaceFormat::R32G32B32A32Uint,
        FfxSurfaceFormat::R32G32B32A32Float,
        FfxSurfaceFormat::R16G16B16A16Float,
        FfxSurfaceFormat::R32G32B32Float,
        FfxSurfaceFormat::R32G32Float,
        FfxSurfaceFormat::R8Uint,
        FfxSurfaceFormat::R32Uint,
        FfxSurfaceFormat::R8G8B8A8Typeless,
        FfxSurfaceFormat::R8G8B8A8Unorm,
        FfxSurfaceFormat::R8G8B8A8Snorm,
        FfxSurfaceFormat::R8G8B8A8Srgb,
        FfxSurfaceFormat::B8G8R8A8Typeless,
        FfxSurfaceFormat::B8G8R8A8Unorm,
        FfxSurfaceFormat::B8G8R8A8Srgb,
        FfxSurfaceFormat::R11G11B10Float,
        FfxSurfaceFormat::R10G10B10A2Unorm,
        FfxSurfaceFormat::R16G16Float,
        FfxSurfaceFormat::R16G16Uint,
        FfxSurfaceFormat::R16G16Sint,
        FfxSurfaceFormat::R16Float,
        FfxSurfaceFormat::R16Uint,
        FfxSurfaceFormat::R16Unorm,
        FfxSurfaceFormat::R16Snorm,
        FfxSurfaceFormat::R8Unorm,
        FfxSurfaceFormat::R8G8Unorm,
        FfxSurfaceFormat::R8G8Uint,
        FfxSurfaceFormat::R32Float,
    ][word as usize]
}
