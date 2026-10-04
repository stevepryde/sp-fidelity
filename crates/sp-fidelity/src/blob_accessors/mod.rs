//! Port of the SDK backend blob accessors (FidelityFX SDK 1.1.4, vendored
//! under `vendor/sdk-1.1.4/sdk/src/backends/shared/`): `ffx_shader_blobs.{h,cpp}`
//! here, one submodule per `blob_accessors/ffx_<effect>_shaderblobs.{h,cpp}`.
//!
//! The generated `*_permutations.h` tables are SDK build outputs and are not
//! vendored. AMD generates their binding reflection with DXC from the pass
//! HLSL; an effect's tables are transcribed from the same DXC reflection of the
//! vendored pass HLSL (`sp-fidelity-oracle/tools/compile_dxc_oracle.py`), in
//! reflection order; each submodule records how.
use super::assert::ffx_assert_message;
use super::error::*;
use super::interface::FfxPass;
use super::types::*;

pub mod fsr2_shaderblobs;

/// `ffxGetPermutationBlobByIndex`, for the effects this crate ports. Any
/// other effect takes the SDK's `default` path: the assertion fails and the
/// empty blob is returned with `FFX_OK` (breadcrumbs returns it without the
/// assertion, as in the SDK).
pub fn ffx_get_permutation_blob_by_index(
    effect_id: FfxEffect,
    pass_id: FfxPass,
    _stage_id: FfxBindStage,
    permutation_options: u32,
) -> Result<FfxShaderBlob, FfxErrorCode> {
    match effect_id {
        FfxEffect::Fsr2 => {
            return fsr2_shaderblobs::fsr2_get_permutation_blob_by_index(
                pass_id,
                permutation_options,
            );
        }
        FfxEffect::Breadcrumbs => {}
        _ => ffx_assert_message!(false, "Not implemented"),
    }

    // return an empty blob
    Ok(FfxShaderBlob::default())
}

/// `ffxIsWave64`, for the effects this crate ports. Any other effect takes the
/// SDK's `default` path.
pub fn ffx_is_wave64(
    effect_id: FfxEffect,
    permutation_options: u32,
    is_wave64: &mut bool,
) -> Result<(), FfxErrorCode> {
    match effect_id {
        FfxEffect::Fsr2 => {
            return fsr2_shaderblobs::fsr2_is_wave64(permutation_options, is_wave64);
        }
        FfxEffect::Breadcrumbs => {
            *is_wave64 = false;
            return Ok(());
        }
        _ => {
            ffx_assert_message!(false, "Not implemented");
            *is_wave64 = false;
        }
    }

    Err(FFX_ERROR_BACKEND_API_ERROR)
}

/// One `FfxShaderBlob` binding-table entry.
pub(crate) const fn binding(
    name: &'static str,
    binding: u32,
    count: u32,
    space: u32,
) -> FfxShaderBlobBinding {
    FfxShaderBlobBinding {
        name,
        binding,
        count,
        space,
    }
}
