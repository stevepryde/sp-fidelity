//! Port of `ffx_frameinterpolation_shaderblobs.{h,cpp}` (FidelityFX SDK 1.1.4).
//!
//! Original SDK binding tables come from DXC 1.9.0.5399 SPIR-V reflection of every
//! vendored HLSL permutation, exported by `compile_dxc_oracle.py` and
//! SPIRV-Cross 1.4.357.0. All 3-bit keys share each pass's binding table.
//! The SDK's accessors select only FP32 tables, including when ALLOW_FP16 is
//! set. Wave64 tables retain the same bindings and a distinct wave identity.
//! The optional outgoing-geometry extension has its own WGSL binding table.
use super::binding;
use crate::assert::ffx_assert_fail;
use crate::error::*;
use crate::frameinterpolation::FfxFrameInterpolationPass;
use crate::frameinterpolation::private::{
    FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED,
    FRAMEINTERPOLATION_SHADER_PERMUTATION_FORCE_WAVE64,
    FRAMEINTERPOLATION_SHADER_PERMUTATION_JITTER_MOTION_VECTORS,
    FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS,
};
use crate::interface::FfxPass;
use crate::types::*;
use crate::util::ffx_contains_flag;

struct PermutationInfo {
    cbv: &'static [FfxShaderBlobBinding],
    srv_texture: &'static [FfxShaderBlobBinding],
    uav_texture: &'static [FfxShaderBlobBinding],
    srv_buffer: &'static [FfxShaderBlobBinding],
    uav_buffer: &'static [FfxShaderBlobBinding],
    sampler: &'static [FfxShaderBlobBinding],
}

const FRAMEINTERPOLATION_RECONSTRUCT_AND_DILATE_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[binding("cbFI", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_depth", 1, 1, 0),
            binding("r_input_motion_vectors", 0, 1, 0),
        ],
        uav_texture: &[
            binding("rw_dilated_motion_vectors", 1, 1, 0),
            binding("rw_dilated_depth", 2, 1, 0),
            binding("rw_reconstructed_depth_previous_frame", 0, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[],
    };

const FRAMEINTERPOLATION_SETUP_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0)],
    srv_texture: &[binding("r_optical_flow_scd", 0, 1, 0)],
    uav_texture: &[
        binding("rw_disocclusion_mask", 4, 1, 0),
        binding("rw_game_motion_vector_field_x", 0, 1, 0),
        binding("rw_game_motion_vector_field_y", 1, 1, 0),
        binding("rw_optical_flow_motion_vector_field_x", 2, 1, 0),
        binding("rw_optical_flow_motion_vector_field_y", 3, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[binding("rw_counters", 5, 1, 0)],
    sampler: &[],
};

const FRAMEINTERPOLATION_RECONSTRUCT_PREV_DEPTH_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[binding("cbFI", 0, 1, 0)],
        srv_texture: &[
            binding("r_dilated_motion_vectors", 0, 1, 0),
            binding("r_dilated_depth", 1, 1, 0),
            binding("r_input_distortion_field", 3, 1, 0),
        ],
        uav_texture: &[binding(
            "rw_reconstructed_depth_interpolated_frame",
            0,
            1,
            0,
        )],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 0, 1, 0)],
    };

const FRAMEINTERPOLATION_GAME_MOTION_VECTOR_FIELD_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[binding("cbFI", 0, 1, 0)],
        srv_texture: &[
            binding("r_previous_interpolation_source", 2, 1, 0),
            binding("r_current_interpolation_source", 3, 1, 0),
            binding("r_dilated_motion_vectors", 0, 1, 0),
            binding("r_dilated_depth", 1, 1, 0),
            binding("r_input_distortion_field", 4, 1, 0),
        ],
        uav_texture: &[
            binding("rw_game_motion_vector_field_x", 0, 1, 0),
            binding("rw_game_motion_vector_field_y", 1, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 0, 1, 0)],
    };

