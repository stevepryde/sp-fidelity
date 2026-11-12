use sp_fidelity::types::FfxSurfaceFormat;
use sp_fidelity_oracle::{FRAMEINTERPOLATION, gpu};
use std::fs;
use std::path::Path;

// Analytic scene: an infinite stationary plane two metres below a level
// perspective camera. Forward translation is four metres per real frame.
// All inputs are generated here; no SGL/game assets, matrices or capture data.
pub fn inputs(size: [u32; 2]) -> (Vec<u8>, Vec<u8>) {
    let mut depth = Vec::new();
    let mut motion = Vec::new();
    let tan = 40f64.to_radians().tan();
    for y in 0..size[1] {
        for x in 0..size[0] {
            let u = (x as f64 + 0.5) / size[0] as f64;
            let v = (y as f64 + 0.5) / size[1] as f64;
            let z = 2. / ((v - 0.5) * 2. * tan);
            let d = if v > 0.5 { 0.3 / z } else { 0. };
            depth.extend((d as f32).to_le_bytes());
            for component in [u - 0.5, v - 0.5] {
                let mv = if v > 0.5 {
                    -component * 4. / (z + 4.)
                } else {
                    0.
                };
                motion.extend(binary16(mv as f32).to_le_bytes());
            }
        }
    }
    (depth, motion)
}
fn binary16(v: f32) -> u16 {
    let bits = v.to_bits();
    if v == 0. {
        return 0;
    }
    let sign = ((bits >> 16) & 0x8000) as u16;
    let exponent = ((bits >> 23) & 255) as i32 - 127 + 15;
    if exponent <= 0 {
        let shift = (14 - exponent) as u32;
        if shift >= 32 {
            return sign;
        }
        let significand = (bits & 0x7fffff) | 0x800000;
        let rounded =
            (significand + ((1 << (shift - 1)) - 1) + ((significand >> shift) & 1)) >> shift;
        return sign | rounded as u16;
    }
    sign | (((((exponent as u32) << 23) | (bits & 0x7fffff)) + 0xfff + ((bits >> 13) & 1)) >> 13)
        as u16
}
pub fn color(size: [u32; 2], frame: u32) -> Vec<u8> {
    let mut data = Vec::new();
    for y in 0..size[1] {
        let v = (y as f64 + 0.5) / size[1] as f64;
        let z = 2. / ((v - 0.5) * 2. * 40f64.to_radians().tan());
        let world_z = 8. - 4. * frame as f64 - z;
        let color = if v <= 0.5 {
            0.
        } else if (world_z / 3.1).floor() as i32 % 2 == 0 {
            0.25
        } else {
            0.75
        };
        for _ in 0..size[0] {
            for channel in [color, color, color, 1.] {
                data.extend(binary16(channel).to_le_bytes());
            }
        }
    }
    data
}
pub fn words(flags: u32, size: [u32; 2]) -> Vec<u32> {
    let mut words = vec![
        1,
        flags,
        size[0],
        size[1],
        size[0],
        size[1],
        FfxSurfaceFormat::R16G16B16A16Float as u32,
        FfxSurfaceFormat::R16G16B16A16Float as u32,
        8,
    ];
    for frame in 0..4 {
        words.extend([0, 0, 1, size[0], size[1], frame, 0]);
        words.extend(
            [
                0.,
                0.,
                size[0] as f32,
                size[1] as f32,
                1000. / 30.,
                f32::MAX,
                0.3,
                1.,
                80f32.to_radians(),
            ]
            .map(f32::to_bits),
        );
        words.extend(
            [
                0.,
                2.,
                8. - 4. * frame as f32,
                0.,
                1.,
                0.,
                1.,
                0.,
                0.,
                0.,
                0.,
                -1.,
            ]
            .map(f32::to_bits),
        );
        words.extend([
            1,
            0,
            5,
            size[0],
            size[1],
            frame,
            0,
            size[0],
            size[1],
            0,
            0,
            size[0],
            size[1],
            size[0].div_ceil(8),
            size[1].div_ceil(8),
        ]);
        words.extend([1. / size[0] as f32, 1. / size[1] as f32].map(f32::to_bits));
        words.push(8);
        words.extend([f32::MAX, 0.3, 80f32.to_radians(), 1., 1000. / 30.].map(f32::to_bits));
        words.extend([u32::from(frame == 0), 0, 0f32.to_bits(), 1000f32.to_bits()]);
    }
    words
}
// This is a diagnosis, not a quality acceptance test or a tolerance for parity
// failures. An independently projected plane must keep its horizontal stripes
// straight. The unchanged interpolation pass does so with the analytic field,
// but the SDK's reconstructed field cannot provide the outgoing-edge velocity.
pub fn diagnose(directory: &Path, original: &Path, events: &[serde_json::Value], size: [u32; 2]) {
    let [width, height] = size.map(|v| v as usize);
    let stage = "frameinterpolation_interpolation";
    let frame = "frame-7";
    let field_stage = "frameinterpolation_game_motion_vector_field";
    let original_output = original.join("metal-replay").join(frame);
    for axis in ["X", "Y"] {
        let filename = format!("FI_GameMotionVectorField{axis}.mip-0.bin");
        let port = fs::read(
            directory
                .join("wgpu")
                .join(frame)
                .join(field_stage)
                .join(&filename),
        )
        .unwrap();
        let amd = fs::read(original_output.join(field_stage).join(filename)).unwrap();
        // SDK-P33 accounts for the original's invalid last-row primary splats.
        // All other primary entries and flags must agree. Secondary entries
        // are order-dependent in the unchanged original; no equality claim.
        for (i, (port, amd)) in port
            .chunks_exact(4)
            .zip(amd.chunks_exact(4))
            .enumerate()
            .take(width * (height - 1))
        {
            let a = u32::from_le_bytes(port.try_into().unwrap());
            let b = u32::from_le_bytes(amd.try_into().unwrap());
            assert_eq!(a >> 31, b >> 31, "primary flag {axis} at {i}");
            if b >> 31 != 0 {
                assert_eq!(a, b, "primary {axis} at {i}");
            }
        }
    }
    let mut trace: Vec<_> = events
        .iter()
        .filter(|e| e[0] == "resource" || (e[0] == "pipeline" && e[1] == 6))
        .cloned()
        .collect();
    let mut current_frame = 0;
    let job = events
        .iter()
        .find(|e| {
            if e[0] == "frame" {
                current_frame = e[1].as_u64().unwrap();
            }
            current_frame == 7 && e[0] == "compute" && e[1] == 6
        })
        .unwrap();
    trace.extend([serde_json::json!(["frame", 7]), job.clone()]);
    let trace = trace
        .iter()
        .map(serde_json::Value::to_string)
        .collect::<Vec<_>>()
        .join("\n")
        + "\n";
    let mut controls = Vec::new();
    for variant in [
        "observed",
        "warm-zero-flow",
        "warm-shifted-flow",
        "analytic-field",
    ] {
        let control = directory.join(variant);
        gpu::link_case(directory, &control, &["inputs"]);
        fs::write(control.join("cpp.jsonl"), &trace).unwrap();
        let target = control.join("wgpu-inputs").join(frame).join(stage);
        fs::create_dir_all(&target).unwrap();
        for file in fs::read_dir(directory.join("wgpu-inputs").join(frame).join(stage)).unwrap() {
            let file = file.unwrap();
            fs::copy(file.path(), target.join(file.file_name())).unwrap();
        }
        // Retain the analytic application colors/counter, but take every
        // internal field from its last writer in the independent AMD sequence.
        for writer in [
            "frameinterpolation_game_motion_vector_field",
            "frameinterpolation_optical_flow_vector_field",
            "frameinterpolation_disocclusion_mask",
            "frameinterpolation_game_vector_field_inpainting_pyramid",
        ] {
            for file in fs::read_dir(original_output.join(writer)).unwrap() {
                let file = file.unwrap();
                let destination = target.join(file.file_name());
                if destination.exists() {
                    fs::copy(file.path(), destination).unwrap();
                }
            }
        }
        if variant.starts_with("warm-") || variant == "analytic-field" {
            let path = target.join("FI_Counters.bin");
            let mut bytes = fs::read(&path).unwrap();
            bytes[4..8].copy_from_slice(&52u32.to_le_bytes());
            fs::write(path, bytes).unwrap();
        }
        if variant.starts_with("warm-") {
            for axis in ["X", "Y"] {
                let path = target.join(format!("FI_OpticalFlowMotionVectorField{axis}.mip-0.bin"));
                let length = fs::metadata(&path).unwrap().len() as usize;
                let word = 0xbfff0000u32
                    | u32::from(binary16(if variant == "warm-zero-flow" { 0. } else { 0.2 }));
                fs::write(path, word.to_le_bytes().repeat(length / 4)).unwrap();
            }
        }
        if variant == "analytic-field" {
            let mut field = [Vec::new(), Vec::new()];
            for y in 0..height {
                let v = (y as f64 + 0.5) / height as f64;
                // Solve the endpoint-linear midpoint projection of the plane:
                // a*z^2 + (4a-1)*z - 2 = 0, where a=(v-.5)*tan(40deg).
                let a = (v - 0.5) * 40f64.to_radians().tan();
                let z = (1. - 4. * a + (1. + (4. * a).powi(2)).sqrt()) / (2. * a);
                for x in 0..width {
                    let u = (x as f64 + 0.5) / width as f64;
                    for (axis, component) in [u - 0.5, v - 0.5].into_iter().enumerate() {
                        let mv = if v > 0.5 {
                            -component * 4. / (2. * z + 4.)
                        } else {
                            0.
                        };
                        field[axis]
                            .extend((0xbfff0000u32 | u32::from(binary16(mv as f32))).to_le_bytes());
                    }
                }
            }
            for (axis, bytes) in ["X", "Y"].into_iter().zip(field) {
                fs::write(
                    target.join(format!("FI_GameMotionVectorField{axis}.mip-0.bin")),
                    bytes,
                )
                .unwrap();
            }
        }
        gpu::replay(&control, &FRAMEINTERPOLATION);
        controls.push(
            fs::read(
                control
                    .join("metal-replay")
                    .join(frame)
                    .join(stage)
                    .join("output.mip-0.bin"),
            )
            .unwrap(),
        );
    }
    let row = |bytes: &[u8], y: usize| bytes[y * width * 8..(y + 1) * width * 8].to_vec();
    assert_eq!(
        row(&controls[0], 700),
        row(&controls[1], 700),
        "warmup must not explain the outgoing edge"
    );
    assert_eq!(
        row(&controls[1], 700),
        row(&controls[2], 700),
        "optical flow must not explain the outgoing edge"
    );
    let bent = |bytes: &[u8]| {
        (660..740).any(|y| {
            let row = &bytes[y * width * 8..(y + 1) * width * 8];
            row.chunks_exact(8).any(|p| p[..6] != row[..6])
        })
    };
    assert!(
        bent(&controls[0]),
        "negative control must reproduce the upstream bent stripes"
    );
    assert!(
        !bent(&controls[3]),
        "analytic motion must retain horizontal plane stripes"
    );
    println!(
        "{}: original outgoing-edge limitation reproduced; analytic-field substitution removes bending; warmup and optical flow excluded",
        directory.display()
    );
}
