//! Port of the FidelityFX SDK 1.1.4 host component.
use super::private::*;
use super::resources::*;
use super::*;
use crate::error::*;
use crate::gpu::spd::ffx_spd_setup;
use crate::interface::ffx_sdk_make_version;
use crate::object_management::*;
const SRV: &[(u32, &str)] = &[
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH,
        "r_input_depth",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_MOTION_VECTORS,
        "r_input_motion_vectors",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD,
        "r_input_distortion_field",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        "r_dilated_depth",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        "r_dilated_motion_vectors",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
        "r_reconstructed_depth_previous_frame",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
        "r_reconstructed_depth_interpolated_frame",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE,
        "r_previous_interpolation_source",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_CURRENT_INTERPOLATION_SOURCE,
        "r_current_interpolation_source",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK,
        "r_disocclusion_mask",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X,
        "r_game_motion_vector_field_x",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y,
        "r_game_motion_vector_field_y",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X,
        "r_optical_flow_motion_vector_field_x",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y,
        "r_optical_flow_motion_vector_field_y",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR,
        "r_optical_flow",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_CONFIDENCE,
        "r_optical_flow_confidence",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_GLOBAL_MOTION,
        "r_optical_flow_global_motion",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCENE_CHANGE_DETECTION,
        "r_optical_flow_scd",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT,
        "r_output",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_MASK,
        "r_inpainting_mask",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID,
        "r_inpainting_pyramid",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PRESENT_BACKBUFFER,
        "r_present_backbuffer",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNTERS,
        "r_counters",
    ),
];
const UAV: &[(u32, &str)] = &[
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        "rw_dilated_depth",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        "rw_dilated_motion_vectors",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
        "rw_reconstructed_depth_previous_frame",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
        "rw_reconstructed_depth_interpolated_frame",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT,
        "rw_output",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK,
        "rw_disocclusion_mask",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X,
        "rw_game_motion_vector_field_x",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y,
        "rw_game_motion_vector_field_y",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X,
        "rw_optical_flow_motion_vector_field_x",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y,
        "rw_optical_flow_motion_vector_field_y",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_MASK,
        "rw_inpainting_mask",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNTERS,
        "rw_counters",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_0,
        "rw_inpainting_pyramid0",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_1,
        "rw_inpainting_pyramid1",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_2,
        "rw_inpainting_pyramid2",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_3,
        "rw_inpainting_pyramid3",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_4,
        "rw_inpainting_pyramid4",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_5,
        "rw_inpainting_pyramid5",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_6,
        "rw_inpainting_pyramid6",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_7,
        "rw_inpainting_pyramid7",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_8,
        "rw_inpainting_pyramid8",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_9,
        "rw_inpainting_pyramid9",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_10,
        "rw_inpainting_pyramid10",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_11,
        "rw_inpainting_pyramid11",
    ),
    (
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_12,
        "rw_inpainting_pyramid12",
    ),
];
const CB: &[(u32, &str)] = &[
    (FFX_FRAMEINTERPOLATION_CONSTANTBUFFER_IDENTIFIER, "cbFI"),
    (
        FFX_FRAMEINTERPOLATION_INPAINTING_PYRAMID_CONSTANTBUFFER_IDENTIFIER,
        "cbInpaintingPyramid",
    ),
];
fn patch(pipeline: &mut FfxPipelineState) -> Result<(), FfxErrorCode> {
    for (bindings, table) in [
        (&mut pipeline.srv_texture_bindings, SRV),
        (&mut pipeline.uav_texture_bindings, UAV),
        (&mut pipeline.constant_buffer_bindings, CB),
        (&mut pipeline.uav_buffer_bindings, UAV),
        (&mut pipeline.srv_buffer_bindings, SRV),
    ] {
        for binding in bindings {
            binding.resource_identifier = table
                .iter()
                .find(|(_, name)| *name == binding.name)
                .ok_or(FFX_ERROR_INVALID_ARGUMENT)?
                .0;
        }
    }
    Ok(())
}
fn sampler(filter: FfxFilterType) -> FfxSamplerDescription {
    FfxSamplerDescription {
        filter,
        address_mode_u: FfxAddressMode::Clamp,
        address_mode_v: FfxAddressMode::Clamp,
        address_mode_w: FfxAddressMode::Clamp,
        stage: FFX_BIND_COMPUTE_SHADER_STAGE,
    }
}
fn uninitialized() -> FfxResourceInitData<'static> {
    FfxResourceInitData {
        r#type: FfxResourceInitDataType::Uninitialized,
        ..Default::default()
    }
}
fn resource_description(
    format: FfxSurfaceFormat,
    width: u32,
    height: u32,
    usage: FfxResourceUsage,
) -> FfxResourceDescription {
    FfxResourceDescription {
        r#type: FfxResourceType::Texture2D,
        format,
        width,
        height,
        depth: 1,
        mip_count: 1,
        flags: FFX_RESOURCE_FLAGS_NONE,
        usage,
    }
}