const FRAMEINTERPOLATION_OPTICAL_FLOW_VECTOR_FIELD_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[binding("cbFI", 0, 1, 0)],
        srv_texture: &[
            binding("r_previous_interpolation_source", 3, 1, 0),
            binding("r_current_interpolation_source", 4, 1, 0),
            binding("r_optical_flow", 0, 1, 0),
        ],
        uav_texture: &[
            binding("rw_optical_flow_motion_vector_field_x", 0, 1, 0),
            binding("rw_optical_flow_motion_vector_field_y", 1, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 0, 1, 0)],
    };

const FRAMEINTERPOLATION_DISOCCLUSION_MASK_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0)],
    srv_texture: &[
        binding("r_dilated_depth", 3, 1, 0),
        binding("r_reconstructed_depth_previous_frame", 2, 1, 0),
        binding("r_reconstructed_depth_interpolated_frame", 4, 1, 0),
        binding("r_game_motion_vector_field_x", 0, 1, 0),
        binding("r_game_motion_vector_field_y", 1, 1, 0),
        binding("r_inpainting_pyramid", 5, 1, 0),
        binding("r_input_distortion_field", 6, 1, 0),
    ],
    uav_texture: &[binding("rw_disocclusion_mask", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 0, 1, 0)],
};

const FRAMEINTERPOLATION_INTERPOLATION_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0)],
    srv_texture: &[
        binding("r_previous_interpolation_source", 4, 1, 0),
        binding("r_current_interpolation_source", 5, 1, 0),
        binding("r_disocclusion_mask", 6, 1, 0),
        binding("r_game_motion_vector_field_x", 0, 1, 0),
        binding("r_game_motion_vector_field_y", 1, 1, 0),
        binding("r_optical_flow_motion_vector_field_x", 2, 1, 0),
        binding("r_optical_flow_motion_vector_field_y", 3, 1, 0),
        binding("r_inpainting_pyramid", 7, 1, 0),
    ],
    uav_texture: &[binding("rw_output", 0, 1, 0)],
    srv_buffer: &[binding("r_counters", 8, 1, 0)],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 0, 1, 0)],
};

const FRAMEINTERPOLATION_INPAINTING_PYRAMID_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[
        binding("cbFI", 0, 1, 0),
        binding("cbInpaintingPyramid", 1, 1, 0),
    ],
    srv_texture: &[binding("r_output", 0, 1, 0)],
    uav_texture: &[
        binding("rw_inpainting_pyramid0", 1, 1, 0),
        binding("rw_inpainting_pyramid1", 2, 1, 0),
        binding("rw_inpainting_pyramid2", 3, 1, 0),
        binding("rw_inpainting_pyramid3", 4, 1, 0),
        binding("rw_inpainting_pyramid4", 5, 1, 0),
        binding("rw_inpainting_pyramid5", 6, 1, 0),
        binding("rw_inpainting_pyramid6", 7, 1, 0),
        binding("rw_inpainting_pyramid7", 8, 1, 0),
        binding("rw_inpainting_pyramid8", 9, 1, 0),
        binding("rw_inpainting_pyramid9", 10, 1, 0),
        binding("rw_inpainting_pyramid10", 11, 1, 0),
        binding("rw_inpainting_pyramid11", 12, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[binding("rw_counters", 0, 1, 0)],
    sampler: &[],
};

const FRAMEINTERPOLATION_INPAINTING_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0)],
    srv_texture: &[
        binding("r_current_interpolation_source", 3, 1, 0),
        binding("r_optical_flow_scd", 0, 1, 0),
        binding("r_inpainting_pyramid", 1, 1, 0),
        binding("r_present_backbuffer", 2, 1, 0),
    ],
    uav_texture: &[binding("rw_output", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
};

const FRAMEINTERPOLATION_GAME_VECTOR_FIELD_INPAINTING_PYRAMID_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[
            binding("cbFI", 0, 1, 0),
            binding("cbInpaintingPyramid", 1, 1, 0),
        ],
        srv_texture: &[
            binding("r_game_motion_vector_field_x", 0, 1, 0),
            binding("r_game_motion_vector_field_y", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_inpainting_pyramid0", 1, 1, 0),
            binding("rw_inpainting_pyramid1", 2, 1, 0),
            binding("rw_inpainting_pyramid2", 3, 1, 0),
            binding("rw_inpainting_pyramid3", 4, 1, 0),
            binding("rw_inpainting_pyramid4", 5, 1, 0),
            binding("rw_inpainting_pyramid5", 6, 1, 0),
            binding("rw_inpainting_pyramid6", 7, 1, 0),
            binding("rw_inpainting_pyramid7", 8, 1, 0),
            binding("rw_inpainting_pyramid8", 9, 1, 0),
            binding("rw_inpainting_pyramid9", 10, 1, 0),
            binding("rw_inpainting_pyramid10", 11, 1, 0),
            binding("rw_inpainting_pyramid11", 12, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[binding("rw_counters", 0, 1, 0)],
        sampler: &[],
    };

const FRAMEINTERPOLATION_DEBUG_VIEW_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0)],
    srv_texture: &[
        binding("r_current_interpolation_source", 7, 1, 0),
        binding("r_disocclusion_mask", 4, 1, 0),
        binding("r_game_motion_vector_field_x", 0, 1, 0),
        binding("r_game_motion_vector_field_y", 1, 1, 0),
        binding("r_optical_flow_motion_vector_field_x", 2, 1, 0),
        binding("r_optical_flow_motion_vector_field_y", 3, 1, 0),
        binding("r_inpainting_pyramid", 6, 1, 0),
        binding("r_present_backbuffer", 5, 1, 0),
        binding("r_input_distortion_field", 8, 1, 0),
    ],
    uav_texture: &[binding("rw_output", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 0, 1, 0)],
};

