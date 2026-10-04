//! Per-pass comparison of the port's dumps (`wgpu`) with the Metal oracle's
//! replay of the same pass inputs (`metal-replay`).
//!
//! The expected dumps come from the C++ trace: every UAV of every compute job
//! (all mips) and every SDK copy destination (mip 0), so a dump missing on
//! both sides fails. Buffers must match exactly. A differing texture dump is
//! rejected unless the effect's `admit` rule names the documented exception
//! (a CONFORMANCE.md ID) that covers it.
use serde_json::Value;
use std::collections::{BTreeMap, HashMap};
use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy)]
struct Shape {
    buffer: bool,
    format: u32,
    width: u32,
    height: u32,
    mips: u32,
    layers: u32,
}

/// An expected dump: its size, and the pass whose output it holds (for a
/// copy, the pass that last wrote the source in that frame) and resource.
struct Expected {
    bytes: usize,
    owner: String,
    resource: String,
    shape: Shape,
    mip: u32,
}

fn expected_dumps(case: &Path, stages: &[&str]) -> Result<HashMap<PathBuf, Expected>, String> {
    let manifest: Value =
        serde_json::from_slice(&fs::read(case.join("inputs/inputs.json")).unwrap()).unwrap();
    let mut shapes: HashMap<String, Shape> = HashMap::new();
    for t in manifest["textures"].as_array().unwrap() {
        let n = |key: &str| u32::try_from(t[key].as_u64().unwrap()).unwrap();
        shapes.insert(
            t["name"].as_str().unwrap().to_owned(),
            Shape {
                buffer: false,
                format: n("format"),
                width: n("width"),
                height: n("height"),
                mips: n("mipCount"),
                layers: n("layers"),
            },
        );
    }
    let mut expected = HashMap::new();
    let mut frame = 0;
    let mut writers: HashMap<String, String> = HashMap::new();
    let trace = fs::read_to_string(case.join("cpp.jsonl")).unwrap();
    for line in trace.lines() {
        let event: Value = serde_json::from_str(line).unwrap();
        let n = |i: usize| u32::try_from(event[i].as_u64().unwrap()).unwrap();
        match event[0].as_str().unwrap() {
            "resource" => {
                let (width, height) = (n(4), n(5));
                shapes.insert(
                    event[1].as_str().unwrap().to_owned(),
                    Shape {
                        buffer: n(2) == 0,
                        format: n(3),
                        width,
                        height,
                        // Zero requests the full chain, as the backends allocate it.
                        mips: match n(6) {
                            0 => u32::BITS - width.max(height).leading_zeros(),
                            mips => mips,
                        },
                        layers: 1,
                    },
                );
            }
            "frame" => {
                frame = n(1);
                writers.clear();
            }
            "dispatch-result" if event[1].as_i64() != Some(0) => {
                return Err(format!("original C++ rejected GPU frame {frame}"));
            }
            "compute" => {
                let stage = stages[n(1) as usize];
                for binding in event[5].as_array().unwrap() {
                    if binding[0] == "srv" {
                        continue;
                    }
                    let name = binding[2].as_str().unwrap().to_owned();
                    let shape = shapes[&name];
                    let directory = PathBuf::from(format!("frame-{frame}")).join(stage);
                    writers.insert(name.clone(), stage.to_owned());
                    if shape.buffer {
                        expected.insert(
                            directory.join(format!("{name}.bin")),
                            Expected {
                                bytes: (shape.width as usize).next_multiple_of(4),
                                owner: stage.to_owned(),
                                resource: name.clone(),
                                shape,
                                mip: 0,
                            },
                        );
                        continue;
                    }
                    for mip in 0..shape.mips {
                        expected.insert(
                            directory.join(format!("{name}.mip-{mip}.bin")),
                            Expected {
                                bytes: texture_bytes(shape, mip),
                                owner: stage.to_owned(),
                                resource: name.clone(),
                                shape,
                                mip,
                            },
                        );
                    }
                }
            }
            "copy" => {
                let source = event[1].as_str().unwrap();
                let destination = event[2].as_str().unwrap();
                let shape = shapes[destination];
                expected.insert(
                    PathBuf::from(format!("frame-{frame}/copy/{destination}.mip-0.bin")),
                    Expected {
                        bytes: texture_bytes(shape, 0),
                        owner: writers.get(source).cloned().unwrap_or_default(),
                        resource: source.to_owned(),
                        shape,
                        mip: 0,
                    },
                );
            }
            _ => {}
        }
    }
    Ok(expected)
}