fn create_pipeline_states(
    context: &mut FfxFrameInterpolationContextPrivate,
) -> Result<(), FfxErrorCode> {
    let backend = context.context_description.backend_interface.clone();
    let mut backend = backend.borrow_mut();
    let caps = backend.get_device_capabilities().unwrap_or_default();
    let flags = context.context_description.flags;
    let permutation =
        if flags & FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS == 0 {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS
        } else {
            0
        } | if flags & FFX_FRAMEINTERPOLATION_ENABLE_JITTER_MOTION_VECTORS != 0 {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_JITTER_MOTION_VECTORS
        } else {
            0
        } | if flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED != 0 {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED
        } else {
            0
        } | if caps.fp16_supported {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_ALLOW_FP16
        } else {
            0
        } | if caps.wave_lane_count_min == 32
            && caps.wave_lane_count_max == 64
            && caps.maximum_supported_shader_model >= FfxShaderModel::ShaderModel6_6
        {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_FORCE_WAVE64
        } else {
            0
        };
    let samplers = [
        sampler(FfxFilterType::MinMagMipPoint),
        sampler(FfxFilterType::MinMagMipLinear),
    ];
    let constants = [
        FfxRootConstantDescription {
            size: FrameInterpolationConstants::WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
        FfxRootConstantDescription {
            size: InpaintingPyramidConstants::WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];
    for (pass, name, pipeline) in [
        (
            FfxFrameInterpolationPass::ReconstructAndDilate,
            "RECONSTRUCT_AND_DILATE",
            &mut context.pipeline_fi_reconstruct_and_dilate,
        ),
        (
            FfxFrameInterpolationPass::Setup,
            "SETUP",
            &mut context.pipeline_fi_setup,
        ),
        (
            FfxFrameInterpolationPass::ReconstructPrevDepth,
            "RECONSTRUCT_PREV_DEPTH",
            &mut context.pipeline_fi_reconstruct_previous_depth,
        ),
        (
            FfxFrameInterpolationPass::GameMotionVectorField,
            "GAME_MOTION_VECTOR_FIELD",
            &mut context.pipeline_fi_game_motion_vector_field,
        ),
        (
            FfxFrameInterpolationPass::OpticalFlowVectorField,
            "OPTICAL_FLOW_VECTOR_FIELD",
            &mut context.pipeline_fi_optical_flow_vector_field,
        ),
        (
            FfxFrameInterpolationPass::DisocclusionMask,
            "DISOCCLUSION_MASK",
            &mut context.pipeline_fi_disocclusion_mask,
        ),
        (
            FfxFrameInterpolationPass::Interpolation,
            "INTERPOLATION",
            &mut context.pipeline_fi_scfi,
        ),
        (
            FfxFrameInterpolationPass::InpaintingPyramid,
            "INPAINTING_PYRAMID",
            &mut context.pipeline_inpainting_pyramid,
        ),
        (
            FfxFrameInterpolationPass::Inpainting,
            "INPAINTING",
            &mut context.pipeline_inpainting,
        ),
        (
            FfxFrameInterpolationPass::GameVectorFieldInpaintingPyramid,
            "GAME_VECTOR_FIELD_INPAINTING_PYRAMID",
            &mut context.pipeline_game_vector_field_inpainting_pyramid,
        ),
        (
            FfxFrameInterpolationPass::DebugView,
            "DEBUG_VIEW",
            &mut context.pipeline_debug_view,
        ),
    ] {
        ffx_safe_release_pipeline(&mut *backend, pipeline, context.effect_context_id);
        let description = FfxPipelineDescription {
            context_flags: flags,
            samplers: &samplers,
            root_constants: &constants,
            name: name.into(),
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
            indirect_workload: 0,
            // The SDK sets backbufferFormat only in its unused raster lambda.
            // Every actual frame-interpolation pipeline uses the compute lambda.
            backbuffer_format: FfxSurfaceFormat::Unknown,
        };
        if let Ok(created) = backend.create_pipeline(
            FfxEffect::FrameInterpolation,
            pass as u32,
            permutation,
            &description,
            context.effect_context_id,
        ) {
            *pipeline = created;
            let _ = patch(pipeline);
        }
    }
    Ok(())
}

/// Precision groups used by the SDK to validate backbuffer/HUD-less compatibility.
pub fn get_format_precision_group(format: FfxSurfaceFormat) -> i32 {
    match format {
        FfxSurfaceFormat::R32G32B32A32Typeless
        | FfxSurfaceFormat::R32G32B32A32Float
        | FfxSurfaceFormat::R32G32B32Float => 0,
        FfxSurfaceFormat::R16G16B16A16Typeless | FfxSurfaceFormat::R16G16B16A16Float => 1,
        FfxSurfaceFormat::R8G8B8A8Typeless
        | FfxSurfaceFormat::R8G8B8A8Unorm
        | FfxSurfaceFormat::B8G8R8A8Typeless
        | FfxSurfaceFormat::B8G8R8A8Unorm => 2,
        FfxSurfaceFormat::R8G8B8A8Snorm => 3,
        FfxSurfaceFormat::R8G8B8A8Srgb | FfxSurfaceFormat::B8G8R8A8Srgb => 4,
        FfxSurfaceFormat::R11G11B10Float => 5,
        FfxSurfaceFormat::R10G10B10A2Typeless | FfxSurfaceFormat::R10G10B10A2Unorm => 6,
        FfxSurfaceFormat::R9G9B9E5Sharedexp => 7,
        _ => -1,
    }
}

pub fn ffx_frame_interpolation_context_create(
    context: &mut FfxFrameInterpolationContext,
    description: &FfxFrameInterpolationContextDescription,
) -> Result<(), FfxErrorCode> {
    let group = get_format_precision_group(description.back_buffer_format);
    if group < 0
        || group != get_format_precision_group(description.previous_interpolation_source_format)
    {
        return Err(FFX_ERROR_INVALID_ARGUMENT);
    }
    let mut private = Box::new(FfxFrameInterpolationContextPrivate::zeroed(
        description.clone(),
    ));
    let result = (|| {
        let backend = description.backend_interface.clone();
        let mut backend = backend.borrow_mut();
        private.device = backend.device();
        if backend.get_sdk_version() != ffx_sdk_make_version(1, 1, 4) {
            return Err(FFX_ERROR_INVALID_VERSION);
        }
        private.effect_context_id =
            backend.create_backend_context(FfxEffect::FrameInterpolation, None)?;
        private.device_capabilities = backend.get_device_capabilities()?;
        private.first_execution = true;
        private.async_supported =
            description.flags & FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT != 0;
        private.constants.max_render_size = [
            description.max_render_size.width as i32,
            description.max_render_size.height as i32,
        ];
        private.constants.display_size = [
            description.display_size.width as i32,
            description.display_size.height as i32,
        ];
        private.constants.display_size_rcp = [
            1.0 / description.display_size.width as f32,
            1.0 / description.display_size.height as f32,
        ];
        private.constants.interpolation_rect_size = private.constants.display_size;
        let r = description.max_render_size;
        let d = description.display_size;
        for (id, name, format, width, height, mips, flags, rtype, usage) in [
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
                "FI_ReconstructedDepthInterpolatedFrame",
                FfxSurfaceFormat::R32Uint,
                r.width,
                r.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X,
                "FI_GameMotionVectorFieldX",
                FfxSurfaceFormat::R32Uint,
                r.width,
                r.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y,
                "FI_GameMotionVectorFieldY",
                FfxSurfaceFormat::R32Uint,
                r.width,
                r.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID,
                "FI_InpaintingPyramid",
                FfxSurfaceFormat::R16G16B16A16Float,
                d.width / 2,
                d.height / 2,
                0,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNTERS,
                "FI_Counters",
                FfxSurfaceFormat::Unknown,
                8,
                4,
                1,
                FFX_RESOURCE_FLAGS_NONE,
                FfxResourceType::Buffer,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X,
                "FI_OpticalFlowMotionVectorFieldX",
                FfxSurfaceFormat::R32Uint,
                r.width,
                r.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y,
                "FI_OpticalFlowMotionVectorFieldY",
                FfxSurfaceFormat::R32Uint,
                r.width,
                r.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE,
                "FI_PreviousInterpolationSouce",
                description.previous_interpolation_source_format,
                d.width,
                d.height,
                1,
                FFX_RESOURCE_FLAGS_NONE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_MASK,
                "FI_InpaintingMask",
                FfxSurfaceFormat::R8Unorm,
                d.width,
                d.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK,
                "FI_DisocclusionMask",
                FfxSurfaceFormat::R8G8Unorm,
                r.width,
                r.height,
                1,
                FFX_RESOURCE_FLAGS_ALIASABLE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_UAV,
            ),
            (
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEFAULT_DISTORTION_FIELD,
                "FI_DefaultDistortionField",
                FfxSurfaceFormat::R8G8Unorm,
                1,
                1,
                1,
                FFX_RESOURCE_FLAGS_NONE,
                FfxResourceType::Texture2D,
                FFX_RESOURCE_USAGE_READ_ONLY,
            ),
        ] {
            let init_data =
                if id == FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEFAULT_DISTORTION_FIELD {
                    FfxResourceInitData::ffx_resource_init_buffer(2, &[0, 0])
                } else {
                    uninitialized()
                };
            let rd = FfxResourceDescription {
                r#type: rtype,
                format,
                width,
                height,
                depth: 1,
                mip_count: mips,
                flags,
                usage,
            };
            private.srv_resources[id as usize] = backend.create_resource(
                &FfxCreateResourceDescription {
                    heap_type: FfxHeapType::Default,
                    resource_description: rd,
                    initial_state: if usage == FFX_RESOURCE_USAGE_READ_ONLY {
                        FFX_RESOURCE_STATE_COMPUTE_READ
                    } else {
                        FFX_RESOURCE_STATE_UNORDERED_ACCESS
                    },
                    name,
                    id,
                    init_data,
                },
                private.effect_context_id,
            )?;
        }
        private.uav_resources = private.srv_resources;
        drop(backend);
        create_pipeline_states(&mut private)
    })();
    context.private = Some(private);
    result
}

pub fn ffx_frame_interpolation_get_shared_resource_descriptions(
    context: &FfxFrameInterpolationContext,
) -> Result<FfxFrameInterpolationSharedResourceDescriptions<'static>, FfxErrorCode> {
    let context = context.private.as_ref().ok_or(FFX_ERROR_INVALID_POINTER)?;
    let r = context.context_description.max_render_size;
    let create = |format, name, id, usage| FfxCreateResourceDescription {
        heap_type: FfxHeapType::Default,
        resource_description: resource_description(format, r.width, r.height, usage),
        initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
        name,
        id,
        init_data: uninitialized(),
    };
    let usage = FFX_RESOURCE_USAGE_RENDERTARGET
        | FFX_RESOURCE_USAGE_UAV
        | FFX_RESOURCE_USAGE_DCC_RENDERTARGET;
    Ok(FfxFrameInterpolationSharedResourceDescriptions {
        dilated_depth: create(
            FfxSurfaceFormat::R32Float,
            "FISHARED_DilatedDepth",
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
            usage,
        ),
        dilated_motion_vectors: create(
            FfxSurfaceFormat::R16G16Float,
            "FISHARED_DilatedVelocity",
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
            usage,
        ),
        reconstructed_prev_nearest_depth: create(
            FfxSurfaceFormat::R32Uint,
            "FISHARED_ReconstructedPrevNearestDepth",
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
            FFX_RESOURCE_USAGE_UAV,
        ),
    })
}

