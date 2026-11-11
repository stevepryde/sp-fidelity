//! Port of `components/fsr3upscaler/ffx_fsr3upscaler_private.h` (SDK 1.1.4).
use super::FfxFsr3UpscalerContextDescription;
use super::resources::{
    FFX_FSR3UPSCALER_CONSTANTBUFFER_COUNT, FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_COUNT,
};
use crate::types::*;

pub const FSR3UPSCALER_SHADER_PERMUTATION_USE_LANCZOS_TYPE: u32 = 1 << 0;
pub const FSR3UPSCALER_SHADER_PERMUTATION_HDR_COLOR_INPUT: u32 = 1 << 1;
pub const FSR3UPSCALER_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS: u32 = 1 << 2;
pub const FSR3UPSCALER_SHADER_PERMUTATION_JITTER_MOTION_VECTORS: u32 = 1 << 3;
pub const FSR3UPSCALER_SHADER_PERMUTATION_DEPTH_INVERTED: u32 = 1 << 4;
pub const FSR3UPSCALER_SHADER_PERMUTATION_ENABLE_SHARPENING: u32 = 1 << 5;
pub const FSR3UPSCALER_SHADER_PERMUTATION_FORCE_WAVE64: u32 = 1 << 6;
pub const FSR3UPSCALER_SHADER_PERMUTATION_ALLOW_FP16: u32 = 1 << 7;

/// The 37-word SDK `cbFSR3Upscaler` constant buffer.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Fsr3UpscalerConstants {
    pub render_size: [i32; 2],
    pub previous_frame_render_size: [i32; 2],
    pub upscale_size: [i32; 2],
    pub previous_frame_upscale_size: [i32; 2],
    pub max_render_size: [i32; 2],
    pub max_upscale_size: [i32; 2],
    pub device_to_view_depth: [f32; 4],
    pub jitter_offset: [f32; 2],
    pub previous_frame_jitter_offset: [f32; 2],
    pub motion_vector_scale: [f32; 2],
    pub downscale_factor: [f32; 2],
    pub motion_vector_jitter_cancellation: [f32; 2],
    pub tan_half_fov: f32,
    pub jitter_phase_count: f32,
    pub delta_time: f32,
    pub delta_pre_exposure: f32,
    pub view_space_to_meters_factor: f32,
    pub frame_index: f32,
    pub velocity_factor: f32,
    pub reactiveness_scale: f32,
    pub shading_change_scale: f32,
    pub accumulation_added_per_frame: f32,
    pub min_disocclusion_accumulation: f32,
}

impl Fsr3UpscalerConstants {
    pub const WORDS: u32 = 37;

    pub fn words(&self) -> Vec<u32> {
        let mut words = Vec::with_capacity(Self::WORDS as usize);
        words.extend(self.render_size.map(i32::cast_unsigned));
        words.extend(self.previous_frame_render_size.map(i32::cast_unsigned));
        words.extend(self.upscale_size.map(i32::cast_unsigned));
        words.extend(self.previous_frame_upscale_size.map(i32::cast_unsigned));
        words.extend(self.max_render_size.map(i32::cast_unsigned));
        words.extend(self.max_upscale_size.map(i32::cast_unsigned));
        words.extend(self.device_to_view_depth.map(f32::to_bits));
        words.extend(self.jitter_offset.map(f32::to_bits));
        words.extend(self.previous_frame_jitter_offset.map(f32::to_bits));
        words.extend(self.motion_vector_scale.map(f32::to_bits));
        words.extend(self.downscale_factor.map(f32::to_bits));
        words.extend(self.motion_vector_jitter_cancellation.map(f32::to_bits));
        words.push(self.tan_half_fov.to_bits());
        words.push(self.jitter_phase_count.to_bits());
        words.push(self.delta_time.to_bits());
        words.push(self.delta_pre_exposure.to_bits());
        words.push(self.view_space_to_meters_factor.to_bits());
        words.push(self.frame_index.to_bits());
        words.push(self.velocity_factor.to_bits());
        words.push(self.reactiveness_scale.to_bits());
        words.push(self.shading_change_scale.to_bits());
        words.push(self.accumulation_added_per_frame.to_bits());
        words.push(self.min_disocclusion_accumulation.to_bits());
        words
    }
}

pub struct FfxFsr3UpscalerContextPrivate {
    pub context_description: FfxFsr3UpscalerContextDescription,
    pub effect_context_id: u32,
    pub constants: Fsr3UpscalerConstants,
    pub device: FfxDevice,
    pub device_capabilities: FfxDeviceCapabilities,
    pub pipeline_prepare_inputs: FfxPipelineState,
    pub pipeline_prepare_reactivity: FfxPipelineState,
    pub pipeline_shading_change: FfxPipelineState,
    pub pipeline_accumulate: FfxPipelineState,
    pub pipeline_accumulate_sharpen: FfxPipelineState,
    pub pipeline_rcas: FfxPipelineState,
    pub pipeline_luma_pyramid: FfxPipelineState,
    pub pipeline_generate_reactive: FfxPipelineState,
    pub pipeline_tcr_autogenerate: FfxPipelineState,
    pub pipeline_shading_change_pyramid: FfxPipelineState,
    pub pipeline_luma_instability: FfxPipelineState,
    pub pipeline_debug_view: FfxPipelineState,
    pub constant_buffers: [FfxConstantBuffer; FFX_FSR3UPSCALER_CONSTANTBUFFER_COUNT as usize],
    pub srv_resources: [FfxResourceInternal; FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_COUNT as usize],
    pub uav_resources: [FfxResourceInternal; FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_COUNT as usize],
    pub first_execution: bool,
    pub resource_frame_index: u32,
    pub previous_jitter_offset: [f32; 2],
    pub pre_exposure: f32,
    pub previous_frame_pre_exposure: f32,
}

impl FfxFsr3UpscalerContextPrivate {
    pub fn zeroed(context_description: FfxFsr3UpscalerContextDescription) -> Self {
        Self {
            context_description,
            effect_context_id: 0,
            constants: Fsr3UpscalerConstants::default(),
            device: 0,
            device_capabilities: FfxDeviceCapabilities::default(),
            pipeline_prepare_inputs: FfxPipelineState::default(),
            pipeline_prepare_reactivity: FfxPipelineState::default(),
            pipeline_shading_change: FfxPipelineState::default(),
            pipeline_accumulate: FfxPipelineState::default(),
            pipeline_accumulate_sharpen: FfxPipelineState::default(),
            pipeline_rcas: FfxPipelineState::default(),
            pipeline_luma_pyramid: FfxPipelineState::default(),
            pipeline_generate_reactive: FfxPipelineState::default(),
            pipeline_tcr_autogenerate: FfxPipelineState::default(),
            pipeline_shading_change_pyramid: FfxPipelineState::default(),
            pipeline_luma_instability: FfxPipelineState::default(),
            pipeline_debug_view: FfxPipelineState::default(),
            constant_buffers: Default::default(),
            srv_resources: [FfxResourceInternal::default();
                FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_COUNT as usize],
            uav_resources: [FfxResourceInternal::default();
                FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_COUNT as usize],
            first_execution: false,
            resource_frame_index: 0,
            previous_jitter_offset: [0.0; 2],
            pre_exposure: 0.0,
            previous_frame_pre_exposure: 0.0,
        }
    }
}
