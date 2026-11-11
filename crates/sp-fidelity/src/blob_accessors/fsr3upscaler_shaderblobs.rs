//! Port of `sdk/src/backends/shared/blob_accessors/ffx_fsr3upscaler_shaderblobs.{h,cpp}`
//! (FidelityFX SDK 1.1.4, FSR 3.1.4, vendored).
//!
//! Binding tables come from actual DXC compilation of the unchanged vendored
//! HLSL through `sp-fidelity-oracle/tools/compile_dxc_oracle.py`: all 64 six-bit
//! keys with and without ALLOW_FP16 (DXC 1.9.0.5399 to SPIR-V, SPIRV-Cross
//! 1.4.357.0 reflection), preserving reflection order. Equal tables share one
//! `PermutationInfo`. Only accumulate varies (Lanczos, motion-vector resolution,
//! sharpening); selected 16-bit tables have the same bindings as 32-bit tables.
//! Wave64 uses the same binding tables and retains its permutation identity.
//! As in the desktop SDK accessor, prepare inputs, RCAS, both pyramids, luma
//! instability and debug view always select 32-bit tables.
use super::binding;
use crate::assert::ffx_assert_fail;
use crate::error::*;
use crate::fsr3upscaler::FfxFsr3UpscalerPass;
use crate::fsr3upscaler::private::{
    FSR3UPSCALER_SHADER_PERMUTATION_ALLOW_FP16, FSR3UPSCALER_SHADER_PERMUTATION_DEPTH_INVERTED,
    FSR3UPSCALER_SHADER_PERMUTATION_ENABLE_SHARPENING,
    FSR3UPSCALER_SHADER_PERMUTATION_FORCE_WAVE64, FSR3UPSCALER_SHADER_PERMUTATION_HDR_COLOR_INPUT,
    FSR3UPSCALER_SHADER_PERMUTATION_JITTER_MOTION_VECTORS,
    FSR3UPSCALER_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS,
    FSR3UPSCALER_SHADER_PERMUTATION_USE_LANCZOS_TYPE,
};
use crate::interface::FfxPass;
use crate::types::*;
use crate::util::ffx_contains_flag;

/// The binding tables of a generated `PermutationInfo`.
struct PermutationInfo {
    cbv: &'static [FfxShaderBlobBinding],
    srv_texture: &'static [FfxShaderBlobBinding],
    uav_texture: &'static [FfxShaderBlobBinding],
    srv_buffer: &'static [FfxShaderBlobBinding],
    uav_buffer: &'static [FfxShaderBlobBinding],
    sampler: &'static [FfxShaderBlobBinding],
}

const PREPARE_REACTIVITY_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const PREPARE_REACTIVITY_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
    srv_texture: &[
        binding("r_reactive_mask", 3, 1, 0),
        binding("r_transparency_and_composition_mask", 4, 1, 0),
        binding("r_accumulation", 5, 1, 0),
        binding("r_shading_change", 6, 1, 0),
        binding("r_current_luma", 7, 1, 0),
        binding("r_reconstructed_previous_nearest_depth", 0, 1, 0),
        binding("r_dilated_motion_vectors", 1, 1, 0),
        binding("r_dilated_depth", 2, 1, 0),
        binding("r_input_exposure", 8, 1, 0),
    ],
    uav_texture: &[
        binding("rw_accumulation", 2, 1, 0),
        binding("rw_new_locks", 1, 1, 0),
        binding("rw_dilated_reactive_masks", 0, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 1, 1, 0)],
}];

const SHADING_CHANGE_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const SHADING_CHANGE_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
    srv_texture: &[binding("r_spd_mips", 0, 1, 0)],
    uav_texture: &[binding("rw_shading_change", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 1, 1, 0)],
}];