pub fn ffx_frame_interpolation_context_get_gpu_memory_usage(
    context: &FfxFrameInterpolationContext,
) -> Result<FfxEffectMemoryUsage, FfxErrorCode> {
    let context = context.private.as_ref().ok_or(FFX_ERROR_INVALID_POINTER)?;
    if context.device == 0 {
        return Err(FFX_ERROR_NULL_DEVICE);
    }
    context
        .context_description
        .backend_interface
        .borrow_mut()
        .get_effect_gpu_memory_usage(context.effect_context_id)
}
pub fn ffx_shared_context_get_gpu_memory_usage(
    backend_interface: &FfxInterfaceRef,
) -> Result<FfxEffectMemoryUsage, FfxErrorCode> {
    backend_interface
        .borrow_mut()
        .get_effect_gpu_memory_usage(0)
}
pub fn ffx_frame_interpolation_resource_is_null(resource: &FfxResource) -> bool {
    resource.resource == 0
}
pub fn ffx_frame_interpolation_get_effect_version() -> FfxVersionNumber {
    ffx_sdk_make_version(
        FFX_FRAMEINTERPOLATION_VERSION_MAJOR,
        FFX_FRAMEINTERPOLATION_VERSION_MINOR,
        FFX_FRAMEINTERPOLATION_VERSION_PATCH,
    )
}
pub fn ffx_frame_interpolation_set_global_debug_message(
    callback: Option<FfxMessageCallback>,
    debug_level: u32,
) -> Result<(), FfxErrorCode> {
    crate::message::ffx_set_print_message_callback(callback, debug_level);
    Ok(())
}
pub fn ffx_frame_interpolation_context_enqueue_refresh_pipeline_request(
    context: &mut FfxFrameInterpolationContext,
) -> Result<(), FfxErrorCode> {
    context
        .private
        .as_mut()
        .ok_or(FFX_ERROR_INVALID_POINTER)?
        .refresh_pipeline_states = true;
    Ok(())
}

