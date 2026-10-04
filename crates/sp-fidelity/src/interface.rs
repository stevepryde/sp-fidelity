//! Port of `sdk/include/FidelityFX/host/ffx_interface.h` (FidelityFX SDK 1.1.4).
//!
//! The C `FfxInterface` function table becomes the [`FfxInterface`] trait: one
//! method per `fp*` callback, named in snake case, with the C
//! `FfxInterface* backendInterface` argument as `&mut self` and out-parameters
//! as return values. An `Err` leaves the component's output slot unchanged.
//! A trait implementation cannot leave a callback `NULL`, so the components'
//! `FFX_ERROR_INCOMPLETE_INTERFACE` callback checks hold statically. The
//! `device` field is [`FfxInterface::device`]. Components share one backend
//! the way C copies the table between contexts: through [`FfxInterfaceRef`].
//!
//! Not ported, because no ported component calls them: `fpRegisterStaticResource`,
//! `fpMapResource`, `fpUnmapResource`, the SDK 1.1 breadcrumbs, frame-generation swap-chain and constant-buffer-allocator
//! callbacks, and the `scratchBuffer`/`scratchBufferSize` backend memory (a
//! Rust backend owns its state).
use super::error::FfxErrorCode;
use super::types::*;
use std::cell::RefCell;
use std::rc::Rc;

pub const FFX_SDK_VERSION_MAJOR: u32 = 1;
pub const FFX_SDK_VERSION_MINOR: u32 = 1;
pub const FFX_SDK_VERSION_PATCH: u32 = 4;

/// `FFX_SDK_MAKE_VERSION(major, minor, patch)`.
pub const fn ffx_sdk_make_version(major: u32, minor: u32, patch: u32) -> FfxVersionNumber {
    (major << 22) | (minor << 12) | patch
}

/// `FfxPass`: an effect's pass enumeration value.
pub type FfxPass = u32;

/// A shared backend: the Rust counterpart of copying `FfxInterface` by value
/// into each effect context description.
pub type FfxInterfaceRef = Rc<RefCell<dyn FfxInterface>>;

/// `FfxInterface`: the backend function table.
pub trait FfxInterface {
    /// `device`.
    fn device(&self) -> FfxDevice;

    /// `fpGetSDKVersion`.
    fn get_sdk_version(&mut self) -> FfxVersionNumber;

    /// `fpGetEffectGpuMemoryUsage`.
    fn get_effect_gpu_memory_usage(
        &mut self,
        effect_context_id: u32,
    ) -> Result<FfxEffectMemoryUsage, FfxErrorCode>;

    /// `fpCreateBackendContext`; returns `effectContextId`.
    fn create_backend_context(
        &mut self,
        effect: FfxEffect,
        bindless_config: Option<&FfxEffectBindlessConfig>,
    ) -> Result<u32, FfxErrorCode>;

    /// `fpGetDeviceCapabilities`.
    fn get_device_capabilities(&mut self) -> Result<FfxDeviceCapabilities, FfxErrorCode>;

    /// `fpDestroyBackendContext`.
    fn destroy_backend_context(&mut self, effect_context_id: u32) -> Result<(), FfxErrorCode>;

    /// `fpCreateResource`.
    fn create_resource(
        &mut self,
        create_resource_description: &FfxCreateResourceDescription<'_>,
        effect_context_id: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode>;

    /// `fpRegisterResource`.
    fn register_resource(
        &mut self,
        in_resource: &FfxResource,
        effect_context_id: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode>;

    /// `fpGetResource`.
    fn get_resource(&mut self, resource: FfxResourceInternal) -> FfxResource;

    /// `fpUnregisterResources`.
    fn unregister_resources(
        &mut self,
        command_list: FfxCommandList,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode>;

    /// `fpGetResourceDescription`.
    fn get_resource_description(&mut self, resource: FfxResourceInternal)
    -> FfxResourceDescription;

    /// `fpDestroyResource`.
    fn destroy_resource(
        &mut self,
        resource: FfxResourceInternal,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode>;

    /// `fpStageConstantBufferDataFunc`: stage `data` (the constant structure as
    /// 32-bit words) into `constant_buffer`.
    fn stage_constant_buffer_data_func(
        &mut self,
        data: &[u32],
        constant_buffer: &mut FfxConstantBuffer,
    ) -> Result<(), FfxErrorCode>;

    /// `fpCreatePipeline`.
    fn create_pipeline(
        &mut self,
        effect: FfxEffect,
        pass: FfxPass,
        permutation_options: u32,
        pipeline_description: &FfxPipelineDescription<'_>,
        effect_context_id: u32,
    ) -> Result<FfxPipelineState, FfxErrorCode>;

    /// `fpGetPermutationBlobByIndex`.
    fn get_permutation_blob_by_index(
        &self,
        effect_id: FfxEffect,
        pass_id: FfxPass,
        bind_stage: FfxBindStage,
        permutation_options: u32,
    ) -> Result<FfxShaderBlob, FfxErrorCode>;

    /// `fpDestroyPipeline`.
    fn destroy_pipeline(
        &mut self,
        pipeline: &mut FfxPipelineState,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode>;

    /// `fpScheduleGpuJob`.
    fn schedule_gpu_job(&mut self, job: &FfxGpuJobDescription) -> Result<(), FfxErrorCode>;

    /// `fpExecuteGpuJobs`.
    fn execute_gpu_jobs(
        &mut self,
        command_list: FfxCommandList,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode>;
}
