//! Select SDK pipeline tables independently of the physical device, while
//! delegating every operation to its real wgpu backend. A reported 32..64 lane
//! range with shader model 6.2 selects the Lanczos LUT without forcing 64 lanes.
use sp_fidelity::error::FfxErrorCode;
use sp_fidelity::interface::{FfxInterface, FfxInterfaceRef, FfxPass};
use sp_fidelity::types::*;
use std::cell::RefCell;
use std::rc::Rc;

pub fn with_capabilities(
    inner: FfxInterfaceRef,
    capabilities: FfxDeviceCapabilities,
) -> FfxInterfaceRef {
    Rc::new(RefCell::new(Capabilities {
        inner,
        capabilities,
    }))
}
struct Capabilities {
    inner: FfxInterfaceRef,
    capabilities: FfxDeviceCapabilities,
}
impl FfxInterface for Capabilities {
    fn device(&self) -> FfxDevice {
        self.inner.borrow().device()
    }
    fn get_sdk_version(&mut self) -> FfxVersionNumber {
        self.inner.borrow_mut().get_sdk_version()
    }
    fn get_effect_gpu_memory_usage(
        &mut self,
        effect_context_id: u32,
    ) -> Result<FfxEffectMemoryUsage, FfxErrorCode> {
        self.inner
            .borrow_mut()
            .get_effect_gpu_memory_usage(effect_context_id)
    }
    fn create_backend_context(
        &mut self,
        effect: FfxEffect,
        bindless_config: Option<&FfxEffectBindlessConfig>,
    ) -> Result<u32, FfxErrorCode> {
        self.inner
            .borrow_mut()
            .create_backend_context(effect, bindless_config)
    }
    fn get_device_capabilities(&mut self) -> Result<FfxDeviceCapabilities, FfxErrorCode> {
        Ok(self.capabilities)
    }
    fn destroy_backend_context(&mut self, effect_context_id: u32) -> Result<(), FfxErrorCode> {
        self.inner
            .borrow_mut()
            .destroy_backend_context(effect_context_id)
    }
    fn create_resource(
        &mut self,
        create_resource_description: &FfxCreateResourceDescription<'_>,
        effect_context_id: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode> {
        self.inner
            .borrow_mut()
            .create_resource(create_resource_description, effect_context_id)
    }
    fn register_resource(
        &mut self,
        in_resource: &FfxResource,
        effect_context_id: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode> {
        self.inner
            .borrow_mut()
            .register_resource(in_resource, effect_context_id)
    }
    fn get_resource(&mut self, resource: FfxResourceInternal) -> FfxResource {
        self.inner.borrow_mut().get_resource(resource)
    }
    fn unregister_resources(
        &mut self,
        command_list: FfxCommandList,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        self.inner
            .borrow_mut()
            .unregister_resources(command_list, effect_context_id)
    }
    fn get_resource_description(
        &mut self,
        resource: FfxResourceInternal,
    ) -> FfxResourceDescription {
        self.inner.borrow_mut().get_resource_description(resource)
    }
    fn destroy_resource(
        &mut self,
        resource: FfxResourceInternal,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        self.inner
            .borrow_mut()
            .destroy_resource(resource, effect_context_id)
    }
    fn stage_constant_buffer_data_func(
        &mut self,
        data: &[u32],
        constant_buffer: &mut FfxConstantBuffer,
    ) -> Result<(), FfxErrorCode> {
        self.inner
            .borrow_mut()
            .stage_constant_buffer_data_func(data, constant_buffer)
    }
    fn create_pipeline(
        &mut self,
        effect: FfxEffect,
        pass: FfxPass,
        permutation_options: u32,
        pipeline_description: &FfxPipelineDescription<'_>,
        effect_context_id: u32,
    ) -> Result<FfxPipelineState, FfxErrorCode> {
        self.inner.borrow_mut().create_pipeline(
            effect,
            pass,
            permutation_options,
            pipeline_description,
            effect_context_id,
        )
    }
    fn get_permutation_blob_by_index(
        &self,
        effect_id: FfxEffect,
        pass_id: FfxPass,
        bind_stage: FfxBindStage,
        permutation_options: u32,
    ) -> Result<FfxShaderBlob, FfxErrorCode> {
        self.inner.borrow().get_permutation_blob_by_index(
            effect_id,
            pass_id,
            bind_stage,
            permutation_options,
        )
    }
    fn destroy_pipeline(
        &mut self,
        pipeline: &mut FfxPipelineState,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        self.inner
            .borrow_mut()
            .destroy_pipeline(pipeline, effect_context_id)
    }
    fn schedule_gpu_job(&mut self, job: &FfxGpuJobDescription) -> Result<(), FfxErrorCode> {
        self.inner.borrow_mut().schedule_gpu_job(job)
    }
    fn execute_gpu_jobs(
        &mut self,
        command_list: FfxCommandList,
        effect_context_id: u32,
    ) -> Result<(), FfxErrorCode> {
        self.inner
            .borrow_mut()
            .execute_gpu_jobs(command_list, effect_context_id)
    }
}
