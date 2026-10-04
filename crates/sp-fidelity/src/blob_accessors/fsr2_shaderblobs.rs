//! Port of `sdk/src/backends/shared/blob_accessors/ffx_fsr2_shaderblobs.{h,cpp}`
//! (FidelityFX SDK 1.1.4, vendored). Functions keep the SDK's order.
//!
//! The SDK includes AMD's generated `ffx_fsr2_<pass>_pass[_wave64][_16bit]_permutations.h`
//! tables, which are not vendored: per pass and table, an `IndirectionTable`
//! from `PermutationKey::index` to a `PermutationInfo` (bytecode and DXC
//! binding reflection). Here each `PermutationInfo` holds the binding tables
//! only. They were derived by compiling the vendored pass HLSL for every key
//! (the six `FFX_FSR2_OPTION_*` values) with `FFX_HALF` 0 and 1 using
//! `sp-fidelity-oracle/tools/compile_dxc_oracle.py` (DXC 1.9.0.5399 to SPIR-V,
//! SPIRV-Cross 1.4.357.0 reflection), reading each `<pass>.reflection.json` and
//! keeping DXC's reflection order; identical binding tables share one
//! `PermutationInfo`. DXC drops unused resources, so a table depends on the
//! key: the accumulate pass on the Lanczos, low-resolution motion vector and
//! sharpening bits, every other pass on none. The 16-bit reflection equals
//! the 32-bit one except for the luminance pyramid, whose 16-bit table this
//! accessor never selects (as RCAS's outside `_GAMING_XBOX`), and a wave64
//! table has the reflection of its wave32 table, so the four tables of a pass
//! share its `PermutationInfo`s.
use super::binding;
use crate::assert::ffx_assert_fail;
use crate::error::*;
use crate::fsr2::FfxFsr2Pass;
use crate::fsr2::private::{
    FSR2_SHADER_PERMUTATION_ALLOW_FP16, FSR2_SHADER_PERMUTATION_DEPTH_INVERTED,
    FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING, FSR2_SHADER_PERMUTATION_FORCE_WAVE64,
    FSR2_SHADER_PERMUTATION_HDR_COLOR_INPUT, FSR2_SHADER_PERMUTATION_JITTER_MOTION_VECTORS,
    FSR2_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS, FSR2_SHADER_PERMUTATION_USE_LANCZOS_TYPE,
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

const DEPTH_CLIP_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const DEPTH_CLIP_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR2", 0, 1, 0)],
    srv_texture: &[
        binding("r_input_color_jittered", 7, 1, 0),
        binding("r_input_motion_vectors", 6, 1, 0),
        binding("r_input_exposure", 9, 1, 0),
        binding("r_reactive_mask", 3, 1, 0),
        binding("r_transparency_and_composition_mask", 4, 1, 0),
        binding("r_reconstructed_previous_nearest_depth", 0, 1, 0),
        binding("r_dilated_motion_vectors", 1, 1, 0),
        binding("r_previous_dilated_motion_vectors", 5, 1, 0),
        binding("r_dilatedDepth", 2, 1, 0),
    ],
    uav_texture: &[
        binding("rw_prepared_input_color", 1, 1, 0),
        binding("rw_dilated_reactive_masks", 0, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 1, 1, 0)],
}];

