//! Reflection pass accessors from SDK 1.1.4's `ffx_denoiser_shaderblobs.cpp`.
//! Binding tables are DXC reflection of the retained pass HLSL. The two depth
//! keys and wave sizes share each pass's resources in both precision modes.
use super::binding;
use crate::assert::ffx_assert_fail;
use crate::denoiser::FfxDenoiserPass;
use crate::denoiser::private::{
    DENOISER_SHADER_PERMUTATION_ALLOW_FP16, DENOISER_SHADER_PERMUTATION_DEPTH_INVERTED,
    DENOISER_SHADER_PERMUTATION_FORCE_WAVE64,
};
use crate::error::FfxErrorCode;
use crate::interface::FfxPass;
use crate::types::*;
use crate::util::ffx_contains_flag;

const REPROJECT_SRVS: &[FfxShaderBlobBinding] = &[
    binding("r_input_depth_hierarchy", 2, 1, 0),
    binding("r_input_motion_vectors", 3, 1, 0),
    binding("r_input_normal", 4, 1, 0),
    binding("r_radiance", 7, 1, 0),
    binding("r_radiance_history", 8, 1, 0),
    binding("r_variance", 9, 1, 0),
    binding("r_sample_count", 10, 1, 0),
    binding("r_extracted_roughness", 12, 1, 0),
    binding("r_depth_history", 13, 1, 0),
    binding("r_normal_history", 14, 1, 0),
    binding("r_roughness_history", 15, 1, 0),
];

const REPROJECT_UAVS: &[FfxShaderBlobBinding] = &[
    binding("rw_variance", 1, 1, 0),
    binding("rw_sample_count", 2, 1, 0),
    binding("rw_average_radiance", 3, 1, 0),
    binding("rw_reprojected_radiance", 9, 1, 0),
];

const PREFILTER_SRVS: &[FfxShaderBlobBinding] = &[
    binding("r_input_depth_hierarchy", 2, 1, 0),
    binding("r_input_normal", 4, 1, 0),
    binding("r_radiance", 7, 1, 0),
    binding("r_variance", 9, 1, 0),
    binding("r_average_radiance", 11, 1, 0),
    binding("r_extracted_roughness", 12, 1, 0),
];

const OUTPUT_UAVS: &[FfxShaderBlobBinding] = &[
    binding("rw_radiance", 0, 1, 0),
    binding("rw_variance", 1, 1, 0),
];

const RESOLVE_SRVS: &[FfxShaderBlobBinding] = &[
    binding("r_radiance", 7, 1, 0),
    binding("r_variance", 9, 1, 0),
    binding("r_sample_count", 10, 1, 0),
    binding("r_average_radiance", 11, 1, 0),
    binding("r_extracted_roughness", 12, 1, 0),
    binding("r_reprojected_radiance", 16, 1, 0),
];

const CONSTANTS: &[FfxShaderBlobBinding] = &[binding("cbDenoiserReflections", 0, 1, 0)];

const TILES: &[FfxShaderBlobBinding] = &[binding("rw_denoiser_tile_list", 5, 1, 0)];

const SAMPLERS: &[FfxShaderBlobBinding] = &[binding("s_LinearSampler", 0, 1, 0)];

pub fn denoiser_get_permutation_blob_by_index(
    pass_id: FfxPass,
    permutation_options: u32,
) -> Result<FfxShaderBlob, FfxErrorCode> {
    let (shader_name, srv, uav) = match pass_id {
        id if id == FfxDenoiserPass::ReprojectReflections as FfxPass => (
            "ffx_denoiser_reproject_reflections_pass",
            REPROJECT_SRVS,
            REPROJECT_UAVS,
        ),
        id if id == FfxDenoiserPass::PrefilterReflections as FfxPass => (
            "ffx_denoiser_prefilter_reflections_pass",
            PREFILTER_SRVS,
            OUTPUT_UAVS,
        ),
        id if id == FfxDenoiserPass::ResolveTemporalReflections as FfxPass => (
            "ffx_denoiser_resolve_temporal_reflections_pass",
            RESOLVE_SRVS,
            OUTPUT_UAVS,
        ),
        _ => {
            ffx_assert_fail!("Should never reach here.");
            return Ok(FfxShaderBlob::default());
        }
    };
    Ok(FfxShaderBlob {
        shader_name,
        permutation: FfxShaderPermutation {
            wave64: ffx_contains_flag(
                permutation_options,
                DENOISER_SHADER_PERMUTATION_FORCE_WAVE64,
            ),
            fp16: ffx_contains_flag(permutation_options, DENOISER_SHADER_PERMUTATION_ALLOW_FP16),
            key_options: &["FFX_DENOISER_OPTION_INVERTED_DEPTH"],
            key_index: u32::from(ffx_contains_flag(
                permutation_options,
                DENOISER_SHADER_PERMUTATION_DEPTH_INVERTED,
            )),
        },
        bound_constant_buffers: CONSTANTS,
        bound_srv_textures: srv,
        bound_uav_textures: uav,
        bound_uav_buffers: TILES,
        bound_samplers: SAMPLERS,
        bound_srv_buffers: &[],
    })
}

pub fn denoiser_is_wave64(
    permutation_options: u32,
    is_wave64: &mut bool,
) -> Result<(), FfxErrorCode> {
    *is_wave64 = ffx_contains_flag(
        permutation_options,
        DENOISER_SHADER_PERMUTATION_FORCE_WAVE64,
    );
    Ok(())
}
