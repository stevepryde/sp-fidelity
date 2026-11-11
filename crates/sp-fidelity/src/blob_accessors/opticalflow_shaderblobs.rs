//! Port of `ffx_opticalflow_shaderblobs.{h,cpp}` (FidelityFX SDK 1.1.4).
//!
//! Binding tables come from DXC 1.9.0.5399 SPIR-V reflection of every
//! vendored HLSL permutation, exported by `compile_dxc_oracle.py` and
//! SPIRV-Cross 1.4.357.0. All 1-bit keys share each pass's binding table.
//! The SDK's accessors select only FP32 tables, including when ALLOW_FP16 is
//! set. Wave64 tables retain the same bindings and a distinct wave identity.
use super::binding;
use crate::assert::ffx_assert_fail;
use crate::error::*;
use crate::interface::FfxPass;
use crate::opticalflow::FfxOpticalflowPass;
use crate::opticalflow::private::{
    OPTICALFLOW_HDR_COLOR_INPUT, OPTICALFLOW_SHADER_PERMUTATION_FORCE_WAVE64,
};
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

const OPTICALFLOW_PREPARE_LUMA_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbOF", 0, 1, 0)],
    srv_texture: &[binding("r_input_color", 0, 1, 0)],
    uav_texture: &[binding("rw_optical_flow_input", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
};

const OPTICALFLOW_GENERATE_OPTICAL_FLOW_INPUT_PYRAMID_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[],
        srv_texture: &[],
        uav_texture: &[
            binding("rw_optical_flow_input", 0, 1, 0),
            binding("rw_optical_flow_input_level_1", 1, 1, 0),
            binding("rw_optical_flow_input_level_2", 2, 1, 0),
            binding("rw_optical_flow_input_level_3", 3, 1, 0),
            binding("rw_optical_flow_input_level_4", 4, 1, 0),
            binding("rw_optical_flow_input_level_5", 5, 1, 0),
            binding("rw_optical_flow_input_level_6", 6, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[],
    };

const OPTICALFLOW_GENERATE_SCD_HISTOGRAM_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[binding("cbOF", 0, 1, 0)],
    srv_texture: &[binding("r_optical_flow_input", 0, 1, 0)],
    uav_texture: &[binding("rw_optical_flow_scd_histogram", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
};

const OPTICALFLOW_COMPUTE_SCD_DIVERGENCE_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[],
    srv_texture: &[],
    uav_texture: &[
        binding("rw_optical_flow_scd_histogram", 0, 1, 0),
        binding("rw_optical_flow_scd_previous_histogram", 1, 1, 0),
        binding("rw_optical_flow_scd_temp", 2, 1, 0),
        binding("rw_optical_flow_scd_output", 3, 1, 0),
    ],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
};

const OPTICALFLOW_COMPUTE_OPTICAL_FLOW_ADVANCED_V5_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[binding("cbOF", 0, 1, 0)],
        srv_texture: &[
            binding("r_optical_flow_input", 0, 1, 0),
            binding("r_optical_flow_previous_input", 1, 1, 0),
        ],
        uav_texture: &[
            binding("rw_optical_flow", 0, 1, 0),
            binding("rw_optical_flow_scd_output", 1, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[],
    };

const OPTICALFLOW_FILTER_OPTICAL_FLOW_V5_PERMUTATION_INFO: PermutationInfo = PermutationInfo {
    cbv: &[],
    srv_texture: &[binding("r_optical_flow_previous", 0, 1, 0)],
    uav_texture: &[binding("rw_optical_flow", 0, 1, 0)],
    srv_buffer: &[],
    uav_buffer: &[],
    sampler: &[],
};

const OPTICALFLOW_SCALE_OPTICAL_FLOW_ADVANCED_V5_PERMUTATION_INFO: PermutationInfo =
    PermutationInfo {
        cbv: &[binding("cbOF", 0, 1, 0)],
        srv_texture: &[
            binding("r_optical_flow_input", 0, 1, 0),
            binding("r_optical_flow_previous_input", 1, 1, 0),
            binding("r_optical_flow", 2, 1, 0),
        ],
        uav_texture: &[
            binding("rw_optical_flow_next_level", 0, 1, 0),
            binding("rw_optical_flow_scd_output", 1, 1, 0),
        ],
        srv_buffer: &[],
        uav_buffer: &[],
        sampler: &[],
    };

const PERMUTATION_KEY_OPTIONS: &[&str] = &["FFX_OPTICALFLOW_OPTION_HDR_COLOR_INPUT"];

/// `POPULATE_PERMUTATION_KEY`: fields in the generated key declaration order.
fn populate_permutation_key(options: u32) -> u32 {
    u32::from(ffx_contains_flag(options, OPTICALFLOW_HDR_COLOR_INPUT))
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
            wave64: ffx_contains_flag(options, OPTICALFLOW_SHADER_PERMUTATION_FORCE_WAVE64),
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

/// `opticalflowGetPermutationBlobByIndex`.
pub fn opticalflow_get_permutation_blob_by_index(
    pass_id: FfxPass,
    permutation_options: u32,
) -> Result<FfxShaderBlob, FfxErrorCode> {
    let (shader_name, info) = match pass_id {
        id if id == FfxOpticalflowPass::PrepareLuma as FfxPass => (
            "ffx_opticalflow_prepare_luma_pass",
            &OPTICALFLOW_PREPARE_LUMA_PERMUTATION_INFO,
        ),
        id if id == FfxOpticalflowPass::GenerateOpticalFlowInputPyramid as FfxPass => (
            "ffx_opticalflow_compute_luminance_pyramid_pass",
            &OPTICALFLOW_GENERATE_OPTICAL_FLOW_INPUT_PYRAMID_PERMUTATION_INFO,
        ),
        id if id == FfxOpticalflowPass::GenerateScdHistogram as FfxPass => (
            "ffx_opticalflow_generate_scd_histogram_pass",
            &OPTICALFLOW_GENERATE_SCD_HISTOGRAM_PERMUTATION_INFO,
        ),
        id if id == FfxOpticalflowPass::ComputeScdDivergence as FfxPass => (
            "ffx_opticalflow_compute_scd_divergence_pass",
            &OPTICALFLOW_COMPUTE_SCD_DIVERGENCE_PERMUTATION_INFO,
        ),
        id if id == FfxOpticalflowPass::ComputeOpticalFlowAdvancedV5 as FfxPass => (
            "ffx_opticalflow_compute_optical_flow_advanced_pass_v5",
            &OPTICALFLOW_COMPUTE_OPTICAL_FLOW_ADVANCED_V5_PERMUTATION_INFO,
        ),
        id if id == FfxOpticalflowPass::FilterOpticalFlowV5 as FfxPass => (
            "ffx_opticalflow_filter_optical_flow_pass_v5",
            &OPTICALFLOW_FILTER_OPTICAL_FLOW_V5_PERMUTATION_INFO,
        ),
        id if id == FfxOpticalflowPass::ScaleOpticalFlowAdvancedV5 as FfxPass => (
            "ffx_opticalflow_scale_optical_flow_advanced_pass_v5",
            &OPTICALFLOW_SCALE_OPTICAL_FLOW_ADVANCED_V5_PERMUTATION_INFO,
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

/// `opticalflowIsWave64`.
pub fn opticalflow_is_wave64(
    permutation_options: u32,
    is_wave64: &mut bool,
) -> Result<(), FfxErrorCode> {
    *is_wave64 = ffx_contains_flag(
        permutation_options,
        OPTICALFLOW_SHADER_PERMUTATION_FORCE_WAVE64,
    );
    Ok(())
}