pub fn ffx_frame_interpolation_context_destroy(
    context: &mut FfxFrameInterpolationContext,
) -> Result<(), FfxErrorCode> {
    let mut context = context.private.take().ok_or(FFX_ERROR_INVALID_POINTER)?;
    let mut backend = context.context_description.backend_interface.borrow_mut();
    context
        .outgoing
        .destroy(&mut *backend, context.effect_context_id);
    for pipeline in [
        &mut context.pipeline_fi_reconstruct_and_dilate,
        &mut context.pipeline_fi_setup,
        &mut context.pipeline_fi_reconstruct_previous_depth,
        &mut context.pipeline_fi_game_motion_vector_field,
        &mut context.pipeline_fi_optical_flow_vector_field,
        &mut context.pipeline_fi_disocclusion_mask,
        &mut context.pipeline_fi_scfi,
        &mut context.pipeline_inpainting_pyramid,
        &mut context.pipeline_inpainting,
        &mut context.pipeline_game_vector_field_inpainting_pyramid,
        &mut context.pipeline_debug_view,
    ] {
        ffx_safe_release_pipeline(&mut *backend, pipeline, context.effect_context_id);
    }
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_CURRENT_INTERPOLATION_SOURCE,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_CONFIDENCE,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_GLOBAL_MOTION,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCENE_CHANGE_DETECTION,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD,
    ] {
        context.srv_resources[id as usize] = Default::default();
    }
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
    ] {
        context.uav_resources[id as usize] = Default::default();
    }
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNTERS,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEFAULT_DISTORTION_FIELD,
    ] {
        ffx_safe_release_copy_resource(
            &mut *backend,
            context.srv_resources[id as usize],
            context.effect_context_id,
        );
    }
    for resource in context.srv_resources {
        ffx_safe_release_resource(&mut *backend, resource, context.effect_context_id);
    }
    let _ = backend.destroy_backend_context(context.effect_context_id);
    Ok(())
}

