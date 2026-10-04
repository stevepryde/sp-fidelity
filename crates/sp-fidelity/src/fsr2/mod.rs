//! Port of `sdk/include/FidelityFX/host/ffx_fsr2.h` (FidelityFX SDK 1.1.4).
//!
//! Submodules: [`private`] (`ffx_fsr2_private.h`), [`component`]
//! (`sdk/src/components/fsr2/ffx_fsr2.cpp`), [`maximum_bias`]
//! (`ffx_fsr2_maximum_bias.h`), [`resources`] (`gpu/fsr2/ffx_fsr2_resources.h`)
//! and [`common`] (the `FFX_CPU` part of `gpu/fsr2/ffx_fsr2_common.h`).
use super::interface::FfxInterfaceRef;
use super::types::*;

pub mod common;
pub mod component;
pub mod maximum_bias;
pub mod private;
pub mod resources;

pub use component::{
    ffx_fsr2_context_create, ffx_fsr2_context_destroy, ffx_fsr2_context_dispatch,
    ffx_fsr2_context_generate_reactive_mask, ffx_fsr2_context_get_gpu_memory_usage,
    ffx_fsr2_get_effect_version, ffx_fsr2_get_jitter_offset, ffx_fsr2_get_jitter_phase_count,
    ffx_fsr2_get_render_resolution_from_quality_mode, ffx_fsr2_get_upscale_ratio_from_quality_mode,
    ffx_fsr2_resource_is_null, ffx_fsr2_set_global_debug_message,
};

/// FidelityFX Super Resolution 2 major version.
pub const FFX_FSR2_VERSION_MAJOR: u32 = 2;
/// FidelityFX Super Resolution 2 minor version.
pub const FFX_FSR2_VERSION_MINOR: u32 = 3;
/// FidelityFX Super Resolution 2 patch version.
pub const FFX_FSR2_VERSION_PATCH: u32 = 3;

/// `FFX_FSR2_CONTEXT_COUNT`: the number of internal effect contexts required
/// by FSR2.
pub const FFX_FSR2_CONTEXT_COUNT: u32 = 1;

/// `FFX_FSR2_CONTEXT_SIZE`: the size of the context specified in 32bit
/// values. The Rust context owns its private state instead.
pub const FFX_FSR2_CONTEXT_SIZE: u32 = FFX_SDK_DEFAULT_CONTEXT_SIZE;

/// `FfxFsr2Pass`: all the passes which constitute the FSR2 algorithm.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFsr2Pass {
    /// A pass which performs depth clipping.
    DepthClip = 0,
    /// A pass which performs reconstruction of previous frame's depth.
    ReconstructPreviousDepth = 1,
    /// A pass which calculates pixel locks.
    Lock = 2,
    /// A pass which performs upscaling.
    Accumulate = 3,
    /// A pass which performs upscaling when sharpening is used.
    AccumulateSharpen = 4,
    /// A pass which performs sharpening.
    Rcas = 5,
    /// A pass which generates the luminance mipmap chain for the current frame.
    ComputeLuminancePyramid = 6,
    /// An optional pass to generate a reactive mask.
    GenerateReactive = 7,
    /// An optional pass to automatically generate transparency/composition and reactive masks.
    TcrAutogenerate = 8,
}

/// `FFX_FSR2_PASS_COUNT`: the number of passes performed by FSR2.
pub const FFX_FSR2_PASS_COUNT: u32 = 9;

/// `FfxFsr2QualityMode`: the quality modes supported by FidelityFX Super
/// Resolution 2 upscaling.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFsr2QualityMode {
    /// Perform upscaling with a per-dimension upscaling ratio of 1.5x.
    Quality = 1,
    /// Perform upscaling with a per-dimension upscaling ratio of 1.7x.
    Balanced = 2,
    /// Perform upscaling with a per-dimension upscaling ratio of 2.0x.
    Performance = 3,
    /// Perform upscaling with a per-dimension upscaling ratio of 3.0x.
    UltraPerformance = 4,
}

/// `FfxFsr2InitializationFlagBits`.
///
/// A bit indicating if the input color data provided is using a high-dynamic range.
pub const FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE: u32 = 1 << 0;
/// A bit indicating if the motion vectors are rendered at display resolution.
pub const FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS: u32 = 1 << 1;
/// A bit indicating that the motion vectors have the jittering pattern applied to them.
pub const FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION: u32 = 1 << 2;
/// A bit indicating that the input depth buffer data provided is inverted [1..0].
pub const FFX_FSR2_ENABLE_DEPTH_INVERTED: u32 = 1 << 3;
/// A bit indicating that the input depth buffer data provided is using an infinite far plane.
pub const FFX_FSR2_ENABLE_DEPTH_INFINITE: u32 = 1 << 4;
/// A bit indicating if automatic exposure should be applied to input color data.
pub const FFX_FSR2_ENABLE_AUTO_EXPOSURE: u32 = 1 << 5;
/// A bit indicating that the application uses dynamic resolution scaling.
pub const FFX_FSR2_ENABLE_DYNAMIC_RESOLUTION: u32 = 1 << 6;
/// A bit indicating that the backend should use 1D textures.
pub const FFX_FSR2_ENABLE_TEXTURE1D_USAGE: u32 = 1 << 7;
/// A bit indicating that the runtime should check some API values and report issues.
pub const FFX_FSR2_ENABLE_DEBUG_CHECKING: u32 = 1 << 8;