fn texture_bytes(shape: Shape, mip: u32) -> usize {
    let texel = match shape.format {
        3 => 16,
        4 | 6 => 8,
        8 | 10 | 16 | 17 | 18 | 28 => 4,
        21 | 24 | 26 => 2,
        25 => 1,
        format => panic!("unsupported surface format {format}"),
    };
    (shape.width >> mip).max(1) as usize
        * (shape.height >> mip).max(1) as usize
        * shape.layers as usize
        * texel
}

fn half(bits: u16) -> f64 {
    let exponent = i32::from((bits >> 10) & 0x1f);
    let mantissa = f64::from(bits & 0x3ff);
    let sign = if bits & 0x8000 != 0 { -1. } else { 1. };
    sign * match exponent {
        0 => mantissa * 2f64.powi(-24),
        31 if mantissa == 0. => f64::INFINITY,
        31 => f64::NAN,
        _ => (1. + mantissa / 1024.) * 2f64.powi(exponent - 15),
    }
}

/// An unsigned small float with a 5-bit exponent and `bits`-bit mantissa.
fn small_float(value: u32, bits: u32) -> f64 {
    let exponent = i32::try_from(value >> bits).unwrap();
    let mantissa = f64::from(value & ((1 << bits) - 1));
    let scale = f64::from(1u32 << bits);
    match exponent {
        0 => mantissa / scale * 2f64.powi(-14),
        31 => f64::NAN,
        _ => (1. + mantissa / scale) * 2f64.powi(exponent - 15),
    }
}

/// Decodes one texel's channels.
type Channels = dyn Fn(&[u8]) -> Vec<f64>;

/// The channels of every texel.
fn decode(format: u32, bytes: &[u8]) -> Vec<Vec<f64>> {
    let u16s = |c: &[u8]| {
        c.chunks_exact(2)
            .map(|b| half(u16::from_le_bytes([b[0], b[1]])))
            .collect()
    };
    let f32s = |c: &[u8]| {
        c.chunks_exact(4)
            .map(|b| f64::from(f32::from_le_bytes(b.try_into().unwrap())))
            .collect()
    };
    let unorm = |c: &[u8]| c.iter().map(|v| f64::from(*v) / 255.).collect();
    let (size, channels): (usize, &Channels) = match format {
        3 => (16, &f32s),
        4 => (8, &u16s),
        6 => (8, &f32s),
        8 => (4, &|c: &[u8]| {
            vec![f64::from(u32::from_le_bytes(c.try_into().unwrap()))]
        }),
        16 => (4, &|c: &[u8]| {
            let v = u32::from_le_bytes(c.try_into().unwrap());
            vec![
                small_float(v & 0x7ff, 6),
                small_float((v >> 11) & 0x7ff, 6),
                small_float(v >> 22, 5),
            ]
        }),
        18 => (4, &u16s),
        21 => (2, &u16s),
        24 => (2, &|c: &[u8]| {
            vec![(f64::from(i16::from_le_bytes([c[0], c[1]])) / 32767.).max(-1.)]
        }),
        25 | 26 | 10 => (
            match format {
                25 => 1,
                26 => 2,
                _ => 4,
            },
            &unorm,
        ),
        28 => (4, &f32s),
        format => panic!("no decoding for surface format {format}"),
    };
    bytes.chunks_exact(size).map(channels).collect()
}

/// One differing dump.
pub struct Difference {
    pub path: PathBuf,
    /// The pass that wrote it (for a copy, the pass that last wrote the
    /// source in that frame).
    pub stage: String,
    /// The written resource (for a copy, its source).
    pub resource: String,
    pub mip: u32,
    /// Width and height of the dumped mip.
    pub size: [u32; 2],
    pub texels: usize,
    pub maximum: f64,
    /// (min x, min y, max x, max y) of the differing texels.
    pub bounds: [u32; 4],
    /// The documented exception that admits it, or why none does.
    pub verdict: Result<&'static str, String>,
}

/// Outcome of one case.
#[derive(Default)]
pub struct Comparison {
    pub exact: usize,
    pub incomplete: Vec<String>,
    pub differences: Vec<Difference>,
    /// Dumps and exact dumps by pass directory (`copy` for copies).
    pub dumps: BTreeMap<String, (usize, usize)>,
}

impl Comparison {
    /// No incomplete evidence and every difference admitted.
    pub fn accepted(&self) -> bool {
        self.incomplete.is_empty() && self.differences.iter().all(|d| d.verdict.is_ok())
    }

    pub fn summary(&self) -> String {
        let mut text = format!(
            "{} exact dumps, {} differing dumps",
            self.exact,
            self.differences.len()
        );
        for item in &self.incomplete {
            let _ = write!(text, "\n  INCOMPLETE {item}");
        }
        for d in &self.differences {
            let _ = write!(
                text,
                "\n  {}: {} texels, max {:.6}, x {}..={} y {}..={}: {}",
                d.path.display(),
                d.texels,
                d.maximum,
                d.bounds[0],
                d.bounds[2],
                d.bounds[1],
                d.bounds[3],
                match &d.verdict {
                    Ok(exception) => format!("admitted ({exception})"),
                    Err(reason) => format!("REJECTED: {reason}"),
                }
            );
        }
        text
    }
}

