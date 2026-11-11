//! Port of `sdk/include/FidelityFX/host/ffx_fsr3.h` (SDK 1.1.4, FSR 3.1.4).
//!
//! FSR3 composes the upscaler, optical flow, and frame interpolation contexts.
//! The callback helper captures a weak reference to the context instead of the
//! SDK's global raw context pointer. Callbacks require this thread, as does the
//! shared backend interface.
use crate::interface::FfxInterfaceRef;
use crate::types::*;
use std::cell::RefCell;
use std::rc::Rc;

pub mod component;
pub mod private;
pub mod resources;
pub use component::*;

pub const FFX_FSR3_VERSION_MAJOR: u32 = 3;
pub const FFX_FSR3_VERSION_MINOR: u32 = 1;
pub const FFX_FSR3_VERSION_PATCH: u32 = 4;
pub const FFX_FSR3_CONTEXT_COUNT: u32 = crate::fsr3upscaler::FFX_FSR3UPSCALER_CONTEXT_COUNT
    + crate::opticalflow::FFX_OPTICALFLOW_CONTEXT_COUNT
    + crate::frameinterpolation::FFX_FRAMEINTERPOLATION_CONTEXT_COUNT
    + 1;
pub const FFX_FSR3_CONTEXT_SIZE: u32 = crate::fsr3upscaler::FFX_FSR3UPSCALER_CONTEXT_SIZE
    + crate::opticalflow::FFX_OPTICALFLOW_CONTEXT_SIZE
    + crate::frameinterpolation::FFX_FRAMEINTERPOLATION_CONTEXT_SIZE
    + FFX_SDK_DEFAULT_CONTEXT_SIZE;

#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFsr3QualityMode {
    Quality = 1,
    Balanced = 2,
    Performance = 3,
    UltraPerformance = 4,
}
pub const FFX_FSR3_ENABLE_HIGH_DYNAMIC_RANGE: u32 = 1 << 0;
pub const FFX_FSR3_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS: u32 = 1 << 1;
pub const FFX_FSR3_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION: u32 = 1 << 2;
pub const FFX_FSR3_ENABLE_DEPTH_INVERTED: u32 = 1 << 3;
pub const FFX_FSR3_ENABLE_DEPTH_INFINITE: u32 = 1 << 4;
pub const FFX_FSR3_ENABLE_AUTO_EXPOSURE: u32 = 1 << 5;
pub const FFX_FSR3_ENABLE_DYNAMIC_RESOLUTION: u32 = 1 << 6;
pub const FFX_FSR3_ENABLE_TEXTURE1D_USAGE: u32 = 1 << 7;
pub const FFX_FSR3_ENABLE_DEBUG_CHECKING: u32 = 1 << 8;
pub const FFX_FSR3_ENABLE_UPSCALING_ONLY: u32 = 1 << 9;
pub const FFX_FSR3_ENABLE_HDR_UPSCALE_SDR_FINALOUTPUT: u32 = 1 << 10;
pub const FFX_FSR3_ENABLE_SDR_UPSCALE_HDR_FINALOUTPUT: u32 = 1 << 11;
pub const FFX_FSR3_ENABLE_ASYNC_WORKLOAD_SUPPORT: u32 = 1 << 12;
pub const FFX_FSR3_ENABLE_INTERPOLATION_ONLY: u32 = 1 << 13;

pub const FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_TEAR_LINES: u32 =
    crate::frameinterpolation::FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES;
pub const FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW: u32 =
    crate::frameinterpolation::FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW;
pub const FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_PACING_LINES: u32 =
    crate::frameinterpolation::FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_PACING_LINES;
pub const FFX_FSR3_UPSCALER_FLAG_DRAW_DEBUG_VIEW: u32 =
    crate::fsr3upscaler::FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW;

#[derive(Clone)]
pub struct FfxFsr3ContextDescription {
    pub flags: u32,
    pub max_render_size: FfxDimensions2D,
    pub max_upscale_size: FfxDimensions2D,
    pub display_size: FfxDimensions2D,
    pub backend_interface_shared_resources: FfxInterfaceRef,
    pub backend_interface_upscaling: FfxInterfaceRef,
    pub backend_interface_frame_interpolation: FfxInterfaceRef,
    pub fp_message: Option<crate::fsr3upscaler::FfxFsr3UpscalerMessage>,
    pub back_buffer_format: FfxSurfaceFormat,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr3DispatchUpscaleDescription {
    pub command_list: FfxCommandList,
    pub color: FfxResource,
    pub depth: FfxResource,
    pub motion_vectors: FfxResource,
    pub exposure: FfxResource,
    pub reactive: FfxResource,
    pub transparency_and_composition: FfxResource,
    pub upscale_output: FfxResource,
    pub jitter_offset: FfxFloatCoords2D,
    pub motion_vector_scale: FfxFloatCoords2D,
    pub render_size: FfxDimensions2D,
    pub upscale_size: FfxDimensions2D,
    pub enable_sharpening: bool,
    pub sharpness: f32,
    pub frame_time_delta: f32,
    pub pre_exposure: f32,
    pub reset: bool,
    pub camera_near: f32,
    pub camera_far: f32,
    pub camera_fov_angle_vertical: f32,
    pub view_space_to_meters_factor: f32,
    pub flags: u32,
    pub frame_id: u64,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr3DispatchFrameGenerationPrepareDescription {
    pub command_list: FfxCommandList,
    pub depth: FfxResource,
    pub motion_vectors: FfxResource,
    pub jitter_offset: FfxFloatCoords2D,
    pub motion_vector_scale: FfxFloatCoords2D,
    pub render_size: FfxDimensions2D,
    pub frame_time_delta: f32,
    pub camera_near: f32,
    pub camera_far: f32,
    pub view_space_to_meters_factor: f32,
    pub camera_fov_angle_vertical: f32,
    pub frame_id: u64,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr3GenerateReactiveDescription {
    pub command_list: FfxCommandList,
    pub color_opaque_only: FfxResource,
    pub color_pre_upscale: FfxResource,
    pub out_reactive: FfxResource,
    pub render_size: FfxDimensions2D,
    pub scale: f32,
    pub cutoff_threshold: f32,
    pub binary_value: f32,
    pub flags: u32,
}

/// The opaque context. A callback holds only a weak reference to its state.
#[derive(Default)]
pub struct FfxFsr3Context {
    pub(crate) private: Option<Rc<RefCell<private::FfxFsr3ContextPrivate>>>,
}