fn schedule(
    context: &FfxFrameInterpolationContextPrivate,
    pipeline: &FfxPipelineState,
    x: u32,
    y: u32,
) {
    let job=FfxComputeJobDescription {pipeline:pipeline.clone(),dimensions:[x,y,1],
 srv_textures:pipeline.srv_texture_bindings.iter().map(|b|FfxTextureSRV {resource:context.srv_resources[b.resource_identifier as usize]}).collect(),
 uav_textures:pipeline.uav_texture_bindings.iter().map(|b| {let id=b.resource_identifier;if (FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_0..=FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_12).contains(&id) {FfxTextureUAV {resource:context.uav_resources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID as usize],mip:id-FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID_MIPMAP_0}} else {FfxTextureUAV {resource:context.uav_resources[id as usize],mip:0}}}).collect(),
 srv_buffers:pipeline.srv_buffer_bindings.iter().map(|b|FfxBufferSRV {resource:context.srv_resources[b.resource_identifier as usize],..Default::default()}).collect(),uav_buffers:pipeline.uav_buffer_bindings.iter().map(|b|FfxBufferUAV {resource:context.uav_resources[b.resource_identifier as usize],..Default::default()}).collect(),
 cbs:pipeline.constant_buffer_bindings.iter().map(|b|context.constant_buffers[b.resource_identifier as usize].clone()).collect(),..Default::default()};
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: pipeline.name.clone(),
            descriptor: FfxGpuJobDescriptor::Compute(Box::new(job)),
        });
}
fn register(
    context: &mut FfxFrameInterpolationContextPrivate,
    resource: &FfxResource,
    index: u32,
    uav: bool,
) {
    if let Ok(resource) = context
        .context_description
        .backend_interface
        .borrow_mut()
        .register_resource(resource, context.effect_context_id)
    {
        if uav {
            context.uav_resources[index as usize] = resource;
        } else {
            context.srv_resources[index as usize] = resource;
        }
    }
}
fn clear_depth(context: &FfxFrameInterpolationContextPrivate, id: u32, name: &str) {
    let depth =
        if context.context_description.flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED != 0 {
            0.0
        } else {
            1.0
        };
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: name.into(),
            descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                target: context.uav_resources[id as usize],
                color: [depth; 4],
            }),
        });
}
fn stage(context: &mut FfxFrameInterpolationContextPrivate) {
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .stage_constant_buffer_data_func(
            &context.constants.words(),
            &mut context.constant_buffers[0],
        );
}

