//! The core resource set: how FSR2's and FSR3's textures are allocated on a
//! device without the SDK's storage formats (`sdk_storage_features`), which is
//! every browser's. WebGPU's core set writes storage textures in the RGBA and
//! 32-bit formats only, reads and writes them in one pass in the 32-bit
//! single-component formats only, and has no 16-bit normalized format.
//!
//! One table owns every substitution: the allocation, the WGSL declaration and
//! the texel conversion between the SDK's layout and the allocation's. Each
//! keeps the SDK's values (CONFORMANCE.md, SDK-P38):
//!
//! - A narrow format a pass only writes becomes the RGBA format of the same
//!   component type, so the hardware converts each store as it would the
//!   SDK's and filters as it would (`WIDENED`).
//! - `R11G11B10_FLOAT` becomes `Rgba16Float`, with the port's WGSL truncating
//!   each store to that format's precision.
//! - The new locks, a read-write `R8_UNORM` texture, become `R32Float`, with
//!   the port's WGSL storing the value the unorm texel would return.
//! - A read-write 1x1 `R32G32_FLOAT` or `R32G32B32A32_FLOAT` texture becomes
//!   `R32Float` with a texel a component (`columns`).
//! - An `R16_SNORM` lookup becomes `R32Float` holding each snorm value. No
//!   pass the core set builds reads one (`get_device_capabilities`).
//!
//! The mips SPD reads and writes stay 16-bit floats: its two dispatches bind
//! them write-only and read-only instead (`FfxWgslSpdPhase`).
use sp_fidelity::types::{
    FFX_RESOURCE_USAGE_UAV, FfxCreateResourceDescription, FfxEffect, FfxSurfaceFormat,
};
use wgpu::TextureFormat;

/// A narrow storage format, the core format its UAVs are allocated in, and
/// both as WGSL storage texel formats.
const WIDENED: &[(FfxSurfaceFormat, TextureFormat, &str, &str)] = &[
    (
        FfxSurfaceFormat::R16G16Float,
        TextureFormat::Rgba16Float,
        "rg16float",
        "rgba16float",
    ),
    (
        FfxSurfaceFormat::R16Float,
        TextureFormat::Rgba16Float,
        "r16float",
        "rgba16float",
    ),
    (
        FfxSurfaceFormat::R8G8Unorm,
        TextureFormat::Rgba8Unorm,
        "rg8unorm",
        "rgba8unorm",
    ),
    (
        FfxSurfaceFormat::R8Unorm,
        TextureFormat::Rgba8Unorm,
        "r8unorm",
        "rgba8unorm",
    ),
    (
        FfxSurfaceFormat::R11G11B10Float,
        TextureFormat::Rgba16Float,
        "rg11b10ufloat",
        "rgba16float",
    ),
];

/// How the core set allocates a texture.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Allocation {
    pub format: TextureFormat,
    /// Texels a texel of the SDK's description takes, side by side: its
    /// components, for a read-write multi-component 32-bit float texture.
    pub columns: u32,
}

/// The core set's allocation of a texture `effect` creates, where it differs
/// from the SDK's format.
pub(crate) fn allocation(
    effect: FfxEffect,
    create: &FfxCreateResourceDescription,
) -> Option<Allocation> {
    use sp_fidelity::fsr2::resources as fsr2;
    use sp_fidelity::fsr3upscaler::resources as fsr3;
    let description = &create.resource_description;
    let uav = description.usage & FFX_RESOURCE_USAGE_UAV != 0;
    let one = |format| Some(Allocation { format, columns: 1 });
    let new_locks = match effect {
        FfxEffect::Fsr2 => create.id == fsr2::FFX_FSR2_RESOURCE_IDENTIFIER_NEW_LOCKS,
        FfxEffect::Fsr3Upscaler => {
            create.id == fsr3::FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_NEW_LOCKS
        }
        _ => false,
    };
    match description.format {
        FfxSurfaceFormat::R16Snorm => one(TextureFormat::R32Float),
        FfxSurfaceFormat::R8Unorm if uav && new_locks => one(TextureFormat::R32Float),
        FfxSurfaceFormat::R32G32Float if uav => Some(Allocation {
            format: TextureFormat::R32Float,
            columns: 2,
        }),
        FfxSurfaceFormat::R32G32B32A32Float if uav => Some(Allocation {
            format: TextureFormat::R32Float,
            columns: 4,
        }),
        format if uav => storage_format(format).and_then(one),
        _ => None,
    }
}

/// The core storage format of a narrow one, for a UAV the caller allocates.
pub(crate) fn storage_format(format: FfxSurfaceFormat) -> Option<TextureFormat> {
    WIDENED
        .iter()
        .find(|(narrow, ..)| *narrow == format)
        .map(|(_, wide, ..)| *wide)
}