/// `FfxFsr2Message`: pass a string message, used for debug messages.
pub type FfxFsr2Message = fn(message_type: FfxMsgType, message: &str);

/// `FfxFsr2ContextDescription`: the parameters required to initialize
/// FidelityFX Super Resolution 2 upscaling.
#[derive(Clone)]
pub struct FfxFsr2ContextDescription {
    /// A collection of `FfxFsr2InitializationFlagBits`.
    pub flags: u32,
    /// The maximum size that rendering will be performed at.
    pub max_render_size: FfxDimensions2D,
    /// The size of the presentation resolution targeted by the upscaling process.
    pub display_size: FfxDimensions2D,
    /// A function that can receive messages from the runtime; `None` is `NULL`.
    pub fp_message: Option<FfxFsr2Message>,
    /// The backend implementation for FidelityFX SDK.
    pub backend_interface: FfxInterfaceRef,
}

/// `FfxFsr2DispatchDescription`: the parameters for dispatching the various
/// passes of FidelityFX Super Resolution 2.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr2DispatchDescription {
    /// The `FfxCommandList` to record FSR2 rendering commands into.
    pub command_list: FfxCommandList,
    /// The color buffer for the current frame (at render resolution).
    pub color: FfxResource,
    /// 32bit depth values for the current frame (at render resolution).
    pub depth: FfxResource,
    /// 2-dimensional motion vectors (at render resolution if
    /// `FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS` is not set).
    pub motion_vectors: FfxResource,
    /// A optional 1x1 exposure value.
    pub exposure: FfxResource,
    /// A optional alpha value of reactive objects in the scene.
    pub reactive: FfxResource,
    /// A optional alpha value of special objects in the scene.
    pub transparency_and_composition: FfxResource,
    /// The output color buffer for the current frame (at presentation resolution).
    pub output: FfxResource,
    /// The subpixel jitter offset applied to the camera.
    pub jitter_offset: FfxFloatCoords2D,
    /// The scale factor to apply to motion vectors.
    pub motion_vector_scale: FfxFloatCoords2D,
    /// The resolution that was used for rendering the input resources.
    pub render_size: FfxDimensions2D,
    /// Enable an additional sharpening pass.
    pub enable_sharpening: bool,
    /// The sharpness value between 0 and 1, where 0 is no additional sharpness and 1 is maximum additional sharpness.
    pub sharpness: f32,
    /// The time elapsed since the last frame (expressed in milliseconds).
    pub frame_time_delta: f32,
    /// The pre exposure value (must be > 0.0f)
    pub pre_exposure: f32,
    /// A boolean value which when set to true, indicates the camera has moved discontinuously.
    pub reset: bool,
    /// The distance to the near plane of the camera.
    pub camera_near: f32,
    /// The distance to the far plane of the camera.
    pub camera_far: f32,
    /// The camera angle field of view in the vertical direction (expressed in radians).
    pub camera_fov_angle_vertical: f32,
    /// The scale factor to convert view space units to meters
    pub view_space_to_meters_factor: f32,

    // EXPERIMENTAL reactive mask generation parameters
    /// A boolean value to indicate internal reactive autogeneration should be used
    pub enable_auto_reactive: bool,
    /// The opaque only color buffer for the current frame (at render resolution).
    pub color_opaque_only: FfxResource,
    /// Cutoff value for TC
    pub auto_tc_threshold: f32,
    /// A value to scale the transparency and composition mask
    pub auto_tc_scale: f32,
    /// A value to scale the reactive mask
    pub auto_reactive_scale: f32,
    /// A value to clamp the reactive mask
    pub auto_reactive_max: f32,
}

/// `FfxFsr2GenerateReactiveDescription`: the parameters for automatic
/// generation of a reactive mask.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFsr2GenerateReactiveDescription {
    /// The `FfxCommandList` to record FSR2 rendering commands into.
    pub command_list: FfxCommandList,
    /// The opaque only color buffer for the current frame (at render resolution).
    pub color_opaque_only: FfxResource,
    /// The opaque+translucent color buffer for the current frame (at render resolution).
    pub color_pre_upscale: FfxResource,
    /// The surface to generate the reactive mask into.
    pub out_reactive: FfxResource,
    /// The resolution that was used for rendering the input resources.
    pub render_size: FfxDimensions2D,
    /// A value to scale the output
    pub scale: f32,
    /// A threshold value to generate a binary reactive mask
    pub cutoff_threshold: f32,
    /// A value to set for the binary reactive mask
    pub binary_value: f32,
    /// Flags to determine how to generate the reactive mask
    pub flags: u32,
}

/// `FfxFsr2Context`: the opaque context; `None` until created.
#[derive(Default)]
pub struct FfxFsr2Context {
    pub(crate) private: Option<Box<private::FfxFsr2ContextPrivate>>,
}
