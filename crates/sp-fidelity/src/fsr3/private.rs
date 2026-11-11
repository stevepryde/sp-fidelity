//! Port of `sdk/src/components/fsr3/ffx_fsr3_private.h`.
use super::FfxFsr3ContextDescription;
use super::resources::*;
use crate::frameinterpolation::{
    FfxFrameInterpolationContext, FfxFrameInterpolationPrepareDescription,
};
use crate::fsr3upscaler::FfxFsr3UpscalerContext;
use crate::opticalflow::FfxOpticalflowContext;
use crate::types::*;

/// Maximum queued frames for descriptor management.
pub const FSR3_MAX_QUEUED_FRAMES: u32 = 2;

/// The composite context's persistent state.
pub struct FfxFsr3ContextPrivate {
    pub description: FfxFsr3ContextDescription,
    pub upscaler_context: FfxFsr3UpscalerContext,
    pub of_context: FfxOpticalflowContext,
    pub fi_context: FfxFrameInterpolationContext,
    pub shared_resources: [FfxResourceInternal; FFX_FSR3_RESOURCE_IDENTIFIER_COUNT as usize],
    pub effect_context_id_shared_resources: u32,
    pub delta_time: f32,
    pub upscaling_only: bool,
    pub interpolation_only: bool,
    pub async_workload_supported: bool,
    pub shared_resource_count: u32,
    pub hudless_color: FfxResource,
    pub dilated_depth: FfxResource,
    pub dilated_motion_vectors: FfxResource,
    pub reconstructed_prev_nearest_depth: FfxResource,
    pub frame_generation_enabled: bool,
    pub frame_generation_flags: u32,
    pub fg_prepare_descriptions:
        [FfxFrameInterpolationPrepareDescription; FSR3_MAX_QUEUED_FRAMES as usize],
}

impl FfxFsr3ContextPrivate {
    pub fn zeroed(description: FfxFsr3ContextDescription) -> Self {
        Self {
            description,
            upscaler_context: Default::default(),
            of_context: Default::default(),
            fi_context: Default::default(),
            shared_resources: [FfxResourceInternal::default();
                FFX_FSR3_RESOURCE_IDENTIFIER_COUNT as usize],
            effect_context_id_shared_resources: 0,
            delta_time: 0.0,
            // The original create function never assigns these private fields.
            // They intentionally retain the SDK's memset-zero state.
            upscaling_only: false,
            interpolation_only: false,
            async_workload_supported: false,
            shared_resource_count: 0,
            hudless_color: Default::default(),
            dilated_depth: Default::default(),
            dilated_motion_vectors: Default::default(),
            reconstructed_prev_nearest_depth: Default::default(),
            frame_generation_enabled: false,
            frame_generation_flags: 0,
            fg_prepare_descriptions: std::array::from_fn(|_| Default::default()),
        }
    }
}
