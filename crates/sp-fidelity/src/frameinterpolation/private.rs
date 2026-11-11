//! Port of `sdk/src/components/frameinterpolation/ffx_frameinterpolation_private.h`.
use super::resources::*;
use super::*;
pub const FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS: u32 = 1 << 0;
pub const FRAMEINTERPOLATION_SHADER_PERMUTATION_JITTER_MOTION_VECTORS: u32 = 1 << 1;
pub const FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED: u32 = 1 << 2;
pub const FRAMEINTERPOLATION_SHADER_PERMUTATION_FORCE_WAVE64: u32 = 1 << 3;
pub const FRAMEINTERPOLATION_SHADER_PERMUTATION_ALLOW_FP16: u32 = 1 << 4;

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct FrameInterpolationConstants {
    pub render_size: [i32; 2],
    pub display_size: [i32; 2],
    pub display_size_rcp: [f32; 2],
    pub camera_near: f32,
    pub camera_far: f32,
    pub upscaler_target_size: [i32; 2],
    pub mode: i32,
    pub reset: i32,
    pub device_to_view_depth: [f32; 4],
    pub delta_time: f32,
    pub hud_less_attached_factor: i32,
    pub distortion_field_size: [i32; 2],
    pub optical_flow_scale: [f32; 2],
    pub optical_flow_block_size: i32,
    pub dispatch_flags: u32,
    pub max_render_size: [i32; 2],
    pub optical_flow_half_res_mode: i32,
    pub num_instances: i32,
    pub interpolation_rect_base: [i32; 2],
    pub interpolation_rect_size: [i32; 2],
    pub debug_bar_color: [f32; 3],
    pub back_buffer_transfer_function: u32,
    pub min_max_luminance: [f32; 2],
    pub f_tan_half_fov: f32,
    pub _pad1: f32,
    pub jitter: [f32; 2],
    pub motion_vector_scale: [f32; 2],
}
impl FrameInterpolationConstants {
    pub const WORDS: u32 = 44;
    pub fn words(&self) -> Vec<u32> {
        let mut w = Vec::with_capacity(Self::WORDS as usize);
        w.extend(self.render_size.map(|v| v.cast_unsigned()));
        w.extend(self.display_size.map(|v| v.cast_unsigned()));
        w.extend(self.display_size_rcp.map(|v| v.to_bits()));
        w.push(self.camera_near.to_bits());
        w.push(self.camera_far.to_bits());
        w.extend(self.upscaler_target_size.map(|v| v.cast_unsigned()));
        w.push(self.mode.cast_unsigned());
        w.push(self.reset.cast_unsigned());
        w.extend(self.device_to_view_depth.map(|v| v.to_bits()));
        w.push(self.delta_time.to_bits());
        w.push(self.hud_less_attached_factor.cast_unsigned());
        w.extend(self.distortion_field_size.map(|v| v.cast_unsigned()));
        w.extend(self.optical_flow_scale.map(|v| v.to_bits()));
        w.push(self.optical_flow_block_size.cast_unsigned());
        w.push(self.dispatch_flags);
        w.extend(self.max_render_size.map(|v| v.cast_unsigned()));
        w.push(self.optical_flow_half_res_mode.cast_unsigned());
        w.push(self.num_instances.cast_unsigned());
        w.extend(self.interpolation_rect_base.map(|v| v.cast_unsigned()));
        w.extend(self.interpolation_rect_size.map(|v| v.cast_unsigned()));
        w.extend(self.debug_bar_color.map(|v| v.to_bits()));
        w.push(self.back_buffer_transfer_function);
        w.extend(self.min_max_luminance.map(|v| v.to_bits()));
        w.push(self.f_tan_half_fov.to_bits());
        w.push(self._pad1.to_bits());
        w.extend(self.jitter.map(|v| v.to_bits()));
        w.extend(self.motion_vector_scale.map(|v| v.to_bits()));
        w
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct InpaintingPyramidConstants {
    pub mips: u32,
    pub numwork_groups: u32,
    pub work_group_offset: [u32; 2],
}
impl InpaintingPyramidConstants {
    pub const WORDS: u32 = 4;
    pub fn words(&self) -> Vec<u32> {
        let mut w = Vec::with_capacity(Self::WORDS as usize);
        w.push(self.mips);
        w.push(self.numwork_groups);
        w.extend(self.work_group_offset.map(|v| v));
        w
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct FfxFrameInterpolationRenderDescription {
    pub render_size: FfxDimensions2D,
    pub upscale_size: FfxDimensions2D,
    pub camera_near: f32,
    pub camera_far: f32,
    pub camera_fov_angle_vertical: f32,
    pub view_space_to_meters_factor: f32,
    pub motion_vector_scale: FfxFloatCoords2D,
}
pub struct FfxFrameInterpolationContextPrivate {
    pub context_description: FfxFrameInterpolationContextDescription,
    pub effect_context_id: FfxUInt32,
    pub render_description: FfxFrameInterpolationRenderDescription,
    pub constants: FrameInterpolationConstants,
    pub inpainting_pyramid_contants: InpaintingPyramidConstants,
    pub device: FfxDevice,
    pub device_capabilities: FfxDeviceCapabilities,
    pub pipeline_fi_reconstruct_and_dilate: FfxPipelineState,
    pub pipeline_fi_setup: FfxPipelineState,
    pub pipeline_fi_reconstruct_previous_depth: FfxPipelineState,
    pub pipeline_fi_game_motion_vector_field: FfxPipelineState,
    pub pipeline_fi_optical_flow_vector_field: FfxPipelineState,
    pub pipeline_fi_disocclusion_mask: FfxPipelineState,
    pub pipeline_fi_scfi: FfxPipelineState,
    pub pipeline_inpainting_pyramid: FfxPipelineState,
    pub pipeline_inpainting: FfxPipelineState,
    pub pipeline_game_vector_field_inpainting_pyramid: FfxPipelineState,
    pub pipeline_debug_view: FfxPipelineState,
    pub constant_buffers: [FfxConstantBuffer; FFX_FRAMEINTERPOLATION_CONSTANTBUFFER_COUNT as usize],
    pub srv_resources:
        [FfxResourceInternal; FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT as usize],
    pub uav_resources:
        [FfxResourceInternal; FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNT as usize],
    pub first_execution: bool,
    pub refresh_pipeline_states: bool,
    pub async_supported: bool,
    pub previous_frame_id: u64,
    pub dispatch_count: u64,
}
impl FfxFrameInterpolationContextPrivate {
    pub fn zeroed(context_description: FfxFrameInterpolationContextDescription) -> Self {
        Self {
            context_description,
            effect_context_id: Default::default(),
            render_description: Default::default(),
            constants: Default::default(),
            inpainting_pyramid_contants: Default::default(),
            device: Default::default(),
            device_capabilities: Default::default(),
            pipeline_fi_reconstruct_and_dilate: Default::default(),
            pipeline_fi_setup: Default::default(),
            pipeline_fi_reconstruct_previous_depth: Default::default(),
            pipeline_fi_game_motion_vector_field: Default::default(),
            pipeline_fi_optical_flow_vector_field: Default::default(),
            pipeline_fi_disocclusion_mask: Default::default(),
            pipeline_fi_scfi: Default::default(),
            pipeline_inpainting_pyramid: Default::default(),
            pipeline_inpainting: Default::default(),
            pipeline_game_vector_field_inpainting_pyramid: Default::default(),
            pipeline_debug_view: Default::default(),
            constant_buffers: std::array::from_fn(|_| Default::default()),
            srv_resources: std::array::from_fn(|_| Default::default()),
            uav_resources: std::array::from_fn(|_| Default::default()),
            first_execution: Default::default(),
            refresh_pipeline_states: Default::default(),
            async_supported: Default::default(),
            previous_frame_id: Default::default(),
            dispatch_count: Default::default(),
        }
    }
}
