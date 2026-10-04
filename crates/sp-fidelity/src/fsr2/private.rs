//! Port of `sdk/src/components/fsr2/ffx_fsr2_private.h` (FidelityFX SDK 1.1.4).
use super::FfxFsr2ContextDescription;
use super::resources::FFX_FSR2_RESOURCE_IDENTIFIER_COUNT;
use crate::types::*;

/// `Fs2ShaderPermutationOptions`.
///
/// Off means reference, On means LUT
pub const FSR2_SHADER_PERMUTATION_USE_LANCZOS_TYPE: u32 = 1 << 0;
/// Enables the HDR code path
pub const FSR2_SHADER_PERMUTATION_HDR_COLOR_INPUT: u32 = 1 << 1;
/// Indicates low resolution motion vectors provided
pub const FSR2_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS: u32 = 1 << 2;
/// Indicates motion vectors were generated with jitter
pub const FSR2_SHADER_PERMUTATION_JITTER_MOTION_VECTORS: u32 = 1 << 3;
/// Indicates input resources were generated with inverted depth
pub const FSR2_SHADER_PERMUTATION_DEPTH_INVERTED: u32 = 1 << 4;
/// Enables a supplementary sharpening pass
pub const FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING: u32 = 1 << 5;
/// doesn't map to a define, selects different table
pub const FSR2_SHADER_PERMUTATION_FORCE_WAVE64: u32 = 1 << 6;
/// Enables fast math computations where possible
pub const FSR2_SHADER_PERMUTATION_ALLOW_FP16: u32 = 1 << 7;

/// `Fsr2Constants`: constants for FSR2 dispatches. Must be kept in sync with
/// cbFSR2 in `ffx_fsr2_callbacks_hlsl.h`.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Fsr2Constants {
    pub render_size: [i32; 2],
    pub max_render_size: [i32; 2],
    pub display_size: [i32; 2],
    pub input_color_resource_dimensions: [i32; 2],
    pub luma_mip_dimensions: [i32; 2],
    pub luma_mip_level_to_use: i32,
    pub frame_index: i32,

    pub device_to_view_depth: [f32; 4],
    pub jitter_offset: [f32; 2],
    pub motion_vector_scale: [f32; 2],
    pub downscale_factor: [f32; 2],
    pub motion_vector_jitter_cancellation: [f32; 2],
    pub pre_exposure: f32,
    pub previous_frame_pre_exposure: f32,
    pub tan_half_fov: f32,
    pub jitter_phase_count: f32,
    pub delta_time: f32,
    pub dynamic_res_change_factor: f32,
    pub view_space_to_meters_factor: f32,
}

impl Fsr2Constants {
    /// `sizeof(Fsr2Constants) / sizeof(uint32_t)`.
    pub const WORDS: u32 = 31;

    /// The C structure's memory as 32-bit words.
    pub fn words(&self) -> Vec<u32> {
        let mut w = Vec::with_capacity(Self::WORDS as usize);
        for pair in [
            self.render_size,
            self.max_render_size,
            self.display_size,
            self.input_color_resource_dimensions,
            self.luma_mip_dimensions,
        ] {
            w.extend(pair.map(i32::cast_unsigned));
        }
        w.push(self.luma_mip_level_to_use.cast_unsigned());
        w.push(self.frame_index.cast_unsigned());
        w.extend(self.device_to_view_depth.map(f32::to_bits));
        for pair in [
            self.jitter_offset,
            self.motion_vector_scale,
            self.downscale_factor,
            self.motion_vector_jitter_cancellation,
        ] {
            w.extend(pair.map(f32::to_bits));
        }
        for value in [
            self.pre_exposure,
            self.previous_frame_pre_exposure,
            self.tan_half_fov,
            self.jitter_phase_count,
            self.delta_time,
            self.dynamic_res_change_factor,
            self.view_space_to_meters_factor,
        ] {
            w.push(value.to_bits());
        }
        w
    }
}

/// `FfxFsr2Context_Private`: the private implementation of the FSR2 context.
pub struct FfxFsr2ContextPrivate {
    pub context_description: FfxFsr2ContextDescription,
    pub effect_context_id: FfxUInt32,
    pub constants: Fsr2Constants,
    pub device: FfxDevice,
    pub device_capabilities: FfxDeviceCapabilities,
    pub pipeline_depth_clip: FfxPipelineState,
    pub pipeline_reconstruct_previous_depth: FfxPipelineState,
    pub pipeline_lock: FfxPipelineState,
    pub pipeline_accumulate: FfxPipelineState,
    pub pipeline_accumulate_sharpen: FfxPipelineState,
    pub pipeline_rcas: FfxPipelineState,
    pub pipeline_compute_luminance_pyramid: FfxPipelineState,
    pub pipeline_generate_reactive: FfxPipelineState,
    pub pipeline_tcr_autogenerate: FfxPipelineState,
    pub constant_buffers: [FfxConstantBuffer; 4],

    // 2 arrays of resources, as e.g. FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS will use different resources when bound as SRV vs when bound as UAV
    pub srv_resources: [FfxResourceInternal; FFX_FSR2_RESOURCE_IDENTIFIER_COUNT as usize],
    pub uav_resources: [FfxResourceInternal; FFX_FSR2_RESOURCE_IDENTIFIER_COUNT as usize],

    pub first_execution: bool,
    pub resource_frame_index: u32,
    pub previous_jitter_offset: [f32; 2],
    pub jitter_phase_count_remaining: i32,
}

impl FfxFsr2ContextPrivate {
    /// The `memset(context, 0, sizeof(FfxFsr2Context_Private))` state with the
    /// context description copied in.
    pub fn zeroed(context_description: FfxFsr2ContextDescription) -> Self {
        Self {
            context_description,
            effect_context_id: 0,
            constants: Fsr2Constants::default(),
            device: 0,
            device_capabilities: FfxDeviceCapabilities::default(),
            pipeline_depth_clip: FfxPipelineState::default(),
            pipeline_reconstruct_previous_depth: FfxPipelineState::default(),
            pipeline_lock: FfxPipelineState::default(),
            pipeline_accumulate: FfxPipelineState::default(),
            pipeline_accumulate_sharpen: FfxPipelineState::default(),
            pipeline_rcas: FfxPipelineState::default(),
            pipeline_compute_luminance_pyramid: FfxPipelineState::default(),
            pipeline_generate_reactive: FfxPipelineState::default(),
            pipeline_tcr_autogenerate: FfxPipelineState::default(),
            constant_buffers: Default::default(),
            srv_resources: [FfxResourceInternal::default();
                FFX_FSR2_RESOURCE_IDENTIFIER_COUNT as usize],
            uav_resources: [FfxResourceInternal::default();
                FFX_FSR2_RESOURCE_IDENTIFIER_COUNT as usize],
            first_execution: false,
            resource_frame_index: 0,
            previous_jitter_offset: [0.0; 2],
            jitter_phase_count_remaining: 0,
        }
    }
}
