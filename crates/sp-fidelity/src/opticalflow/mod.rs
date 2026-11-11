//! Port of `sdk/include/FidelityFX/host/ffx_opticalflow.h` (FidelityFX SDK 1.1.4).
use crate::interface::FfxInterfaceRef;
use crate::types::*;
pub mod component;
pub mod private;
pub mod resources;
pub use component::*;
pub const FFX_OPTICALFLOW_VERSION_MAJOR: u32 = 1;
pub const FFX_OPTICALFLOW_VERSION_MINOR: u32 = 1;
pub const FFX_OPTICALFLOW_VERSION_PATCH: u32 = 2;
pub const FFX_OPTICALFLOW_CONTEXT_COUNT: u32 = 1;
pub const FFX_OPTICALFLOW_CONTEXT_SIZE: u32 = FFX_SDK_DEFAULT_CONTEXT_SIZE;
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxOpticalflowPass {
    PrepareLuma,
    GenerateOpticalFlowInputPyramid,
    GenerateScdHistogram,
    ComputeScdDivergence,
    ComputeOpticalFlowAdvancedV5,
    FilterOpticalFlowV5,
    ScaleOpticalFlowAdvancedV5,
}

pub const FFX_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE: u32 = 1 << 0;

#[derive(Clone)]
pub struct FfxOpticalflowContextDescription {
    pub backend_interface: FfxInterfaceRef,
    pub flags: u32,
    pub resolution: FfxDimensions2D,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxOpticalflowDispatchDescription {
    pub command_list: FfxCommandList,
    pub color: FfxResource,
    pub optical_flow_vector: FfxResource,
    pub optical_flow_scd: FfxResource,
    pub reset: bool,
    pub backbuffer_transfer_function: i32,
    pub min_max_luminance: FfxFloatCoords2D,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FfxOpticalflowSharedResourceDescriptions<'a> {
    pub optical_flow_vector: FfxCreateResourceDescription<'a>,
    pub optical_flow_scd: FfxCreateResourceDescription<'a>,
}

#[derive(Default)]
pub struct FfxOpticalflowContext {
    pub(crate) private: Option<Box<private::FfxOpticalflowContextPrivate>>,
}

pub const FFX_OPTICALFLOW_PASS_COUNT: u32 = 7;