const PREPARE_INPUTS_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const PREPARE_INPUTS_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
    srv_texture: &[
        binding("r_input_depth", 1, 1, 0),
        binding("r_input_color_jittered", 2, 1, 0),
        binding("r_input_motion_vectors", 0, 1, 0),
    ],
    uav_texture: &[
        binding("rw_farthest_depth", 3, 1, 0),
        binding("rw_current_luma", 4, 1, 0),
        binding("rw_reconstructed_previous_nearest_depth", 2, 1, 0),
        binding("rw_dilated_depth", 1, 1, 0),
        binding("rw_dilated_motion_vectors", 0, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const ACCUMULATE_INDIRECTION_TABLE: [usize; 64] = [
    0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3, 0, 1, 0, 1, 2, 3, 2, 3,
    4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7, 4, 5, 4, 5, 6, 7, 6, 7,
];
const ACCUMULATE_PERMUTATION_INFO: [PermutationInfo; 8] = [
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_upscaled_output", 1, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_lanczos_lut", 4, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_upscaled_output", 1, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_upscaled_output", 1, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_lanczos_lut", 4, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_upscaled_output", 1, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_lanczos_lut", 4, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_color_jittered", 8, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_farthest_depth_mip1", 5, 1, 0),
            binding("r_luma_instability", 7, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_lanczos_lut", 4, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_new_locks", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
];

const RCAS_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const RCAS_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbRCAS", 1, 1, 0)],
    srv_texture: &[
        binding("r_rcas_input", 1, 1, 0),
        binding("r_input_exposure", 0, 1, 0),
    ],
    uav_texture: &[binding("rw_upscaled_output", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const LUMA_PYRAMID_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const LUMA_PYRAMID_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[
        binding("cbFSR3Upscaler", 0, 1, 0),
        binding("cbSPD", 1, 1, 0),
    ],
    srv_texture: &[
        binding("r_farthest_depth", 1, 1, 0),
        binding("r_current_luma", 0, 1, 0),
    ],
    uav_texture: &[
        binding("rw_farthest_depth_mip1", 8, 1, 0),
        binding("rw_frame_info", 1, 1, 0),
        binding("rw_spd_mip5", 7, 1, 0),
        binding("rw_spd_global_atomic", 0, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const AUTOGEN_REACTIVE_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const AUTOGEN_REACTIVE_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbGenerateReactive", 1, 1, 0)],
    srv_texture: &[
        binding("r_input_color_jittered", 1, 1, 0),
        binding("r_input_opaque_only", 0, 1, 0),
    ],
    uav_texture: &[binding("rw_output_autoreactive", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const SHADING_CHANGE_PYRAMID_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const SHADING_CHANGE_PYRAMID_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[
        binding("cbFSR3Upscaler", 0, 1, 0),
        binding("cbSPD", 1, 1, 0),
    ],
    srv_texture: &[
        binding("r_current_luma", 0, 1, 0),
        binding("r_previous_luma", 1, 1, 0),
        binding("r_dilated_motion_vectors", 2, 1, 0),
        binding("r_input_exposure", 3, 1, 0),
    ],
    uav_texture: &[
        binding("rw_spd_mip0", 1, 1, 0),
        binding("rw_spd_mip1", 2, 1, 0),
        binding("rw_spd_mip2", 3, 1, 0),
        binding("rw_spd_mip3", 4, 1, 0),
        binding("rw_spd_mip4", 5, 1, 0),
        binding("rw_spd_mip5", 6, 1, 0),
        binding("rw_spd_global_atomic", 0, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const LUMA_INSTABILITY_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const LUMA_INSTABILITY_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
    srv_texture: &[
        binding("r_luma_history", 4, 1, 0),
        binding("r_current_luma", 6, 1, 0),
        binding("r_dilated_motion_vectors", 2, 1, 0),
        binding("r_input_exposure", 0, 1, 0),
        binding("r_dilated_reactive_masks", 1, 1, 0),
    ],
    uav_texture: &[
        binding("rw_luma_history", 0, 1, 0),
        binding("rw_luma_instability", 1, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 1, 1, 0)],
}];

const DEBUG_VIEW_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const DEBUG_VIEW_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR3Upscaler", 0, 1, 0)],
    srv_texture: &[
        binding("r_internal_upscaled_color", 3, 1, 0),
        binding("r_dilated_motion_vectors", 1, 1, 0),
        binding("r_dilated_depth", 2, 1, 0),
        binding("r_dilated_reactive_masks", 0, 1, 0),
    ],
    uav_texture: &[binding("rw_upscaled_output", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 1, 1, 0)],
}];

const PERMUTATION_KEY_OPTIONS: &[&str] = &[
    "FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE",
    "FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT",
    "FFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS",
    "FFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS",
    "FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH",
    "FFX_FSR3UPSCALER_OPTION_APPLY_SHARPENING",
];

/// The generated `<pass>_PermutationKey`: one bit field per option, every
/// FSR3UPSCALER pass key has the same six.
#[derive(Clone, Copy, Default)]
#[expect(
    clippy::struct_excessive_bools,
    reason = "the generated key's bit fields"
)]
struct PermutationKey {
    ffx_fsr3upscaler_option_reproject_use_lanczos_type: bool,
    ffx_fsr3upscaler_option_hdr_color_input: bool,
    ffx_fsr3upscaler_option_low_resolution_motion_vectors: bool,
    ffx_fsr3upscaler_option_jittered_motion_vectors: bool,
    ffx_fsr3upscaler_option_inverted_depth: bool,
    ffx_fsr3upscaler_option_apply_sharpening: bool,
}

impl PermutationKey {
    /// `index`: the bit fields in declaration order.
    fn index(self) -> u32 {
        u32::from(self.ffx_fsr3upscaler_option_reproject_use_lanczos_type)
            | u32::from(self.ffx_fsr3upscaler_option_hdr_color_input) << 1
            | u32::from(self.ffx_fsr3upscaler_option_low_resolution_motion_vectors) << 2
            | u32::from(self.ffx_fsr3upscaler_option_jittered_motion_vectors) << 3
            | u32::from(self.ffx_fsr3upscaler_option_inverted_depth) << 4
            | u32::from(self.ffx_fsr3upscaler_option_apply_sharpening) << 5
    }
}

/// `POPULATE_PERMUTATION_KEY(options, key)`.
fn populate_permutation_key(options: u32) -> PermutationKey {
    PermutationKey {
        ffx_fsr3upscaler_option_reproject_use_lanczos_type: ffx_contains_flag(
            options,
            FSR3UPSCALER_SHADER_PERMUTATION_USE_LANCZOS_TYPE,
        ),
        ffx_fsr3upscaler_option_hdr_color_input: ffx_contains_flag(
            options,
            FSR3UPSCALER_SHADER_PERMUTATION_HDR_COLOR_INPUT,
        ),
        ffx_fsr3upscaler_option_low_resolution_motion_vectors: ffx_contains_flag(
            options,
            FSR3UPSCALER_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS,
        ),
        ffx_fsr3upscaler_option_jittered_motion_vectors: ffx_contains_flag(
            options,
            FSR3UPSCALER_SHADER_PERMUTATION_JITTER_MOTION_VECTORS,
        ),
        ffx_fsr3upscaler_option_inverted_depth: ffx_contains_flag(
            options,
            FSR3UPSCALER_SHADER_PERMUTATION_DEPTH_INVERTED,
        ),
        ffx_fsr3upscaler_option_apply_sharpening: ffx_contains_flag(
            options,
            FSR3UPSCALER_SHADER_PERMUTATION_ENABLE_SHARPENING,
        ),
    }
}

/// `POPULATE_SHADER_BLOB_FFX(info, tableIndex)` for one of the four generated
/// tables (`_wave64_16bit`, `_wave64`, `_16bit`, plain) of a pass. The
/// bytecode is replaced by the pass and permutation identity.
fn populate_shader_blob_ffx(
    shader_name: &'static str,
    wave64: bool,
    fp16: bool,
    key: PermutationKey,
    info: &'static PermutationInfo,
) -> FfxShaderBlob {
    FfxShaderBlob {
        shader_name,
        permutation: FfxShaderPermutation {
            wave64,
            fp16,
            key_index: key.index(),
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

/// `fsr3UpscalerGetPrepareReactivityPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_prepare_reactivity_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = PREPARE_REACTIVITY_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_prepare_reactivity_pass",
        is_wave64,
        is_16bit,
        key,
        &PREPARE_REACTIVITY_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetShadingChangePassPermutationBlobByIndex`.
fn fsr3_upscaler_get_shading_change_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = SHADING_CHANGE_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_shading_change_pass",
        is_wave64,
        is_16bit,
        key,
        &SHADING_CHANGE_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetPrepareInputsPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_prepare_inputs_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = PREPARE_INPUTS_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_prepare_inputs_pass",
        is_wave64,
        false,
        key,
        &PREPARE_INPUTS_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetAccumulatePassPermutationBlobByIndex`.
fn fsr3_upscaler_get_accumulate_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = ACCUMULATE_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_accumulate_pass",
        is_wave64,
        is_16bit,
        key,
        &ACCUMULATE_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetRcasPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_rcas_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = RCAS_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_rcas_pass",
        is_wave64,
        false,
        key,
        &RCAS_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetLumaPyramidPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_luma_pyramid_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = LUMA_PYRAMID_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_luma_pyramid_pass",
        is_wave64,
        false,
        key,
        &LUMA_PYRAMID_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetAutogenReactivePassPermutationBlobByIndex`.
fn fsr3_upscaler_get_autogen_reactive_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = AUTOGEN_REACTIVE_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_autogen_reactive_pass",
        is_wave64,
        is_16bit,
        key,
        &AUTOGEN_REACTIVE_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetShadingChangePyramidPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_shading_change_pyramid_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = SHADING_CHANGE_PYRAMID_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_shading_change_pyramid_pass",
        is_wave64,
        false,
        key,
        &SHADING_CHANGE_PYRAMID_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetLumaInstabilityPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_luma_instability_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = LUMA_INSTABILITY_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_luma_instability_pass",
        is_wave64,
        false,
        key,
        &LUMA_INSTABILITY_PERMUTATION_INFO[table_index],
    )
}

/// `fsr3UpscalerGetDebugViewPassPermutationBlobByIndex`.
fn fsr3_upscaler_get_debug_view_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);
    let table_index = DEBUG_VIEW_INDIRECTION_TABLE[key.index() as usize];
    populate_shader_blob_ffx(
        "ffx_fsr3upscaler_debug_view_pass",
        is_wave64,
        false,
        key,
        &DEBUG_VIEW_PERMUTATION_INFO[table_index],
    )
}

/// `FfxFsr3UpscalerPass` values as `FfxPass`.
const FFX_FSR3UPSCALER_PASS_PREPARE_REACTIVITY: FfxPass =
    FfxFsr3UpscalerPass::PrepareReactivity as FfxPass;
const FFX_FSR3UPSCALER_PASS_SHADING_CHANGE: FfxPass = FfxFsr3UpscalerPass::ShadingChange as FfxPass;
const FFX_FSR3UPSCALER_PASS_PREPARE_INPUTS: FfxPass = FfxFsr3UpscalerPass::PrepareInputs as FfxPass;
const FFX_FSR3UPSCALER_PASS_ACCUMULATE: FfxPass = FfxFsr3UpscalerPass::Accumulate as FfxPass;
const FFX_FSR3UPSCALER_PASS_RCAS: FfxPass = FfxFsr3UpscalerPass::Rcas as FfxPass;
const FFX_FSR3UPSCALER_PASS_LUMA_PYRAMID: FfxPass = FfxFsr3UpscalerPass::LumaPyramid as FfxPass;
const FFX_FSR3UPSCALER_PASS_GENERATE_REACTIVE: FfxPass =
    FfxFsr3UpscalerPass::GenerateReactive as FfxPass;
const FFX_FSR3UPSCALER_PASS_SHADING_CHANGE_PYRAMID: FfxPass =
    FfxFsr3UpscalerPass::ShadingChangePyramid as FfxPass;
const FFX_FSR3UPSCALER_PASS_LUMA_INSTABILITY: FfxPass =
    FfxFsr3UpscalerPass::LumaInstability as FfxPass;
const FFX_FSR3UPSCALER_PASS_DEBUG_VIEW: FfxPass = FfxFsr3UpscalerPass::DebugView as FfxPass;
const FFX_FSR3UPSCALER_PASS_ACCUMULATE_SHARPEN: FfxPass =
    FfxFsr3UpscalerPass::AccumulateSharpen as FfxPass;

/// `fsr3UpscalerGetPermutationBlobByIndex`. Deprecated TCR and invalid passes
/// take the SDK default path: assertion failure, then an empty blob and `FFX_OK`.
pub fn fsr3_upscaler_get_permutation_blob_by_index(
    pass_id: FfxPass,
    permutation_options: u32,
) -> Result<FfxShaderBlob, FfxErrorCode> {
    let is_wave64 = ffx_contains_flag(
        permutation_options,
        FSR3UPSCALER_SHADER_PERMUTATION_FORCE_WAVE64,
    );
    let is_16bit = ffx_contains_flag(
        permutation_options,
        FSR3UPSCALER_SHADER_PERMUTATION_ALLOW_FP16,
    );

    match pass_id {
        FFX_FSR3UPSCALER_PASS_PREPARE_INPUTS => {
            return Ok(
                fsr3_upscaler_get_prepare_inputs_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_PREPARE_REACTIVITY => {
            return Ok(
                fsr3_upscaler_get_prepare_reactivity_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_SHADING_CHANGE => {
            return Ok(
                fsr3_upscaler_get_shading_change_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_ACCUMULATE | FFX_FSR3UPSCALER_PASS_ACCUMULATE_SHARPEN => {
            return Ok(fsr3_upscaler_get_accumulate_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR3UPSCALER_PASS_RCAS => {
            return Ok(fsr3_upscaler_get_rcas_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR3UPSCALER_PASS_LUMA_PYRAMID => {
            return Ok(
                fsr3_upscaler_get_luma_pyramid_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_GENERATE_REACTIVE => {
            return Ok(
                fsr3_upscaler_get_autogen_reactive_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_SHADING_CHANGE_PYRAMID => {
            return Ok(
                fsr3_upscaler_get_shading_change_pyramid_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_LUMA_INSTABILITY => {
            return Ok(
                fsr3_upscaler_get_luma_instability_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR3UPSCALER_PASS_DEBUG_VIEW => {
            return Ok(fsr3_upscaler_get_debug_view_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        _ => ffx_assert_fail!("Should never reach here."),
    }

    Ok(FfxShaderBlob::default())
}

/// `fsr3UpscalerIsWave64`.
pub fn fsr3_upscaler_is_wave64(
    permutation_options: u32,
    is_wave64: &mut bool,
) -> Result<(), FfxErrorCode> {
    *is_wave64 = ffx_contains_flag(
        permutation_options,
        FSR3UPSCALER_SHADER_PERMUTATION_FORCE_WAVE64,
    );
    Ok(())
}
