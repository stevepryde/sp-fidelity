//! Port of `sdk/src/components/opticalflow/ffx_opticalflow_private.h`.
use super::resources::*;
use super::*;
pub const FFX_OF_BINDING_IDENTIFIER_NULL: u32 = 0;
pub const FFX_OF_BINDING_IDENTIFIER_INPUT_COLOR: u32 = 1;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT: u32 = 2;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_1: u32 = 3;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_2: u32 = 4;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_3: u32 = 5;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_4: u32 = 6;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_5: u32 = 7;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_6: u32 = 8;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS_INPUT: u32 = 9;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_HISTOGRAM: u32 = 10;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_PREVIOUS_HISTOGRAM: u32 = 11;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_TEMP: u32 = 12;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_OUTPUT: u32 = 13;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW: u32 = 14;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_NEXT_LEVEL: u32 = 15;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS: u32 = 16;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_1: u32 = 17;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_2: u32 = 18;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_3: u32 = 19;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_4: u32 = 20;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_5: u32 = 21;
pub const FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_6: u32 = 22;
pub const FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_VECTOR: u32 = 23;
pub const FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_SCD_OUTPUT: u32 = 24;
pub const FFX_OF_BINDING_IDENTIFIER_COUNT: u32 = 25;
pub const OPTICALFLOW_SHADER_PERMUTATION_FORCE_WAVE64: u32 = 1 << 0;
pub const OPTICALFLOW_SHADER_PERMUTATION_ALLOW_FP16: u32 = 1 << 1;
pub const OPTICALFLOW_HDR_COLOR_INPUT: u32 = 1 << 2;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct OpticalflowConstants {
    pub input_luma_resolution: [i32; 2],
    pub optical_flow_pyramid_level: u32,
    pub optical_flow_pyramid_level_count: u32,
    pub frame_index: i32,
    pub backbuffer_transfer_function: u32,
    pub min_max_luminance: [f32; 2],
}
impl OpticalflowConstants {
    pub const WORDS: u32 = 8;
    pub fn words(&self) -> Vec<u32> {
        let mut w = Vec::with_capacity(Self::WORDS as usize);
        w.extend(self.input_luma_resolution.map(|v| v.cast_unsigned()));
        w.push(self.optical_flow_pyramid_level);
        w.push(self.optical_flow_pyramid_level_count);
        w.push(self.frame_index.cast_unsigned());
        w.push(self.backbuffer_transfer_function);
        w.extend(self.min_max_luminance.map(|v| v.to_bits()));
        w
    }
}
pub struct FfxOpticalflowContextPrivate {
    pub context_description: FfxOpticalflowContextDescription,
    pub effect_context_id: FfxUInt32,
    pub constants: OpticalflowConstants,
    pub device: FfxDevice,
    pub device_capabilities: FfxDeviceCapabilities,
    pub pipeline_prepare_luma: FfxPipelineState,
    pub pipeline_generate_optical_flow_input_pyramid: FfxPipelineState,
    pub pipeline_generate_scd_histogram: FfxPipelineState,
    pub pipeline_compute_scd_divergence: FfxPipelineState,
    pub pipeline_compute_optical_flow_advanced_v5: FfxPipelineState,
    pub pipeline_filter_optical_flow_v5: FfxPipelineState,
    pub pipeline_scale_optical_flow_advanced_v5: FfxPipelineState,
    pub resources: [FfxResourceInternal; FFX_OF_RESOURCE_IDENTIFIER_COUNT as usize],
    pub srv_bindings: [FfxResourceInternal; FFX_OF_BINDING_IDENTIFIER_COUNT as usize],
    pub uav_bindings: [FfxResourceInternal; FFX_OF_BINDING_IDENTIFIER_COUNT as usize],
    pub constant_buffers: [FfxConstantBuffer; FFX_OPTICALFLOW_CONSTANTBUFFER_COUNT as usize],
    pub first_execution: bool,
    pub refresh_pipeline_states: bool,
    pub resource_frame_index: u32,
}
impl FfxOpticalflowContextPrivate {
    pub fn zeroed(context_description: FfxOpticalflowContextDescription) -> Self {
        Self {
            context_description,
            effect_context_id: Default::default(),
            constants: Default::default(),
            device: Default::default(),
            device_capabilities: Default::default(),
            pipeline_prepare_luma: Default::default(),
            pipeline_generate_optical_flow_input_pyramid: Default::default(),
            pipeline_generate_scd_histogram: Default::default(),
            pipeline_compute_scd_divergence: Default::default(),
            pipeline_compute_optical_flow_advanced_v5: Default::default(),
            pipeline_filter_optical_flow_v5: Default::default(),
            pipeline_scale_optical_flow_advanced_v5: Default::default(),
            resources: std::array::from_fn(|_| Default::default()),
            srv_bindings: std::array::from_fn(|_| Default::default()),
            uav_bindings: std::array::from_fn(|_| Default::default()),
            constant_buffers: std::array::from_fn(|_| Default::default()),
            first_execution: Default::default(),
            refresh_pipeline_states: Default::default(),
            resource_frame_index: Default::default(),
        }
    }
}
