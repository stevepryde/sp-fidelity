//! Reflections API from `sdk/include/FidelityFX/host/ffx_denoiser.h` (SDK 1.1.4).
//! AMD's SSSR ray tracer is one producer of the signal. The denoiser takes
//! caller-supplied radiance and hit distance through reprojection, spatial
//! prefiltering and temporal resolve. The caller swaps the two radiance and
//! variance images each frame and supplies the active tile list and indirect
//! dispatch arguments.
use crate::interface::FfxInterfaceRef;
use crate::types::*;

pub mod component;
pub mod private;
pub mod resources;
pub use component::*;

pub const FFX_DENOISER_VERSION_MAJOR: u32 = 1;
pub const FFX_DENOISER_VERSION_MINOR: u32 = 3;
pub const FFX_DENOISER_VERSION_PATCH: u32 = 0;
pub const FFX_DENOISER_CONTEXT_COUNT: u32 = 1;
pub const FFX_DENOISER_CONTEXT_SIZE: u32 = 73098;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[repr(u32)]
pub enum FfxDenoiserPass {
    ReprojectReflections = 5,
    PrefilterReflections = 6,
    ResolveTemporalReflections = 7,
}

pub const FFX_DENOISER_REFLECTIONS: u32 = 1 << 1;
pub const FFX_DENOISER_ENABLE_DEPTH_INVERTED: u32 = 1 << 2;

#[derive(Clone)]
pub struct FfxDenoiserContextDescription {
    /// Set `FFX_DENOISER_REFLECTIONS` and, for reversed Z, `FFX_DENOISER_ENABLE_DEPTH_INVERTED`.
    pub flags: u32,
    pub window_size: FfxDimensions2D,
    /// Must match the current normal image for the frame-end history copy.
    pub normals_history_buffer_format: FfxSurfaceFormat,
    pub backend_interface: FfxInterfaceRef,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct FfxDenoiserReflectionsDispatchDescription {
    pub command_list: FfxCommandList,
    pub depth_hierarchy: FfxResource,
    pub motion_vectors: FfxResource,
    pub normal: FfxResource,
    /// Current noisy RGB radiance and reflected ray length in alpha. Receives the resolved result.
    pub radiance_a: FfxResource,
    /// Last frame's resolved radiance. Becomes scratch after reprojection reads it.
    pub radiance_b: FfxResource,
    /// Receives current variance; this becomes next frame's `variance_b`.
    pub variance_a: FfxResource,
    pub variance_b: FfxResource,
    /// R8_UNORM roughness, matching the SDK's internal roughness-history copy.
    pub extracted_roughness: FfxResource,
    /// Packed 8×8 tile origins, x in the low 16 bits and y in the high 16 bits.
    pub denoiser_tile_list: FfxResource,
    /// The denoiser reads the dispatch dimensions at byte offset 12.
    pub indirect_arguments_buffer: FfxResource,
    /// Destination for a full copy of the resolved radiance. Its alpha duplicates blue.
    pub output: FfxResource,
    /// Mirrors the SDK dispatch field. SDK 1.1.4 stages dimensions from the context's window size.
    pub render_size: FfxDimensions2D,
    pub motion_vector_scale: FfxFloatCoords2D,
    /// Column-major matrices.
    pub inv_projection: [f32; 16],
    pub inv_view: [f32; 16],
    pub prev_view_projection: [f32; 16],
    pub normals_unpack_mul: f32,
    pub normals_unpack_add: f32,
    pub is_roughness_perceptual: bool,
    pub roughness_channel: u32,
    pub temporal_stability_factor: f32,
    pub roughness_threshold: f32,
    pub frame_index: u32,
    /// Clears both internal average-radiance surfaces before reprojection.
    pub reset: bool,
}

#[derive(Default)]
pub struct FfxDenoiserContext {
    pub(crate) private: Option<Box<private::FfxDenoiserContextPrivate>>,
}