pub fn ffx_frame_interpolation_prepare(
    context: &mut FfxFrameInterpolationContext,
    params: &FfxFrameInterpolationPrepareDescription,
) -> Result<(), FfxErrorCode> {
    let context = context.private.as_mut().ok_or(FFX_ERROR_INVALID_POINTER)?;
    super::outgoing::prepare(context, params)?;
    if context.context_description.flags & FFX_FRAMEINTERPOLATION_ENABLE_DEBUG_CHECKING != 0
        && [
            params.camera_position,
            params.camera_up,
            params.camera_right,
            params.camera_forward,
        ]
        .iter()
        .all(|v| v.iter().all(|f| f.to_bits() == 0))
    {
        crate::message::ffx_print_message(
            FfxMsgType::Warning as u32,
            "ffxDispatchDescFrameGenerationPrepareCameraInfo needs to be passed as linked struct. This is a required input to FSR3.1.4 and onwards for best quality.",
        );
    }
    context.constants.render_size = [
        params.render_size.width as i32,
        params.render_size.height as i32,
    ];
    context.constants.jitter = [params.jitter_offset.x, params.jitter_offset.y];
    let target = if context.context_description.flags
        & FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
        != 0
    {
        context.constants.display_size
    } else {
        context.constants.render_size
    };
    context.constants.motion_vector_scale = [
        params.motion_vector_scale.x / target[0] as f32,
        params.motion_vector_scale.y / target[1] as f32,
    ];
    stage(context);
    crate::assert::ffx_assert!(!ffx_frame_interpolation_resource_is_null(&params.depth));
    crate::assert::ffx_assert!(!ffx_frame_interpolation_resource_is_null(
        &params.motion_vectors
    ));
    register(
        context,
        &params.depth,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH,
        false,
    );
    register(
        context,
        &params.motion_vectors,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_MOTION_VECTORS,
        false,
    );
    register(
        context,
        &params.dilated_depth,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        true,
    );
    register(
        context,
        &params.dilated_motion_vectors,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        true,
    );
    register(
        context,
        &params.reconstructed_prev_depth,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
        true,
    );
    let outgoing_result = super::outgoing::capture(context);
    clear_depth(
        context,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
        "Clear Reconstructed Previous Nearest Depth",
    );
    schedule(
        context,
        &context.pipeline_fi_reconstruct_and_dilate,
        params.render_size.width.div_ceil(8),
        params.render_size.height.div_ceil(8),
    );
    let executed = context
        .context_description
        .backend_interface
        .borrow_mut()
        .execute_gpu_jobs(params.command_list, context.effect_context_id);
    let unregistered = context
        .context_description
        .backend_interface
        .borrow_mut()
        .unregister_resources(params.command_list, context.effect_context_id);
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_MOTION_VECTORS,
    ] {
        context.srv_resources[id as usize] = Default::default();
    }
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
    ] {
        context.uav_resources[id as usize] = Default::default();
    }
    let result = outgoing_result.and(executed).and(unregistered);
    super::outgoing::finish(context, result.is_ok(), false);
    result
}

fn setup_device_depth(context: &mut FfxFrameInterpolationContextPrivate) {
    let params = context.render_description;
    let inverted =
        context.context_description.flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED != 0;
    let infinite =
        context.context_description.flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE != 0;
    let mut min = params.camera_near.min(params.camera_far);
    let mut max = params.camera_near.max(params.camera_far);
    if inverted {
        std::mem::swap(&mut min, &mut max);
    }
    let q = max / (min - max);
    let c = [[q, -1.0 - f32::EPSILON], [q, f32::EPSILON]][inverted as usize][infinite as usize];
    let e = [[q * min, -min - f32::EPSILON], [q * min, max]][inverted as usize][infinite as usize];
    let aspect = params.render_size.width as f32 / params.render_size.height as f32;
    let cot = (0.5 * params.camera_fov_angle_vertical).cos()
        / (0.5 * params.camera_fov_angle_vertical).sin();
    context.constants.device_to_view_depth = [
        -c,
        e * params.view_space_to_meters_factor,
        1.0 / (cot / aspect),
        1.0 / cot,
    ];
}
fn pyramid(
    context: &mut FfxFrameInterpolationContextPrivate,
    dimensions: FfxDimensions2D,
    game: bool,
) {
    let mut groups = [0; 2];
    let mut offset = [0; 2];
    let mut num = [0; 2];
    ffx_spd_setup(
        &mut groups,
        &mut offset,
        &mut num,
        [0, 0, dimensions.width, dimensions.height],
    );
    context.inpainting_pyramid_contants = InpaintingPyramidConstants {
        mips: num[1],
        numwork_groups: num[0],
        work_group_offset: offset,
    };
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .stage_constant_buffer_data_func(
            &context.inpainting_pyramid_contants.words(),
            &mut context.constant_buffers
                [FFX_FRAMEINTERPOLATION_INPAINTING_PYRAMID_CONSTANTBUFFER_IDENTIFIER as usize],
        );
    let pipeline = if game {
        &context.pipeline_game_vector_field_inpainting_pyramid
    } else {
        &context.pipeline_inpainting_pyramid
    };
    schedule(context, pipeline, groups[0], groups[1]);
}

