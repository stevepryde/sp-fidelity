//! Original-shader control with only the independently reproduced SDK-P33 fix.
use sp_fidelity_oracle::{FRAMEINTERPOLATION, gpu};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

pub fn sequence(directory: &Path) -> PathBuf {
    let shaders = directory.join("bounded-original-shaders");
    fs::create_dir_all(&shaders).unwrap();
    // Both sync and async host modes select this same depth-inverted,
    // infinite-depth shader permutation. Every other shader remains unchanged.
    let variant = "options-0x05";
    let destination = shaders.join(variant);
    fs::create_dir_all(&destination).unwrap();
    for file in fs::read_dir(FRAMEINTERPOLATION.shaders().join(variant)).unwrap() {
        let file = file.unwrap();
        let target = destination.join(file.file_name());
        if file.file_name() == "frameinterpolation_game_motion_vector_field.metal" {
            let mut source = fs::read_to_string(file.path()).unwrap();
            let entry = source.find("kernel void main0(").unwrap();
            let start = entry + source[entry..].find("\n{\n").unwrap() + 3;
            source.insert_str(
                start,
                "    if (any(gl_GlobalInvocationID.xy >= uint2(cbFI.renderSize))) return;\n",
            );
            fs::write(target, source).unwrap();
        } else {
            std::os::unix::fs::symlink(file.path(), target).unwrap();
        }
    }
    let sequence = directory.join("sequence");
    gpu::link_case(directory, &sequence, &["cpp.jsonl", "inputs", "wgpu"]);
    let output = Command::new(gpu::metal_oracle())
        .args(["--compiler-mode", "wgpu"])
        .arg(shaders)
        .arg(directory.join("cpp.jsonl"))
        .arg(directory.join("inputs"))
        .arg(sequence.join("metal-replay"))
        .output()
        .unwrap();
    fs::write(
        directory.join("bounded-original.log"),
        [&output.stdout[..], &output.stderr[..]].concat(),
    )
    .unwrap();
    assert!(
        output.status.success(),
        "original with SDK-P33 bounds correction: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    sequence
}
