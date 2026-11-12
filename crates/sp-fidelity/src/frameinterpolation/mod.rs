//! Port of `sdk/include/FidelityFX/host/ffx_frameinterpolation.h` (FidelityFX SDK 1.1.4).
use crate::interface::FfxInterfaceRef;
use crate::types::*;
pub mod component;
mod edge;
pub mod private;
pub mod resources;
pub use component::*;
pub const FFX_FRAMEINTERPOLATION_VERSION_MAJOR: u32 = 1;
pub const FFX_FRAMEINTERPOLATION_VERSION_MINOR: u32 = 1;
pub const FFX_FRAMEINTERPOLATION_VERSION_PATCH: u32 = 3;
pub const FFX_FRAMEINTERPOLATION_CONTEXT_COUNT: u32 = 1;
pub const FFX_FRAMEINTERPOLATION_CONTEXT_SIZE: u32 = FFX_SDK_DEFAULT_CONTEXT_SIZE;
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxFrameInterpolationPass {
    ReconstructAndDilate,
    Setup,
    ReconstructPrevDepth,
    GameMotionVectorField,
    OpticalFlowVectorField,
    DisocclusionMask,
    Interpolation,
    InpaintingPyramid,
    Inpainting,
    GameVectorFieldInpaintingPyramid,
    DebugView,
    /// Port extension: camera-supported reconstruction of outgoing geometry.
    ReconstructOutgoingGeometry,
    /// Port extension: disocclusion using retained actual previous depth.
    DisocclusionWithCameraVisibility,
}

pub const FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED: u32 = 1 << 0;

pub const FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE: u32 = 1 << 1;

pub const FFX_FRAMEINTERPOLATION_ENABLE_TEXTURE1D_USAGE: u32 = 1 << 2;

pub const FFX_FRAMEINTERPOLATION_ENABLE_HDR_COLOR_INPUT: u32 = 1 << 3;

pub const FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS: u32 = 1 << 4;

pub const FFX_FRAMEINTERPOLATION_ENABLE_JITTER_MOTION_VECTORS: u32 = 1 << 5;

pub const FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT: u32 = 1 << 6;

pub const FFX_FRAMEINTERPOLATION_ENABLE_DEBUG_CHECKING: u32 = 1 << 7;

pub const FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES: u32 = 1 << 0;

pub const FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_RESET_INDICATORS: u32 = 1 << 1;

pub const FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW: u32 = 1 << 2;

pub const FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_PACING_LINES: u32 = 1 << 3;

pub const FFX_FRAMEINTERPOLATION_DISPATCH_RESERVED_1: u32 = 1 << 4;

pub const FFX_FRAMEINTERPOLATION_DISPATCH_RESERVED_2: u32 = 1 << 5;

#[derive(Clone)]
pub struct FfxFrameInterpolationContextDescription {
    pub flags: u32,
    pub max_render_size: FfxDimensions2D,
    pub display_size: FfxDimensions2D,
    pub back_buffer_format: FfxSurfaceFormat,
    pub previous_interpolation_source_format: FfxSurfaceFormat,
    pub backend_interface: FfxInterfaceRef,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FfxFrameInterpolationSharedResourceDescriptions<'a> {
    pub reconstructed_prev_nearest_depth: FfxCreateResourceDescription<'a>,
    pub dilated_depth: FfxCreateResourceDescription<'a>,
    pub dilated_motion_vectors: FfxCreateResourceDescription<'a>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFrameInterpolationPrepareDescription {
    pub flags: u32,
    pub command_list: FfxCommandList,
    pub render_size: FfxDimensions2D,
    pub jitter_offset: FfxFloatCoords2D,
    pub motion_vector_scale: FfxFloatCoords2D,
    pub frame_time_delta: f32,
    pub camera_near: f32,
    pub camera_far: f32,
    pub view_space_to_meters_factor: f32,
    pub camera_fov_angle_vertical: f32,
    pub depth: FfxResource,
    pub motion_vectors: FfxResource,
    pub frame_id: u64,
    pub dilated_depth: FfxResource,
    pub dilated_motion_vectors: FfxResource,
    pub reconstructed_prev_depth: FfxResource,
    /// Optional outgoing-edge reconstruction: world-space camera position.
    /// Supply this and an orthonormal right/up/forward basis for consecutive
    /// frames of a symmetric perspective camera. Zero basis disables the
    /// extension. Reset dispatch after cuts or changes to the world origin.
    /// See the crate README for depth, jitter and motion-vector conventions.
    pub camera_position: FfxFloat32x3,
    pub camera_up: FfxFloat32x3,
    pub camera_right: FfxFloat32x3,
    pub camera_forward: FfxFloat32x3,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxFrameInterpolationDispatchDescription {
    pub flags: u32,
    pub command_list: FfxCommandList,
    pub display_size: FfxDimensions2D,
    pub render_size: FfxDimensions2D,
    pub current_back_buffer: FfxResource,
    pub current_back_buffer_hud_less: FfxResource,
    pub output: FfxResource,
    pub interpolation_rect: FfxRect2D,
    pub optical_flow_vector: FfxResource,
    pub optical_flow_scene_change_detection: FfxResource,
    pub optical_flow_buffer_size: FfxDimensions2D,
    pub optical_flow_scale: FfxFloatCoords2D,
    pub optical_flow_block_size: i32,
    pub camera_near: f32,
    pub camera_far: f32,
    pub camera_fov_angle_vertical: f32,
    pub view_space_to_meters_factor: f32,
    pub frame_time_delta: f32,
    pub reset: bool,
    pub back_buffer_transfer_function: FfxBackbufferTransferFunction,
    pub min_max_luminance: [f32; 2],
    pub frame_id: u64,
    pub dilated_depth: FfxResource,
    pub dilated_motion_vectors: FfxResource,
    pub reconstructed_prev_depth: FfxResource,
    pub distortion_field: FfxResource,
}

#[derive(Default)]
pub struct FfxFrameInterpolationContext {
    pub(crate) private: Option<Box<private::FfxFrameInterpolationContextPrivate>>,
}

pub const FFX_FRAMEINTERPOLATION_PASS_COUNT: u32 = 13;