const RECONSTRUCT_PREVIOUS_DEPTH_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const RECONSTRUCT_PREVIOUS_DEPTH_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR2", 0, 1, 0)],
    srv_texture: &[
        binding("r_input_color_jittered", 2, 1, 0),
        binding("r_input_motion_vectors", 0, 1, 0),
        binding("r_input_depth", 1, 1, 0),
        binding("r_input_exposure", 3, 1, 0),
    ],
    uav_texture: &[
        binding("rw_reconstructed_previous_nearest_depth", 0, 1, 0),
        binding("rw_dilated_motion_vectors", 1, 1, 0),
        binding("rw_dilatedDepth", 2, 1, 0),
        binding("rw_lock_input_luma", 3, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const LOCK_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const LOCK_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR2", 0, 1, 0)],
    srv_texture: &[binding("r_lock_input_luma", 0, 1, 0)],
    uav_texture: &[
        binding("rw_reconstructed_previous_nearest_depth", 1, 1, 0),
        binding("rw_new_locks", 0, 1, 0),
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
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
            binding("rw_upscaled_output", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_lanczos_lut", 6, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
            binding("rw_upscaled_output", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
            binding("rw_upscaled_output", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_lanczos_lut", 6, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
            binding("rw_upscaled_output", 2, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_motion_vectors", 2, 1, 0),
            binding("r_input_exposure", 0, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_lanczos_lut", 6, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[binding("s_LinearClamp", 1, 1, 0)],
    },
    PermutationInfo {
        cbv: &[binding("cbFSR2", 0, 1, 0)],
        srv_texture: &[
            binding("r_input_exposure", 0, 1, 0),
            binding("r_dilated_motion_vectors", 2, 1, 0),
            binding("r_internal_upscaled_color", 3, 1, 0),
            binding("r_lock_status", 4, 1, 0),
            binding("r_prepared_input_color", 5, 1, 0),
            binding("r_luma_history", 10, 1, 0),
            binding("r_lanczos_lut", 6, 1, 0),
            binding("r_imgMips", 8, 1, 0),
            binding("r_dilated_reactive_masks", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_internal_upscaled_color", 0, 1, 0),
            binding("rw_lock_status", 1, 1, 0),
            binding("rw_new_locks", 3, 1, 0),
            binding("rw_luma_history", 4, 1, 0),
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
    cbv: &[binding("cbFSR2", 0, 1, 0), binding("cbRCAS", 1, 1, 0)],
    srv_texture: &[
        binding("r_input_exposure", 0, 1, 0),
        binding("r_rcas_input", 1, 1, 0),
    ],
    uav_texture: &[binding("rw_upscaled_output", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

const COMPUTE_LUMINANCE_PYRAMID_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const COMPUTE_LUMINANCE_PYRAMID_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[binding("cbFSR2", 0, 1, 0), binding("cbSPD", 1, 1, 0)],
    srv_texture: &[binding("r_input_color_jittered", 0, 1, 0)],
    uav_texture: &[
        binding("rw_img_mip_shading_change", 1, 1, 0),
        binding("rw_img_mip_5", 2, 1, 0),
        binding("rw_auto_exposure", 3, 1, 0),
        binding("rw_spd_global_atomic", 0, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[binding("s_LinearClamp", 1, 1, 0)],
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

const TCR_AUTOGEN_INDIRECTION_TABLE: [usize; 64] = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
const TCR_AUTOGEN_PERMUTATION_INFO: [PermutationInfo; 1] = [PermutationInfo {
    cbv: &[
        binding("cbFSR2", 0, 1, 0),
        binding("cbGenerateReactive", 1, 1, 0),
    ],
    srv_texture: &[
        binding("r_input_color_jittered", 1, 1, 0),
        binding("r_input_opaque_only", 0, 1, 0),
        binding("r_input_motion_vectors", 2, 1, 0),
        binding("r_reactive_mask", 4, 1, 0),
        binding("r_transparency_and_composition_mask", 5, 1, 0),
        binding("r_input_prev_color_pre_alpha", 46, 1, 0),
        binding("r_input_prev_color_post_alpha", 47, 1, 0),
    ],
    uav_texture: &[
        binding("rw_output_autoreactive", 0, 1, 0),
        binding("rw_output_autocomposition", 1, 1, 0),
        binding("rw_output_prev_color_pre_alpha", 2, 1, 0),
        binding("rw_output_prev_color_post_alpha", 3, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
}];

/// The `PermutationKey` bit fields in order: the `FFX_FSR2_OPTION_*` defines
/// of `POPULATE_PERMUTATION_KEY`.
const PERMUTATION_KEY_OPTIONS: &[&str] = &[
    "FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE",
    "FFX_FSR2_OPTION_HDR_COLOR_INPUT",
    "FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS",
    "FFX_FSR2_OPTION_JITTERED_MOTION_VECTORS",
    "FFX_FSR2_OPTION_INVERTED_DEPTH",
    "FFX_FSR2_OPTION_APPLY_SHARPENING",
];

/// The generated `<pass>_PermutationKey`: one bit field per option, every
/// FSR2 pass key has the same six.
#[derive(Clone, Copy, Default)]
#[expect(
    clippy::struct_excessive_bools,
    reason = "the generated key's bit fields"
)]
struct PermutationKey {
    ffx_fsr2_option_reproject_use_lanczos_type: bool,
    ffx_fsr2_option_hdr_color_input: bool,
    ffx_fsr2_option_low_resolution_motion_vectors: bool,
    ffx_fsr2_option_jittered_motion_vectors: bool,
    ffx_fsr2_option_inverted_depth: bool,
    ffx_fsr2_option_apply_sharpening: bool,
}

impl PermutationKey {
    /// `index`: the bit fields in declaration order.
    fn index(self) -> u32 {
        u32::from(self.ffx_fsr2_option_reproject_use_lanczos_type)
            | u32::from(self.ffx_fsr2_option_hdr_color_input) << 1
            | u32::from(self.ffx_fsr2_option_low_resolution_motion_vectors) << 2
            | u32::from(self.ffx_fsr2_option_jittered_motion_vectors) << 3
            | u32::from(self.ffx_fsr2_option_inverted_depth) << 4
            | u32::from(self.ffx_fsr2_option_apply_sharpening) << 5
    }
}

/// `POPULATE_PERMUTATION_KEY(options, key)`.
fn populate_permutation_key(options: u32) -> PermutationKey {
    PermutationKey {
        ffx_fsr2_option_reproject_use_lanczos_type: ffx_contains_flag(
            options,
            FSR2_SHADER_PERMUTATION_USE_LANCZOS_TYPE,
        ),
        ffx_fsr2_option_hdr_color_input: ffx_contains_flag(
            options,
            FSR2_SHADER_PERMUTATION_HDR_COLOR_INPUT,
        ),
        ffx_fsr2_option_low_resolution_motion_vectors: ffx_contains_flag(
            options,
            FSR2_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS,
        ),
        ffx_fsr2_option_jittered_motion_vectors: ffx_contains_flag(
            options,
            FSR2_SHADER_PERMUTATION_JITTER_MOTION_VECTORS,
        ),
        ffx_fsr2_option_inverted_depth: ffx_contains_flag(
            options,
            FSR2_SHADER_PERMUTATION_DEPTH_INVERTED,
        ),
        ffx_fsr2_option_apply_sharpening: ffx_contains_flag(
            options,
            FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING,
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

/// `fsr2GetTcrAutogenPassPermutationBlobByIndex`.
fn fsr2_get_tcr_autogen_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        if is_16bit {
            let table_index = TCR_AUTOGEN_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_tcr_autogen_pass",
                true,
                true,
                key,
                &TCR_AUTOGEN_PERMUTATION_INFO[table_index],
            )
        } else {
            let table_index = TCR_AUTOGEN_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_tcr_autogen_pass",
                true,
                false,
                key,
                &TCR_AUTOGEN_PERMUTATION_INFO[table_index],
            )
        }
    } else if is_16bit {
        let table_index = TCR_AUTOGEN_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_tcr_autogen_pass",
            false,
            true,
            key,
            &TCR_AUTOGEN_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = TCR_AUTOGEN_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_tcr_autogen_pass",
            false,
            false,
            key,
            &TCR_AUTOGEN_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetDepthClipPassPermutationBlobByIndex`.
fn fsr2_get_depth_clip_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        if is_16bit {
            let table_index = DEPTH_CLIP_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_depth_clip_pass",
                true,
                true,
                key,
                &DEPTH_CLIP_PERMUTATION_INFO[table_index],
            )
        } else {
            let table_index = DEPTH_CLIP_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_depth_clip_pass",
                true,
                false,
                key,
                &DEPTH_CLIP_PERMUTATION_INFO[table_index],
            )
        }
    } else if is_16bit {
        let table_index = DEPTH_CLIP_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_depth_clip_pass",
            false,
            true,
            key,
            &DEPTH_CLIP_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = DEPTH_CLIP_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_depth_clip_pass",
            false,
            false,
            key,
            &DEPTH_CLIP_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetReconstructPreviousDepthPassPermutationBlobByIndex`.
fn fsr2_get_reconstruct_previous_depth_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        if is_16bit {
            let table_index = RECONSTRUCT_PREVIOUS_DEPTH_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_reconstruct_previous_depth_pass",
                true,
                true,
                key,
                &RECONSTRUCT_PREVIOUS_DEPTH_PERMUTATION_INFO[table_index],
            )
        } else {
            let table_index = RECONSTRUCT_PREVIOUS_DEPTH_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_reconstruct_previous_depth_pass",
                true,
                false,
                key,
                &RECONSTRUCT_PREVIOUS_DEPTH_PERMUTATION_INFO[table_index],
            )
        }
    } else if is_16bit {
        let table_index = RECONSTRUCT_PREVIOUS_DEPTH_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_reconstruct_previous_depth_pass",
            false,
            true,
            key,
            &RECONSTRUCT_PREVIOUS_DEPTH_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = RECONSTRUCT_PREVIOUS_DEPTH_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_reconstruct_previous_depth_pass",
            false,
            false,
            key,
            &RECONSTRUCT_PREVIOUS_DEPTH_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetLockPassPermutationBlobByIndex`.
fn fsr2_get_lock_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        if is_16bit {
            let table_index = LOCK_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_lock_pass",
                true,
                true,
                key,
                &LOCK_PERMUTATION_INFO[table_index],
            )
        } else {
            let table_index = LOCK_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_lock_pass",
                true,
                false,
                key,
                &LOCK_PERMUTATION_INFO[table_index],
            )
        }
    } else if is_16bit {
        let table_index = LOCK_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_lock_pass",
            false,
            true,
            key,
            &LOCK_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = LOCK_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_lock_pass",
            false,
            false,
            key,
            &LOCK_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetAccumulatePassPermutationBlobByIndex`.
fn fsr2_get_accumulate_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        if is_16bit {
            let table_index = ACCUMULATE_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_accumulate_pass",
                true,
                true,
                key,
                &ACCUMULATE_PERMUTATION_INFO[table_index],
            )
        } else {
            let table_index = ACCUMULATE_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_accumulate_pass",
                true,
                false,
                key,
                &ACCUMULATE_PERMUTATION_INFO[table_index],
            )
        }
    } else if is_16bit {
        let table_index = ACCUMULATE_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_accumulate_pass",
            false,
            true,
            key,
            &ACCUMULATE_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = ACCUMULATE_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_accumulate_pass",
            false,
            false,
            key,
            &ACCUMULATE_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetRCASPassPermutationBlobByIndex`, outside `_GAMING_XBOX`: the
/// 16-bit tables are not selected.
fn fsr2_get_rcas_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        let table_index = RCAS_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_rcas_pass",
            true,
            false,
            key,
            &RCAS_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = RCAS_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_rcas_pass",
            false,
            false,
            key,
            &RCAS_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetComputeLuminancePyramidPassPermutationBlobByIndex`: the 16-bit
/// tables are not selected.
fn fsr2_get_compute_luminance_pyramid_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    _: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        let table_index = COMPUTE_LUMINANCE_PYRAMID_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_compute_luminance_pyramid_pass",
            true,
            false,
            key,
            &COMPUTE_LUMINANCE_PYRAMID_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = COMPUTE_LUMINANCE_PYRAMID_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_compute_luminance_pyramid_pass",
            false,
            false,
            key,
            &COMPUTE_LUMINANCE_PYRAMID_PERMUTATION_INFO[table_index],
        )
    }
}

/// `fsr2GetAutogenReactivePassPermutationBlobByIndex`.
fn fsr2_get_autogen_reactive_pass_permutation_blob_by_index(
    permutation_options: u32,
    is_wave64: bool,
    is_16bit: bool,
) -> FfxShaderBlob {
    let key = populate_permutation_key(permutation_options);

    if is_wave64 {
        if is_16bit {
            let table_index = AUTOGEN_REACTIVE_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_autogen_reactive_pass",
                true,
                true,
                key,
                &AUTOGEN_REACTIVE_PERMUTATION_INFO[table_index],
            )
        } else {
            let table_index = AUTOGEN_REACTIVE_INDIRECTION_TABLE[key.index() as usize];
            populate_shader_blob_ffx(
                "ffx_fsr2_autogen_reactive_pass",
                true,
                false,
                key,
                &AUTOGEN_REACTIVE_PERMUTATION_INFO[table_index],
            )
        }
    } else if is_16bit {
        let table_index = AUTOGEN_REACTIVE_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_autogen_reactive_pass",
            false,
            true,
            key,
            &AUTOGEN_REACTIVE_PERMUTATION_INFO[table_index],
        )
    } else {
        let table_index = AUTOGEN_REACTIVE_INDIRECTION_TABLE[key.index() as usize];
        populate_shader_blob_ffx(
            "ffx_fsr2_autogen_reactive_pass",
            false,
            false,
            key,
            &AUTOGEN_REACTIVE_PERMUTATION_INFO[table_index],
        )
    }
}

/// `FfxFsr2Pass` values as `FfxPass`.
const FFX_FSR2_PASS_DEPTH_CLIP: FfxPass = FfxFsr2Pass::DepthClip as FfxPass;
const FFX_FSR2_PASS_RECONSTRUCT_PREVIOUS_DEPTH: FfxPass =
    FfxFsr2Pass::ReconstructPreviousDepth as FfxPass;
const FFX_FSR2_PASS_LOCK: FfxPass = FfxFsr2Pass::Lock as FfxPass;
const FFX_FSR2_PASS_ACCUMULATE: FfxPass = FfxFsr2Pass::Accumulate as FfxPass;
const FFX_FSR2_PASS_ACCUMULATE_SHARPEN: FfxPass = FfxFsr2Pass::AccumulateSharpen as FfxPass;
const FFX_FSR2_PASS_RCAS: FfxPass = FfxFsr2Pass::Rcas as FfxPass;
const FFX_FSR2_PASS_COMPUTE_LUMINANCE_PYRAMID: FfxPass =
    FfxFsr2Pass::ComputeLuminancePyramid as FfxPass;
const FFX_FSR2_PASS_GENERATE_REACTIVE: FfxPass = FfxFsr2Pass::GenerateReactive as FfxPass;
const FFX_FSR2_PASS_TCR_AUTOGENERATE: FfxPass = FfxFsr2Pass::TcrAutogenerate as FfxPass;

/// `fsr2GetPermutationBlobByIndex`. A pass outside `FfxFsr2Pass` takes the
/// SDK's `default` path: the assertion fails and the empty blob is returned
/// with `FFX_OK`.
pub fn fsr2_get_permutation_blob_by_index(
    pass_id: FfxPass,
    permutation_options: u32,
) -> Result<FfxShaderBlob, FfxErrorCode> {
    let is_wave64 = ffx_contains_flag(permutation_options, FSR2_SHADER_PERMUTATION_FORCE_WAVE64);
    let is_16bit = ffx_contains_flag(permutation_options, FSR2_SHADER_PERMUTATION_ALLOW_FP16);

    match pass_id {
        FFX_FSR2_PASS_DEPTH_CLIP => {
            return Ok(fsr2_get_depth_clip_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR2_PASS_RECONSTRUCT_PREVIOUS_DEPTH => {
            return Ok(
                fsr2_get_reconstruct_previous_depth_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR2_PASS_LOCK => {
            return Ok(fsr2_get_lock_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR2_PASS_ACCUMULATE | FFX_FSR2_PASS_ACCUMULATE_SHARPEN => {
            return Ok(fsr2_get_accumulate_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR2_PASS_RCAS => {
            return Ok(fsr2_get_rcas_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR2_PASS_COMPUTE_LUMINANCE_PYRAMID => {
            return Ok(
                fsr2_get_compute_luminance_pyramid_pass_permutation_blob_by_index(
                    permutation_options,
                    is_wave64,
                    is_16bit,
                ),
            );
        }
        FFX_FSR2_PASS_GENERATE_REACTIVE => {
            return Ok(fsr2_get_autogen_reactive_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        FFX_FSR2_PASS_TCR_AUTOGENERATE => {
            return Ok(fsr2_get_tcr_autogen_pass_permutation_blob_by_index(
                permutation_options,
                is_wave64,
                is_16bit,
            ));
        }
        _ => ffx_assert_fail!("Should never reach here."),
    }

    // return an empty blob
    Ok(FfxShaderBlob::default())
}

/// `fsr2IsWave64`.
pub fn fsr2_is_wave64(permutation_options: u32, is_wave64: &mut bool) -> Result<(), FfxErrorCode> {
    *is_wave64 = ffx_contains_flag(permutation_options, FSR2_SHADER_PERMUTATION_FORCE_WAVE64);
    Ok(())
}