// Port extension; the original AMD pass tables remain unchanged.
const FRAMEINTERPOLATION_OUTGOING_GEOMETRY: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0), binding("cbEdge", 1, 1, 0)],
    srv_texture: &[
        binding("r_edge_previous_depth", 0, 1, 0),
        binding("r_edge_previous_motion", 1, 1, 0),
    ],
    uav_texture: &[
        binding("rw_game_motion_vector_field_x", 0, 1, 0),
        binding("rw_game_motion_vector_field_y", 1, 1, 0),
        binding("rw_reconstructed_depth_interpolated_frame", 2, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
};

const FRAMEINTERPOLATION_CAMERA_VISIBILITY: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbFI", 0, 1, 0), binding("cbEdge", 1, 1, 0)],
    srv_texture: &[
        binding("r_dilated_depth", 3, 1, 0),
        binding("r_reconstructed_depth_previous_frame", 2, 1, 0),
        binding("r_reconstructed_depth_interpolated_frame", 4, 1, 0),
        binding("r_game_motion_vector_field_x", 0, 1, 0),
        binding("r_game_motion_vector_field_y", 1, 1, 0),
        binding("r_inpainting_pyramid", 5, 1, 0),
        binding("r_input_distortion_field", 6, 1, 0),
        binding("r_edge_previous_depth", 7, 1, 0),
        binding("r_edge_previous_motion", 8, 1, 0),
    ],
    uav_texture: &[binding("rw_disocclusion_mask", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 0, 1, 0)],
};

const PERMUTATION_KEY_OPTIONS: &[&str] = &[
    "FFX_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS",
    "FFX_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS",
    "FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH",
];

/// `POPULATE_PERMUTATION_KEY`: fields in the generated key declaration order.
fn populate_permutation_key(options: u32) -> u32 {
    u32::from(ffx_contains_flag(
        options,
        FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS,
    )) | u32::from(ffx_contains_flag(
        options,
        FRAMEINTERPOLATION_SHADER_PERMUTATION_JITTER_MOTION_VECTORS,
    )) << 1
        | u32::from(ffx_contains_flag(
            options,
            FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED,
        )) << 2
}

/// `POPULATE_SHADER_BLOB_FFX`, with bytecode replaced by shader identity.
fn populate_shader_blob_ffx(
    shader_name: &'static str,
    options: u32,
    info: &'static PermutationInfo,
) -> FfxShaderBlob {
    FfxShaderBlob {
        shader_name,
        permutation: FfxShaderPermutation {
            wave64: ffx_contains_flag(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_FORCE_WAVE64),
            fp16: false,
            key_index: populate_permutation_key(options),
            key_options: PERMUTATION_KEY_OPTIONS,
        },
        bound_constant_buffers: info.cbv,
        bound_srv_textures: info.srv_texture,
        bound_uav_textures: info.uav_texture,
        bound_srv_buffers: info.srv_buffer,
        bound_uav_buffers: info.uav_buffer,
        bound_samplers: info.sampler,
    }
}