pub fn ffx_frame_interpolation_dispatch(
    context: &mut FfxFrameInterpolationContext,
    params: &FfxFrameInterpolationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    let context = context.private.as_mut().ok_or(FFX_ERROR_INVALID_POINTER)?;
    if context.refresh_pipeline_states {
        let _ = create_pipeline_states(context);
        context.refresh_pipeline_states = false;
    }
    let reset = context.dispatch_count == 0 || params.reset;
    crate::assert::ffx_assert!(
        !context.async_supported || reset || params.frame_id > context.previous_frame_id
    );
    let disjoint = params.frame_id < context.previous_frame_id
        || params.frame_id.wrapping_sub(context.previous_frame_id) > 1;
    context.previous_frame_id = params.frame_id;
    context.dispatch_count = context.dispatch_count.wrapping_add(1);
    let c = &mut context.constants;
    c.render_size = [
        params.render_size.width as i32,
        params.render_size.height as i32,
    ];
    c.display_size = [
        params.display_size.width as i32,
        params.display_size.height as i32,
    ];
    c.display_size_rcp = [
        1.0 / params.display_size.width as f32,
        1.0 / params.display_size.height as f32,
    ];
    c.upscaler_target_size = [
        params.interpolation_rect.width,
        params.interpolation_rect.height,
    ];
    c.mode = 0;
    c.reset = (reset || disjoint) as i32;
    c.delta_time = params.frame_time_delta;
    c.hud_less_attached_factor = (params.current_back_buffer_hud_less.resource != 0) as i32;
    c.optical_flow_scale = [params.optical_flow_scale.x, params.optical_flow_scale.y];
    c.optical_flow_block_size = params.optical_flow_block_size;
    c.dispatch_flags = params.flags;
    c.camera_near = params.camera_near;
    c.camera_far = params.camera_far;
    c.interpolation_rect_base = [
        params.interpolation_rect.left,
        params.interpolation_rect.top,
    ];
    c.interpolation_rect_size = [
        params.interpolation_rect.width,
        params.interpolation_rect.height,
    ];
    static DEBUG_INDEX: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
    const COLORS: [[f32; 3]; 7] = [
        [0.0, 1.0, 1.0],
        [1.0, 0.42, 0.0],
        [0.0, 0.16, 1.0],
        [0.74, 1.0, 0.0],
        [0.68, 0.0, 1.0],
        [0.0, 1.0, 0.1],
        [1.0, 1.0, 0.48],
    ];
    c.debug_bar_color = COLORS[DEBUG_INDEX.fetch_add(1, std::sync::atomic::Ordering::Relaxed) % 7];
    c.back_buffer_transfer_function = params.back_buffer_transfer_function as u32;
    c.min_max_luminance = params.min_max_luminance;
    let aspect = params.render_size.width as f32 / params.render_size.height as f32;
    let horizontal = ((params.camera_fov_angle_vertical / 2.0).tan() * aspect).atan() * 2.0;
    c.f_tan_half_fov = (horizontal * 0.5).tan();
    let distortion = params.distortion_field.resource != 0;
    c.distortion_field_size = if distortion {
        [
            params.distortion_field.description.width as i32,
            params.distortion_field.description.height as i32,
        ]
    } else {
        [1, 1]
    };
    context.render_description.camera_far = params.camera_far;
    context.render_description.camera_near = params.camera_near;
    context.render_description.view_space_to_meters_factor =
        if params.view_space_to_meters_factor > 0.0 {
            params.view_space_to_meters_factor
        } else {
            1.0
        };
    context.render_description.camera_fov_angle_vertical = params.camera_fov_angle_vertical;
    context.render_description.render_size = params.render_size;
    context.render_description.upscale_size = params.display_size;
    setup_device_depth(context);
    super::outgoing::begin_dispatch(context, params);
    stage(context);
    if context.constants.hud_less_attached_factor == 1 {
        crate::assert::ffx_assert!(
            context
                .context_description
                .previous_interpolation_source_format
                == params.current_back_buffer_hud_less.description.format
        );
        register(
            context,
            &params.current_back_buffer,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PRESENT_BACKBUFFER,
            false,
        );
        register(
            context,
            &params.current_back_buffer_hud_less,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_CURRENT_INTERPOLATION_SOURCE,
            false,
        );
    } else {
        crate::assert::ffx_assert!(
            context
                .context_description
                .previous_interpolation_source_format
                == params.current_back_buffer.description.format
        );
        register(
            context,
            &params.current_back_buffer,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_CURRENT_INTERPOLATION_SOURCE,
            false,
        );
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PRESENT_BACKBUFFER as usize] = context
            .srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_CURRENT_INTERPOLATION_SOURCE as usize];
    }
    for (resource, id) in [
        (
            &params.dilated_depth,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        ),
        (
            &params.dilated_motion_vectors,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        ),
        (
            &params.reconstructed_prev_depth,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME,
        ),
    ] {
        if resource.resource != 0 {
            register(context, resource, id, false);
        }
    }
    register(
        context,
        &params.output,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT,
        true,
    );
    context.srv_resources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT as usize] =
        context.uav_resources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OUTPUT as usize];
    if params.optical_flow_scale.x > 0.0 {
        register(
            context,
            &params.optical_flow_vector,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR,
            false,
        );
        register(
            context,
            &params.optical_flow_scene_change_detection,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCENE_CHANGE_DETECTION,
            false,
        );
    } else {
        for id in [
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_CONFIDENCE,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_GLOBAL_MOTION,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCENE_CHANGE_DETECTION,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR,
        ] {
            context.srv_resources[id as usize] = Default::default();
        }
    }
    if distortion {
        register(
            context,
            &params.distortion_field,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD,
            false,
        );
    } else {
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD as usize] = context
            .srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEFAULT_DISTORTION_FIELD as usize];
    }
    let display = [
        params.display_size.width.div_ceil(8),
        params.display_size.height.div_ceil(8),
    ];
    let render = [
        params.render_size.width.div_ceil(8),
        params.render_size.height.div_ceil(8),
    ];
    let optical = [
        ((params.display_size.width as f32 / params.optical_flow_block_size as f32 + 7.0) as u32)
            / 8,
        ((params.display_size.height as f32 / params.optical_flow_block_size as f32 + 7.0) as u32)
            / 8,
    ];
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_MASK,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK,
    ] {
        let _ = context
            .context_description
            .backend_interface
            .borrow_mut()
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: String::new(),
                descriptor: FfxGpuJobDescriptor::Discard(FfxDiscardJobDescription {
                    target: context.uav_resources[id as usize],
                }),
            });
    }
    schedule(context, &context.pipeline_fi_setup, render[0], render[1]);
    let mut current_geometry_result = Ok(());
    if context.constants.reset == 0 {
        clear_depth(
            context,
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
            "Clear Reconstructed Depth Interpolated Frame",
        );
        schedule(
            context,
            &context.pipeline_fi_reconstruct_previous_depth,
            render[0],
            render[1],
        );
        schedule(
            context,
            &context.pipeline_fi_game_motion_vector_field,
            render[0],
            render[1],
        );
        current_geometry_result = super::outgoing::reconstruct_current(context, params);
        pyramid(context, params.render_size, true);
        schedule(
            context,
            &context.pipeline_fi_optical_flow_vector_field,
            optical[0],
            optical[1],
        );
        schedule(
            context,
            &context.pipeline_fi_disocclusion_mask,
            render[0],
            render[1],
        );
    }
    let outgoing_result = super::outgoing::reconstruct(context, params);
    schedule(context, &context.pipeline_fi_scfi, display[0], display[1]);
    pyramid(context, params.display_size, false);
    schedule(
        context,
        &context.pipeline_inpainting,
        display[0],
        display[1],
    );
    if params.flags & FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW != 0 {
        pyramid(context, params.render_size, true);
        schedule(
            context,
            &context.pipeline_debug_view,
            display[0],
            display[1],
        );
    }
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: String::new(),
            descriptor: FfxGpuJobDescriptor::Copy(FfxCopyJobDescription {
                src: context.srv_resources
                    [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_CURRENT_INTERPOLATION_SOURCE
                        as usize],
                dst: context.uav_resources
                    [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE
                        as usize],
                ..Default::default()
            }),
        });
    for id in [
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNTERS,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_PREVIOUS_INTERPOLATION_SOURCE,
        FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK,
    ] {
        let _ = context
            .context_description
            .backend_interface
            .borrow_mut()
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: String::new(),
                descriptor: FfxGpuJobDescriptor::Barrier(FfxBarrierDescription {
                    resource: context.srv_resources[id as usize],
                    sub_resource_id: 0,
                    new_state: if id == FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_COUNTERS {
                        FFX_RESOURCE_STATE_COPY_DEST
                    } else {
                        FFX_RESOURCE_STATE_UNORDERED_ACCESS
                    },
                    current_state: 0,
                    barrier_type: FfxBarrierType::Transition,
                }),
            });
    }
    let retained = super::outgoing::retain_distortion(context, params);
    let executed = context
        .context_description
        .backend_interface
        .borrow_mut()
        .execute_gpu_jobs(params.command_list, context.effect_context_id);
    let unregistered = context
        .context_description
        .backend_interface
        .borrow_mut()
        .unregister_resources(params.command_list, context.effect_context_id);
    let result = current_geometry_result
        .and(outgoing_result)
        .and(retained)
        .and(executed)
        .and(unregistered);
    super::outgoing::finish(context, result.is_ok(), true);
    result
}
