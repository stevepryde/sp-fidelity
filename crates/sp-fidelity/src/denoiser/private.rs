//! Reflection members of `sdk/src/components/denoiser/ffx_denoiser_private.h`.
use super::resources::FFX_DENOISER_RESOURCE_IDENTIFIER_COUNT;
use super::*;

pub const DENOISER_SHADER_PERMUTATION_FORCE_WAVE64: u32 = 1 << 0;
pub const DENOISER_SHADER_PERMUTATION_ALLOW_FP16: u32 = 1 << 1;
pub const DENOISER_SHADER_PERMUTATION_DEPTH_INVERTED: u32 = 1 << 2;

pub(crate) type ResourceTable =
    [FfxResourceInternal; FFX_DENOISER_RESOURCE_IDENTIFIER_COUNT as usize];

pub(crate) struct FfxDenoiserContextPrivate {
    pub description: FfxDenoiserContextDescription,
    pub effect_context_id: u32,
    pub device: FfxDevice,
    pub reproject: FfxPipelineState,
    pub prefilter: FfxPipelineState,
    pub resolve_temporal: FfxPipelineState,
    pub resources: ResourceTable,
    pub constants: FfxConstantBuffer,
    pub first_frame: bool,
}
