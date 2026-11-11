//! Port of `sdk/include/FidelityFX/host/ffx_fsr3upscaler.h` (SDK 1.1.4, FSR 3.1.4).
use crate::interface::FfxInterfaceRef;
use crate::types::*;

pub mod component;
pub mod private;
pub mod resources;

pub use component::*;

pub const FFX_FSR3UPSCALER_VERSION_MAJOR: u32 = 3;
pub const FFX_FSR3UPSCALER_VERSION_MINOR: u32 = 1;
pub const FFX_FSR3UPSCALER_VERSION_PATCH: u32 = 4;
pub const FFX_FSR3UPSCALER_CONTEXT_COUNT: u32 = 1;
pub const FFX_FSR3UPSCALER_CONTEXT_SIZE: u32 = FFX_SDK_DEFAULT_CONTEXT_SIZE;

/// All passes, including the deprecated TCR autogeneration identifier.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFsr3UpscalerPass {
    PrepareInputs = 0,
    LumaPyramid = 1,
    ShadingChangePyramid = 2,
    ShadingChange = 3,
    PrepareReactivity = 4,
    LumaInstability = 5,
    Accumulate = 6,
    AccumulateSharpen = 7,
    Rcas = 8,
    DebugView = 9,
    GenerateReactive = 10,
    TcrAutogenerate = 11,
}
pub const FFX_FSR3UPSCALER_PASS_COUNT: u32 = 12;

#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFsr3UpscalerQualityMode {
    NativeAa = 0,
    Quality = 1,
    Balanced = 2,
    Performance = 3,
    UltraPerformance = 4,
}

pub const FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE: u32 = 1 << 0;
pub const FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS: u32 = 1 << 1;
pub const FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION: u32 = 1 << 2;
pub const FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED: u32 = 1 << 3;
pub const FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE: u32 = 1 << 4;
pub const FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE: u32 = 1 << 5;
pub const FFX_FSR3UPSCALER_ENABLE_DYNAMIC_RESOLUTION: u32 = 1 << 6;
pub const FFX_FSR3UPSCALER_ENABLE_TEXTURE1D_USAGE: u32 = 1 << 7;
pub const FFX_FSR3UPSCALER_ENABLE_DEBUG_CHECKING: u32 = 1 << 8;

pub const FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW: u32 = 1 << 0;

pub type FfxFsr3UpscalerMessage = fn(message_type: FfxMsgType, message: &str);

#[derive(Clone)]
pub struct FfxFsr3UpscalerContextDescription {
    pub flags: u32,
    pub max_render_size: FfxDimensions2D,
    pub max_upscale_size: FfxDimensions2D,
    pub fp_message: Option<FfxFsr3UpscalerMessage>,
    pub backend_interface: FfxInterfaceRef,
}

/// Keys accepted by `ffxFsr3UpscalerSetConstant`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFsr3UpscalerConfigureKey {
    VelocityFactor = 0,
    ReactivenessScale = 1,
    ShadingChangeScale = 2,
    AccumulationAddedPerFrame = 3,
    MinDisocclusionAccumulation = 4,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr3UpscalerDispatchDescription {
    pub command_list: FfxCommandList,
    pub color: FfxResource,
    pub depth: FfxResource,
    pub motion_vectors: FfxResource,
    pub exposure: FfxResource,
    pub reactive: FfxResource,
    pub transparency_and_composition: FfxResource,
    pub dilated_depth: FfxResource,
    pub dilated_motion_vectors: FfxResource,
    pub reconstructed_prev_nearest_depth: FfxResource,
    pub output: FfxResource,
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
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr3UpscalerGenerateReactiveDescription {
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

/// Resources allocated by the caller and supplied on every dispatch.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FfxFsr3UpscalerSharedResourceDescriptions {
    pub reconstructed_prev_nearest_depth: FfxCreateResourceDescription<'static>,
    pub dilated_depth: FfxCreateResourceDescription<'static>,
    pub dilated_motion_vectors: FfxCreateResourceDescription<'static>,
}

/// The opaque context; `None` until created.
#[derive(Default)]
pub struct FfxFsr3UpscalerContext {
    pub(crate) private: Option<Box<private::FfxFsr3UpscalerContextPrivate>>,
}