/// `frameInterpolationGetPermutationBlobByIndex`.
pub fn frame_interpolation_get_permutation_blob_by_index(
    pass_id: FfxPass,
    _stage_id: FfxBindStage,
    permutation_options: u32,
) -> Result<FfxShaderBlob, FfxErrorCode> {
    let (shader_name, info) = match pass_id {
        id if id == FfxFrameInterpolationPass::ReconstructAndDilate as FfxPass => (
            "ffx_frameinterpolation_reconstruct_and_dilate_pass",
            &FRAMEINTERPOLATION_RECONSTRUCT_AND_DILATE_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::Setup as FfxPass => (
            "ffx_frameinterpolation_setup_pass",
            &FRAMEINTERPOLATION_SETUP_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::ReconstructPrevDepth as FfxPass => (
            "ffx_frameinterpolation_reconstruct_previous_depth_pass",
            &FRAMEINTERPOLATION_RECONSTRUCT_PREV_DEPTH_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::GameMotionVectorField as FfxPass => (
            "ffx_frameinterpolation_game_motion_vector_field_pass",
            &FRAMEINTERPOLATION_GAME_MOTION_VECTOR_FIELD_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::OpticalFlowVectorField as FfxPass => (
            "ffx_frameinterpolation_optical_flow_vector_field_pass",
            &FRAMEINTERPOLATION_OPTICAL_FLOW_VECTOR_FIELD_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::DisocclusionMask as FfxPass => (
            "ffx_frameinterpolation_disocclusion_mask_pass",
            &FRAMEINTERPOLATION_DISOCCLUSION_MASK_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::Interpolation as FfxPass => (
            "ffx_frameinterpolation_pass",
            &FRAMEINTERPOLATION_INTERPOLATION_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::InpaintingPyramid as FfxPass => (
            "ffx_frameinterpolation_compute_inpainting_pyramid_pass",
            &FRAMEINTERPOLATION_INPAINTING_PYRAMID_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::Inpainting as FfxPass => (
            "ffx_frameinterpolation_inpainting_pass",
            &FRAMEINTERPOLATION_INPAINTING_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::GameVectorFieldInpaintingPyramid as FfxPass => (
            "ffx_frameinterpolation_compute_game_vector_field_inpainting_pyramid_pass",
            &FRAMEINTERPOLATION_GAME_VECTOR_FIELD_INPAINTING_PYRAMID_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::DebugView as FfxPass => (
            "ffx_frameinterpolation_debug_view_pass",
            &FRAMEINTERPOLATION_DEBUG_VIEW_PERMUTATION_INFO,
        ),
        id if id == FfxFrameInterpolationPass::ReconstructOutgoingGeometry as FfxPass => (
            "ffx_frameinterpolation_reconstruct_outgoing_geometry_pass",
            &FRAMEINTERPOLATION_OUTGOING_GEOMETRY,
        ),
        id if id == FfxFrameInterpolationPass::DisocclusionWithCameraVisibility as FfxPass => (
            "ffx_frameinterpolation_disocclusion_camera_pass",
            &FRAMEINTERPOLATION_CAMERA_VISIBILITY,
        ),
        _ => {
            ffx_assert_fail!("Should never reach here.");
            return Ok(FfxShaderBlob::default());
        }
    };
    Ok(populate_shader_blob_ffx(
        shader_name,
        permutation_options,
        info,
    ))
}

/// `frameInterpolationIsWave64`.
pub fn frame_interpolation_is_wave64(
    permutation_options: u32,
    is_wave64: &mut bool,
) -> Result<(), FfxErrorCode> {
    *is_wave64 = ffx_contains_flag(
        permutation_options,
        FRAMEINTERPOLATION_SHADER_PERMUTATION_FORCE_WAVE64,
    );
    Ok(())
}