/// Compare `wgpu` with `metal-replay` in `case`; `stages` names the passes by
/// SDK pass value. `admit` returns the documented exception that covers a
/// differing texture dump, or why none does.
pub fn compare(
    case: &Path,
    stages: &[&str],
    admit: &dyn Fn(&Difference) -> Result<&'static str, String>,
) -> Comparison {
    let mut result = Comparison::default();
    let expected = match expected_dumps(case, stages) {
        Ok(expected) => expected,
        Err(error) => {
            result.incomplete.push(error);
            return result;
        }
    };
    let (left, right) = (case.join("wgpu"), case.join("metal-replay"));
    let mut paths: Vec<_> = expected.keys().cloned().collect();
    paths.sort();
    for side in [&left, &right] {
        for entry in walk(side) {
            if !expected.contains_key(&entry) {
                result
                    .incomplete
                    .push(format!("unexpected {}", side.join(&entry).display()));
            }
        }
    }
    for path in paths {
        let e = &expected[&path];
        let read = |root: &Path| fs::read(root.join(&path)).ok();
        let (Some(a), Some(b)) = (read(&left), read(&right)) else {
            result
                .incomplete
                .push(format!("missing {}", path.display()));
            continue;
        };
        if a.len() != e.bytes || b.len() != e.bytes {
            result.incomplete.push(format!(
                "{}: {} and {} bytes, expected {}",
                path.display(),
                a.len(),
                b.len(),
                e.bytes
            ));
            continue;
        }
        let directory = path.iter().nth(1).unwrap().to_str().unwrap().to_owned();
        let count = result.dumps.entry(directory).or_default();
        count.0 += 1;
        if a == b {
            count.1 += 1;
            result.exact += 1;
            continue;
        }
        let width = (e.shape.width >> e.mip).max(1);
        let size = [width, (e.shape.height >> e.mip).max(1)];
        if e.shape.buffer {
            result.differences.push(Difference {
                path: path.clone(),
                stage: e.owner.clone(),
                resource: e.resource.clone(),
                mip: e.mip,
                size,
                texels: a.iter().zip(&b).filter(|(x, y)| x != y).count(),
                maximum: f64::NAN,
                bounds: [0; 4],
                verdict: Err("buffers must match exactly".into()),
            });
            continue;
        }
        let (x, y) = (decode(e.shape.format, &a), decode(e.shape.format, &b));
        let texel = a.len() / x.len();
        let mut texels = 0;
        let mut maximum = 0f64;
        let mut bounds = [u32::MAX, u32::MAX, 0, 0];
        for (index, (p, q)) in x.iter().zip(&y).enumerate() {
            let bytes = index * texel..(index + 1) * texel;
            if p == q || a[bytes.clone()] == b[bytes] {
                continue;
            }
            texels += 1;
            for (u, v) in p.iter().zip(q) {
                maximum = maximum.max(if u.is_nan() && v.is_nan() {
                    0.
                } else {
                    (u - v).abs()
                });
            }
            let (px, py) = (index as u32 % width, index as u32 / width);
            bounds = [
                bounds[0].min(px),
                bounds[1].min(py),
                bounds[2].max(px),
                bounds[3].max(py),
            ];
        }
        if texels == 0 {
            // Bitwise different NaN payloads or signed zeros only.
            result.exact += 1;
            continue;
        }
        let mut difference = Difference {
            path: path.clone(),
            stage: e.owner.clone(),
            resource: e.resource.clone(),
            mip: e.mip,
            size,
            texels,
            maximum,
            bounds,
            verdict: Err(String::new()),
        };
        difference.verdict = admit(&difference);
        result.differences.push(difference);
    }
    result
}

fn walk(root: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let mut stack = vec![root.to_owned()];
    while let Some(directory) = stack.pop() {
        let Ok(entries) = fs::read_dir(&directory) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                stack.push(path);
            } else if path.extension().is_some_and(|e| e == "bin") {
                let relative = path.strip_prefix(root).unwrap().to_owned();
                if relative.to_str().unwrap().starts_with("frame-") {
                    out.push(relative);
                }
            }
        }
    }
    out
}

/// Stages in pass order, then `copy`.
pub fn stage_order(stages: &[&str], stage: &str) -> usize {
    stages
        .iter()
        .position(|s| *s == stage)
        .unwrap_or(stages.len())
}
