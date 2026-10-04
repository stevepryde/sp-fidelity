//! Port of `sdk/src/shared/ffx_object_management.{h,cpp}` (FidelityFX SDK 1.1.4).
use super::interface::FfxInterface;
use super::types::{FfxPipelineState, FfxResourceInternal};

/// `ffxSafeReleasePipeline`.
pub fn ffx_safe_release_pipeline(
    backend_interface: &mut dyn FfxInterface,
    pipeline: &mut FfxPipelineState,
    effect_context_id: u32,
) {
    let _ = backend_interface.destroy_pipeline(pipeline, effect_context_id);
}

/// `ffxSafeReleaseCopyResource`.
pub fn ffx_safe_release_copy_resource(
    backend_interface: &mut dyn FfxInterface,
    resource: FfxResourceInternal,
    effect_context_id: u32,
) {
    let copy_resource = FfxResourceInternal {
        internal_index: resource.internal_index + 1,
    };
    let _ = backend_interface.destroy_resource(copy_resource, effect_context_id);
}

/// `ffxSafeReleaseResource`.
pub fn ffx_safe_release_resource(
    backend_interface: &mut dyn FfxInterface,
    resource: FfxResourceInternal,
    effect_context_id: u32,
) {
    let _ = backend_interface.destroy_resource(resource, effect_context_id);
}