/// The port's WGSL with every narrow storage texture declared in its core
/// format. The declarations that change access or layout are the port's own
/// (`FFX_WGSL_CORE`).
pub(crate) fn declare(mut source: String) -> String {
    for (_, _, narrow, wide) in WIDENED {
        source = source.replace(
            &format!("texture_storage_2d<{narrow},"),
            &format!("texture_storage_2d<{wide},"),
        );
    }
    source
}

fn halves(data: &[u8]) -> impl Iterator<Item = u16> + '_ {
    data.chunks_exact(2)
        .map(|half| u16::from_le_bytes([half[0], half[1]]))
}

/// Texels in the SDK's `format` as texels of a texture of `allocation`, the
/// unused components zero: what an upload to a texture this backend
/// allocated differently needs, as its own initial data does.
pub fn ffx_texels_from_sdk_wgpu(
    format: FfxSurfaceFormat,
    allocation: TextureFormat,
    data: &[u8],
) -> Vec<u8> {
    use FfxSurfaceFormat as F;
    use TextureFormat as T;
    let pad = |texel: usize, to: usize| {
        data.chunks(texel)
            .flat_map(|texel| {
                texel
                    .iter()
                    .copied()
                    .chain(std::iter::repeat_n(0, to - texel.len()))
            })
            .collect()
    };
    match (format, allocation) {
        // An R32G32_FLOAT UAV's texels gain zero .zw (`storage_texture_format`).
        (F::R32G32Float, T::Rgba32Float) => pad(8, 16),
        (F::R16G16Float, T::Rgba16Float) => pad(4, 8),
        (F::R16Float, T::Rgba16Float) => pad(2, 8),
        (F::R8G8Unorm, T::Rgba8Unorm) => pad(2, 4),
        (F::R8Unorm, T::Rgba8Unorm) => pad(1, 4),
        // Unsigned 11/11/10-bit floats share binary16's exponent: each is the
        // half with its mantissa's low bits zero.
        (F::R11G11B10Float, T::Rgba16Float) => data
            .chunks_exact(4)
            .flat_map(|texel| {
                let packed = u32::from_le_bytes(texel.try_into().unwrap());
                [
                    ((packed & 2047) << 4) as u16,
                    (((packed >> 11) & 2047) << 4) as u16,
                    ((packed >> 22) << 5) as u16,
                    0,
                ]
            })
            .flat_map(u16::to_le_bytes)
            .collect(),
        (F::R8Unorm, T::R32Float) => data
            .iter()
            .flat_map(|&code| (f32::from(code) / 255.).to_le_bytes())
            .collect(),
        // A snorm of -32768 reads as -1, as -32767 does.
        (F::R16Snorm, T::R32Float) => halves(data)
            .flat_map(|code| (f32::from((code as i16).max(-32767)) / 32767.).to_le_bytes())
            .collect(),
        // A texel a component holds the same floats in the same order.
        _ => data.to_vec(),
    }
}

/// Texels read from a texture of `allocation` in the layout of the SDK's
/// `format`, which the resource's description names: what a capture or a
/// comparison with the SDK's own resource needs.
pub fn ffx_sdk_texels_wgpu(
    format: FfxSurfaceFormat,
    allocation: TextureFormat,
    data: &[u8],
) -> Vec<u8> {
    use FfxSurfaceFormat as F;
    use TextureFormat as T;
    let keep = |texel: usize, of: usize| {
        data.chunks(of)
            .flat_map(|wide| wide[..texel].iter().copied())
            .collect()
    };
    match (format, allocation) {
        (F::R32G32Float, T::Rgba32Float) => keep(8, 16),
        (F::R16G16Float, T::Rgba16Float) => keep(4, 8),
        (F::R16Float, T::Rgba16Float) => keep(2, 8),
        (F::R8G8Unorm, T::Rgba8Unorm) => keep(2, 4),
        (F::R8Unorm, T::Rgba8Unorm) => keep(1, 4),
        (F::R11G11B10Float, T::Rgba16Float) => data
            .chunks_exact(8)
            .flat_map(|texel| {
                let half = |at: usize| u32::from(u16::from_le_bytes([texel[at], texel[at + 1]]));
                ((half(0) >> 4) | ((half(2) >> 4) << 11) | ((half(4) >> 5) << 22)).to_le_bytes()
            })
            .collect(),
        (F::R8Unorm, T::R32Float) => data
            .chunks_exact(4)
            .map(|texel| (f32::from_le_bytes(texel.try_into().unwrap()) * 255.).round() as u8)
            .collect(),
        (F::R16Snorm, T::R32Float) => data
            .chunks_exact(4)
            .flat_map(|texel| {
                ((f32::from_le_bytes(texel.try_into().unwrap()) * 32767.).round() as i16)
                    .to_le_bytes()
            })
            .collect(),
        _ => data.to_vec(),
    }
}
