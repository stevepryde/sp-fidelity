//! Port of `components/fsr3upscaler/ffx_fsr3upscaler.cpp` (SDK 1.1.4, FSR 3.1.4).
//! The `_GAMING_XBOX` shader-permutation branch is not ported.
use super::private::*;
use super::resources::*;
use super::*;
use crate::error::*;
use crate::gpu::fsr1::fsr_rcas_con;
use crate::gpu::spd::ffx_spd_setup;
use crate::interface::{FfxInterfaceRef, FfxPass, ffx_sdk_make_version};
use crate::message::{ffx_print_message, ffx_set_print_message_callback};
use crate::object_management::{
    ffx_safe_release_copy_resource, ffx_safe_release_pipeline, ffx_safe_release_resource,
};
use crate::util::{FFX_EPSILON, FFX_PI};

const FSR3UPSCALER_MAX_QUEUED_FRAMES: u32 = 16;

struct ResourceBinding {
    index: u32,
    name: &'static str,
}
const fn resource_binding(index: u32, name: &'static str) -> ResourceBinding {
    ResourceBinding { index, name }
}

const SRV_TEXTURE_BINDING_TABLE: &[ResourceBinding] = &[
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_COLOR,
        "r_input_color_jittered",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY,
        "r_input_opaque_only",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS,
        "r_input_motion_vectors",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_DEPTH,
        "r_input_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_EXPOSURE,
        "r_input_exposure",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FRAME_INFO,
        "r_frame_info",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK,
        "r_reactive_mask",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK,
        "r_transparency_and_composition_mask",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
        "r_reconstructed_previous_nearest_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        "r_dilated_motion_vectors",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        "r_dilated_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR,
        "r_internal_upscaled_color",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION,
        "r_accumulation",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY,
        "r_luma_history",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RCAS_INPUT,
        "r_rcas_input",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LANCZOS_LUT,
        "r_lanczos_lut",
    ),
    resource_binding(FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS, "r_spd_mips"),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
        "r_dilated_reactive_masks",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_NEW_LOCKS,
        "r_new_locks",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH,
        "r_farthest_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH_MIP1,
        "r_farthest_depth_mip1",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SHADING_CHANGE,
        "r_shading_change",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_CURRENT_LUMA,
        "r_current_luma",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_PREVIOUS_LUMA,
        "r_previous_luma",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_INSTABILITY,
        "r_luma_instability",
    ),
];

const UAV_TEXTURE_BINDING_TABLE: &[ResourceBinding] = &[
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
        "rw_reconstructed_previous_nearest_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        "rw_dilated_motion_vectors",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        "rw_dilated_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR,
        "rw_internal_upscaled_color",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION,
        "rw_accumulation",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY,
        "rw_luma_history",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_UPSCALED_OUTPUT,
        "rw_upscaled_output",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
        "rw_dilated_reactive_masks",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FRAME_INFO,
        "rw_frame_info",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT,
        "rw_spd_global_atomic",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_NEW_LOCKS,
        "rw_new_locks",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_AUTOREACTIVE,
        "rw_output_autoreactive",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SHADING_CHANGE,
        "rw_shading_change",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH,
        "rw_farthest_depth",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH_MIP1,
        "rw_farthest_depth_mip1",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_CURRENT_LUMA,
        "rw_current_luma",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_INSTABILITY,
        "rw_luma_instability",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_0,
        "rw_spd_mip0",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_1,
        "rw_spd_mip1",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_2,
        "rw_spd_mip2",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_3,
        "rw_spd_mip3",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_4,
        "rw_spd_mip4",
    ),
    resource_binding(
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_5,
        "rw_spd_mip5",
    ),
];

const CONSTANT_BUFFER_BINDING_TABLE: &[ResourceBinding] = &[
    resource_binding(
        FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_FSR3UPSCALER,
        "cbFSR3Upscaler",
    ),
    resource_binding(FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_SPD, "cbSPD"),
    resource_binding(FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_RCAS, "cbRCAS"),
    resource_binding(
        FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_GENREACTIVE,
        "cbGenerateReactive",
    ),
];

/// `Fsr3UpscalerRcasConstants` (`FfxRcasConstants`).
#[derive(Clone, Copy, Default)]
struct Fsr3UpscalerRcasConstants {
    rcas_config: [u32; 4],
}

impl Fsr3UpscalerRcasConstants {
    fn words(&self) -> Vec<u32> {
        self.rcas_config.to_vec()
    }
}

/// `Fsr3UpscalerSpdConstants`.
#[derive(Clone, Copy, Default)]
struct Fsr3UpscalerSpdConstants {
    mips: u32,
    numwork_groups: u32,
    work_group_offset: [u32; 2],
    render_size: [u32; 2],
}

impl Fsr3UpscalerSpdConstants {
    fn words(&self) -> Vec<u32> {
        vec![
            self.mips,
            self.numwork_groups,
            self.work_group_offset[0],
            self.work_group_offset[1],
            self.render_size[0],
            self.render_size[1],
        ]
    }
}

/// `Fsr3UpscalerGenerateReactiveConstants`.
#[derive(Clone, Copy, Default)]
struct Fsr3UpscalerGenerateReactiveConstants {
    scale: f32,
    threshold: f32,
    binary_value: f32,
    flags: u32,
}

impl Fsr3UpscalerGenerateReactiveConstants {
    fn words(&self) -> Vec<u32> {
        vec![
            self.scale.to_bits(),
            self.threshold.to_bits(),
            self.binary_value.to_bits(),
            self.flags,
        ]
    }
}

const FSR3UPSCALER_SECONDARY_UNION_WORDS: u32 = 6;

/// `lanczos2`.
fn lanczos2(value: f32) -> f32 {
    if value.abs() < FFX_EPSILON {
        1.0
    } else {
        ((FFX_PI * value).sin() / (FFX_PI * value))
            * ((0.5 * FFX_PI * value).sin() / (0.5 * FFX_PI * value))
    }
}

/// `halton`: the halton number for index and base.
fn halton(index: i32, base: i32) -> f32 {
    let mut f = 1.0f32;
    let mut result = 0.0f32;

    let mut current_index = index;
    while current_index > 0 {
        f /= base as f32;
        result += f * (current_index % base) as f32;
        current_index = ((current_index as f32) / (base as f32)).floor() as u32 as i32;
    }

    result
}

/// `fsr3upscalerDebugCheckDispatch`.
fn fsr3_upscaler_debug_check_dispatch(
    context: &FfxFsr3UpscalerContextPrivate,
    params: &FfxFsr3UpscalerDispatchDescription,
) {
    if params.command_list == 0 {
        ffx_print_message(FfxMsgType::Error as u32, "commandList is null");
    }

    if params.color.resource == 0 {
        ffx_print_message(FfxMsgType::Error as u32, "color resource is null");
    }

    if params.depth.resource == 0 {
        ffx_print_message(FfxMsgType::Error as u32, "depth resource is null");
    }

    if params.motion_vectors.resource == 0 {
        ffx_print_message(FfxMsgType::Error as u32, "motionVectors resource is null");
    }

    if params.exposure.resource != 0
        && (context.context_description.flags & FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE)
            == FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE
    {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "exposure resource provided, however auto exposure flag is present",
        );
    }

    if params.output.resource == 0 {
        ffx_print_message(FfxMsgType::Error as u32, "output resource is null");
    }

    if params.jitter_offset.x.abs() > 1.0 || params.jitter_offset.y.abs() > 1.0 {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "jitterOffset contains value outside of expected range [-1.0, 1.0]",
        );
    }

    if (params.motion_vector_scale.x > context.context_description.max_render_size.width as f32)
        || (params.motion_vector_scale.y
            > context.context_description.max_render_size.height as f32)
    {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "motionVectorScale contains scale value greater than maxRenderSize",
        );
    }
    if (params.motion_vector_scale.x == 0.0) || (params.motion_vector_scale.y == 0.0) {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "motionVectorScale contains zero scale value",
        );
    }

    if (params.render_size.width > context.context_description.max_render_size.width)
        || (params.render_size.height > context.context_description.max_render_size.height)
    {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "renderSize is greater than context maxRenderSize",
        );
    }
    if (params.render_size.width == 0) || (params.render_size.height == 0) {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "renderSize contains zero dimension",
        );
    }

    if params.sharpness < 0.0 || params.sharpness > 1.0 {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "sharpness contains value outside of expected range [0.0, 1.0]",
        );
    }

    if params.frame_time_delta < 1.0 {
        ffx_print_message(
            FfxMsgType::Warning as u32,
            "frameTimeDelta is less than 1.0f - this value should be milliseconds (~16.6f for 60fps)",
        );
    }

    if params.pre_exposure == 0.0 {
        ffx_print_message(
            FfxMsgType::Error as u32,
            "preExposure provided as 0.0f which is invalid",
        );
    }

    let infinite_depth = (context.context_description.flags
        & FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE)
        == FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE;
    let inverse_depth = (context.context_description.flags
        & FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED)
        == FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED;

    if inverse_depth {
        if params.camera_near < params.camera_far {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED flag is present yet cameraNear is less than cameraFar",
            );
        }
        if infinite_depth && params.camera_near != f32::MAX {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE and FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED present, yet cameraNear != FLT_MAX",
            );
        }
        if params.camera_far < 0.075 {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED present, cameraFar value is very low which may result in depth separation artefacting",
            );
        }
    } else {
        if params.camera_near > params.camera_far {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "cameraNear is greater than cameraFar in non-inverted-depth context",
            );
        }
        if infinite_depth && params.camera_far != f32::MAX {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE present, yet cameraFar != FLT_MAX",
            );
        }
        if params.camera_near < 0.075 {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "cameraNear value is very low which may result in depth separation artefacting",
            );
        }
    }

    if params.camera_fov_angle_vertical <= 0.0 {
        ffx_print_message(
            FfxMsgType::Error as u32,
            "cameraFovAngleVertical is 0.0f - this value should be > 0.0f",
        );
    }
    if params.camera_fov_angle_vertical > FFX_PI {
        ffx_print_message(
            FfxMsgType::Error as u32,
            "cameraFovAngleVertical is greater than 180 degrees/PI",
        );
    }
}

/// The name lookup loop of `patchResourceBindings`.
fn map_index(table: &[ResourceBinding], name: &str) -> Result<u32, FfxErrorCode> {
    let mut map_index = 0;
    while map_index < table.len() {
        if table[map_index].name == name {
            break;
        }
        map_index += 1;
    }
    ffx_return_on_error!(map_index != table.len(), FFX_ERROR_INVALID_ARGUMENT);
    Ok(table[map_index].index)
}

/// `patchResourceBindings`.
fn patch_resource_bindings(inout_pipeline: &mut FfxPipelineState) -> Result<(), FfxErrorCode> {
    for binding in &mut inout_pipeline.srv_texture_bindings {
        binding.resource_identifier = map_index(SRV_TEXTURE_BINDING_TABLE, &binding.name)?;
    }

    for binding in &mut inout_pipeline.uav_texture_bindings {
        binding.resource_identifier = map_index(UAV_TEXTURE_BINDING_TABLE, &binding.name)?;
    }

    for binding in &mut inout_pipeline.constant_buffer_bindings {
        binding.resource_identifier = map_index(CONSTANT_BUFFER_BINDING_TABLE, &binding.name)?;
    }

    Ok(())
}

/// `getPipelinePermutationFlags`.
fn get_pipeline_permutation_flags(
    context_flags: u32,
    pass_id: FfxFsr3UpscalerPass,
    fp16: bool,
    force64: bool,
    use_lut: bool,
) -> u32 {
    // work out what permutation to load.
    let mut flags = 0;
    flags |= if context_flags & FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE != 0 {
        FSR3UPSCALER_SHADER_PERMUTATION_HDR_COLOR_INPUT
    } else {
        0
    };
    flags |= if context_flags & FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS != 0 {
        0
    } else {
        FSR3UPSCALER_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS
    };
    flags |= if context_flags & FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION != 0 {
        FSR3UPSCALER_SHADER_PERMUTATION_JITTER_MOTION_VECTORS
    } else {
        0
    };
    flags |= if context_flags & FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED != 0 {
        FSR3UPSCALER_SHADER_PERMUTATION_DEPTH_INVERTED
    } else {
        0
    };
    flags |= if pass_id == FfxFsr3UpscalerPass::AccumulateSharpen {
        FSR3UPSCALER_SHADER_PERMUTATION_ENABLE_SHARPENING
    } else {
        0
    };
    flags |= if use_lut {
        FSR3UPSCALER_SHADER_PERMUTATION_USE_LANCZOS_TYPE
    } else {
        0
    };
    flags |= if force64 {
        FSR3UPSCALER_SHADER_PERMUTATION_FORCE_WAVE64
    } else {
        0
    };
    flags |= if fp16 && (pass_id != FfxFsr3UpscalerPass::Rcas) {
        FSR3UPSCALER_SHADER_PERMUTATION_ALLOW_FP16
    } else {
        0
    };
    flags
}

/// `createPipelineStates`.
fn create_pipeline_states(context: &mut FfxFsr3UpscalerContextPrivate) -> Result<(), FfxErrorCode> {
    let sampler_descs = [
        FfxSamplerDescription {
            filter: FfxFilterType::MinMagMipPoint,
            address_mode_u: FfxAddressMode::Clamp,
            address_mode_v: FfxAddressMode::Clamp,
            address_mode_w: FfxAddressMode::Clamp,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
        FfxSamplerDescription {
            filter: FfxFilterType::MinMagMipLinear,
            address_mode_u: FfxAddressMode::Clamp,
            address_mode_v: FfxAddressMode::Clamp,
            address_mode_w: FfxAddressMode::Clamp,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];
    let root_constant_descs = [
        FfxRootConstantDescription {
            size: Fsr3UpscalerConstants::WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
        FfxRootConstantDescription {
            size: FSR3UPSCALER_SECONDARY_UNION_WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];
    let mut pipeline_description = FfxPipelineDescription {
        context_flags: context.context_description.flags,
        samplers: &sampler_descs,
        root_constants: &root_constant_descs,
        name: String::new(),
        stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        indirect_workload: 0,
        backbuffer_format: FfxSurfaceFormat::Unknown,
    };
    let backend = context.context_description.backend_interface.clone();
    // The SDK ignores this call's error code.
    let capabilities = backend
        .borrow_mut()
        .get_device_capabilities()
        .unwrap_or_default();
    let have_shader_model66 =
        capabilities.maximum_supported_shader_model >= FfxShaderModel::ShaderModel6_6;
    let supported_fp16 = capabilities.fp16_supported;
    let use_lut = capabilities.wave_lane_count_min == 32 && capabilities.wave_lane_count_max == 64;
    let can_force_wave64 = use_lut && have_shader_model66;
    let context_flags = context.context_description.flags;
    let create = |pass: FfxFsr3UpscalerPass, description: &FfxPipelineDescription<'_>, id: u32| {
        backend.borrow_mut().create_pipeline(
            FfxEffect::Fsr3Upscaler,
            pass as FfxPass,
            get_pipeline_permutation_flags(
                context_flags,
                pass,
                supported_fp16,
                can_force_wave64,
                use_lut,
            ),
            description,
            id,
        )
    };
    pipeline_description.name = "FSR3-LUMA-PYRAMID".into();
    context.pipeline_luma_pyramid = create(
        FfxFsr3UpscalerPass::LumaPyramid,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-RCAS".into();
    context.pipeline_rcas = create(
        FfxFsr3UpscalerPass::Rcas,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-GEN_REACTIVE".into();
    context.pipeline_generate_reactive = create(
        FfxFsr3UpscalerPass::GenerateReactive,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.root_constants = &root_constant_descs[..1];
    pipeline_description.name = "FSR3-PREPARE-INPUTS".into();
    context.pipeline_prepare_inputs = create(
        FfxFsr3UpscalerPass::PrepareInputs,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-PREPARE-REACTIVITY".into();
    context.pipeline_prepare_reactivity = create(
        FfxFsr3UpscalerPass::PrepareReactivity,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-SHADING-CHANGE".into();
    context.pipeline_shading_change = create(
        FfxFsr3UpscalerPass::ShadingChange,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-ACCUMULATE".into();
    context.pipeline_accumulate = create(
        FfxFsr3UpscalerPass::Accumulate,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-ACCUM_SHARP".into();
    context.pipeline_accumulate_sharpen = create(
        FfxFsr3UpscalerPass::AccumulateSharpen,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-SHADING-CHANGE-PYRAMID".into();
    context.pipeline_shading_change_pyramid = create(
        FfxFsr3UpscalerPass::ShadingChangePyramid,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-LUMA-INSTABILITY".into();
    context.pipeline_luma_instability = create(
        FfxFsr3UpscalerPass::LumaInstability,
        &pipeline_description,
        context.effect_context_id,
    )?;
    pipeline_description.name = "FSR3-DEBUG-VIEW".into();
    context.pipeline_debug_view = create(
        FfxFsr3UpscalerPass::DebugView,
        &pipeline_description,
        context.effect_context_id,
    )?;
    patch_resource_bindings(&mut context.pipeline_prepare_inputs)?;
    patch_resource_bindings(&mut context.pipeline_prepare_reactivity)?;
    patch_resource_bindings(&mut context.pipeline_shading_change)?;
    patch_resource_bindings(&mut context.pipeline_accumulate)?;
    patch_resource_bindings(&mut context.pipeline_luma_pyramid)?;
    patch_resource_bindings(&mut context.pipeline_accumulate_sharpen)?;
    patch_resource_bindings(&mut context.pipeline_rcas)?;
    patch_resource_bindings(&mut context.pipeline_generate_reactive)?;
    patch_resource_bindings(&mut context.pipeline_tcr_autogenerate)?;
    patch_resource_bindings(&mut context.pipeline_shading_change_pyramid)?;
    patch_resource_bindings(&mut context.pipeline_luma_instability)?;
    patch_resource_bindings(&mut context.pipeline_debug_view)?;
    Ok(())
}

/// `{FFX_RESOURCE_INIT_DATA_TYPE_UNINITIALIZED}`.
fn uninitialized() -> FfxResourceInitData<'static> {
    FfxResourceInitData {
        r#type: FfxResourceInitDataType::Uninitialized,
        ..Default::default()
    }
}

/// The memory of an `int16_t` array as bytes.
fn int16_bytes(values: &[i16]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|value| value.to_ne_bytes())
        .collect()
}

/// `fsr3upscalerCreate`.
#[expect(clippy::too_many_lines, reason = "one SDK function")]
fn fsr3_upscaler_create(
    context: &mut FfxFsr3UpscalerContextPrivate,
    context_description: &FfxFsr3UpscalerContextDescription,
) -> Result<(), FfxErrorCode> {
    *context = FfxFsr3UpscalerContextPrivate::zeroed(context_description.clone());
    let backend = context.context_description.backend_interface.clone();
    context.device = backend.borrow().device();
    let version = backend.borrow_mut().get_sdk_version();
    ffx_return_on_error!(
        version == ffx_sdk_make_version(1, 1, 4),
        FFX_ERROR_INVALID_VERSION
    );
    context.effect_context_id = backend
        .borrow_mut()
        .create_backend_context(FfxEffect::Fsr3Upscaler, None)?;
    context.device_capabilities = backend.borrow_mut().get_device_capabilities()?;
    context.first_execution = true;
    context.resource_frame_index = 0;
    context.constants.max_upscale_size = [
        context_description.max_upscale_size.width as i32,
        context_description.max_upscale_size.height as i32,
    ];
    context.constants.velocity_factor = 1.0;
    context.constants.reactiveness_scale = 1.0;
    context.constants.shading_change_scale = 1.0;
    context.constants.accumulation_added_per_frame = 1.0 / 3.0;
    context.constants.min_disocclusion_accumulation = -1.0 / 3.0;
    const LANCZOS2_LUT_WIDTH: u32 = 128;
    let mut lanczos2_weights = [0i16; LANCZOS2_LUT_WIDTH as usize];
    for current_lanczos_width_index in 0..LANCZOS2_LUT_WIDTH {
        let x = 2.0 * current_lanczos_width_index as f32 / (LANCZOS2_LUT_WIDTH - 1) as f32;
        lanczos2_weights[current_lanczos_width_index as usize] =
            (lanczos2(x) * 32767.0).round() as i16;
    }
    let lanczos2_weights = int16_bytes(&lanczos2_weights);
    let default_exposure = [0u8; 8];
    let max_render_size = context_description.max_render_size;
    let max_upscale_size = context_description.max_upscale_size;
    let max_render_size_div2 = FfxDimensions2D {
        width: max_render_size.width / 2,
        height: max_render_size.height / 2,
    };
    /// An `FfxInternalResourceDescription` of `FFX_RESOURCE_TYPE_TEXTURE2D`.
    #[expect(clippy::too_many_arguments, reason = "the SDK's aggregate initializer")]
    fn surface<'a>(
        id: u32,
        name: &'static str,
        usage: FfxResourceUsage,
        format: FfxSurfaceFormat,
        width: u32,
        height: u32,
        mip_count: u32,
        flags: FfxResourceFlags,
        init_data: FfxResourceInitData<'a>,
    ) -> FfxInternalResourceDescription<'a> {
        FfxInternalResourceDescription {
            id,
            name,
            r#type: FfxResourceType::Texture2D,
            usage,
            format,
            width,
            height,
            mip_count,
            flags,
            init_data,
        }
    }

    let internal_surface_desc = [
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_1,
            "FSR3UPSCALER_Accumulation1",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8Unorm,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_2,
            "FSR3UPSCALER_Accumulation2",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8Unorm,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_1,
            "FSR3UPSCALER_Luma1",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_2,
            "FSR3UPSCALER_Luma2",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERMEDIATE_FP16x1,
            "FSR3UPSCALER_IntermediateFp16x1",
            FFX_RESOURCE_USAGE_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SHADING_CHANGE,
            "FSR3UPSCALER_ShadingChange",
            FFX_RESOURCE_USAGE_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R8Unorm,
            max_render_size_div2.width,
            max_render_size_div2.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_NEW_LOCKS,
            "FSR3UPSCALER_NewLocks",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8Unorm,
            max_upscale_size.width,
            max_upscale_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_1,
            "FSR3UPSCALER_InternalUpscaled1",
            FFX_RESOURCE_USAGE_RENDERTARGET
                | FFX_RESOURCE_USAGE_UAV
                | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16B16A16Float,
            max_upscale_size.width,
            max_upscale_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_2,
            "FSR3UPSCALER_InternalUpscaled2",
            FFX_RESOURCE_USAGE_RENDERTARGET
                | FFX_RESOURCE_USAGE_UAV
                | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16B16A16Float,
            max_upscale_size.width,
            max_upscale_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS,
            "FSR3UPSCALER_SpdMips",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16G16Float,
            max_render_size_div2.width,
            max_render_size_div2.height,
            0,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH_MIP1,
            "FSR3UPSCALER_FarthestDepthMip1",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16Float,
            max_render_size_div2.width,
            max_render_size_div2.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY_1,
            "FSR3UPSCALER_LumaHistory1",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16G16B16A16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY_2,
            "FSR3UPSCALER_LumaHistory2",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16G16B16A16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT,
            "FSR3UPSCALER_SpdAtomicCounter",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R32Uint,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_value(size_of::<u32>(), 0),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
            "FSR3UPSCALER_DilatedReactiveMasks",
            FFX_RESOURCE_USAGE_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R8G8B8A8Unorm,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LANCZOS_LUT,
            "FSR3UPSCALER_LanczosLutData",
            FFX_RESOURCE_USAGE_READ_ONLY,
            FfxSurfaceFormat::R16Snorm,
            LANCZOS2_LUT_WIDTH,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_buffer(
                lanczos2_weights.len(),
                &lanczos2_weights,
            ),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY,
            "FSR3UPSCALER_DefaultReactivityMask",
            FFX_RESOURCE_USAGE_READ_ONLY,
            FfxSurfaceFormat::R8Unorm,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_value(size_of::<u8>(), 0),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_EXPOSURE,
            "FSR3UPSCALER_DefaultExposure",
            FFX_RESOURCE_USAGE_READ_ONLY,
            FfxSurfaceFormat::R32G32Float,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_buffer(
                default_exposure.len(),
                &default_exposure,
            ),
        ),
        surface(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FRAME_INFO,
            "FSR3UPSCALER_FrameInfo",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R32G32B32A32Float,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
    ];
    // clear the SRV resources to NULL.
    context.srv_resources =
        [FfxResourceInternal::default(); FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_COUNT as usize];

    for current_surface_description in &internal_surface_desc {
        let resource_type = current_surface_description.r#type;
        let resource_description = FfxResourceDescription {
            r#type: resource_type,
            format: current_surface_description.format,
            width: current_surface_description.width,
            height: current_surface_description.height,
            depth: 1,
            mip_count: current_surface_description.mip_count,
            flags: current_surface_description.flags,
            usage: current_surface_description.usage,
        };
        let initial_state = if current_surface_description.usage == FFX_RESOURCE_USAGE_READ_ONLY {
            FFX_RESOURCE_STATE_COMPUTE_READ
        } else {
            FFX_RESOURCE_STATE_UNORDERED_ACCESS
        };
        let create_resource_description = FfxCreateResourceDescription {
            heap_type: FfxHeapType::Default,
            resource_description,
            initial_state,
            name: current_surface_description.name,
            id: current_surface_description.id,
            init_data: current_surface_description.init_data,
        };

        context.srv_resources[current_surface_description.id as usize] = ffx_validate!(
            backend
                .borrow_mut()
                .create_resource(&create_resource_description, context.effect_context_id)
        );
    }

    // copy resources to uavResrouces list
    context.uav_resources = context.srv_resources;

    // avoid compiling pipelines on first render
    {
        create_pipeline_states(context)?;
    }
    Ok(())
}

/// `fsr3upscalerRelease`.
fn fsr3_upscaler_release(context: &mut FfxFsr3UpscalerContextPrivate) -> Result<(), FfxErrorCode> {
    let backend = context.context_description.backend_interface.clone();
    let effect_context_id = context.effect_context_id;
    for pipeline in [
        &mut context.pipeline_prepare_inputs,
        &mut context.pipeline_prepare_reactivity,
        &mut context.pipeline_shading_change,
        &mut context.pipeline_accumulate,
        &mut context.pipeline_accumulate_sharpen,
        &mut context.pipeline_rcas,
        &mut context.pipeline_luma_pyramid,
        &mut context.pipeline_generate_reactive,
        &mut context.pipeline_tcr_autogenerate,
        &mut context.pipeline_shading_change_pyramid,
        &mut context.pipeline_luma_instability,
        &mut context.pipeline_debug_view,
    ] {
        ffx_safe_release_pipeline(&mut *backend.borrow_mut(), pipeline, effect_context_id);
    }
    for id in [
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_COLOR,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_DEPTH,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_EXPOSURE,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RCAS_INPUT,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_UPSCALED_OUTPUT,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_CURRENT_LUMA,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_PREVIOUS_LUMA,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_INSTABILITY,
    ] {
        context.srv_resources[id as usize] = FfxResourceInternal::default();
    }
    for id in [
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LANCZOS_LUT,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_EXPOSURE,
    ] {
        ffx_safe_release_copy_resource(
            &mut *backend.borrow_mut(),
            context.srv_resources[id as usize],
            effect_context_id,
        );
    }
    for resource in context.srv_resources {
        ffx_safe_release_resource(&mut *backend.borrow_mut(), resource, effect_context_id);
    }
    let _ = backend
        .borrow_mut()
        .destroy_backend_context(effect_context_id);
    Ok(())
}

/// `setupDeviceDepthToViewSpaceDepthParams`.
fn setup_device_depth_to_view_space_depth_params(
    context: &mut FfxFsr3UpscalerContextPrivate,
    params: &FfxFsr3UpscalerDispatchDescription,
) {
    let b_inverted = (context.context_description.flags & FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED)
        == FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED;
    let b_infinite = (context.context_description.flags & FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE)
        == FFX_FSR3UPSCALER_ENABLE_DEPTH_INFINITE;

    // make sure it has no impact if near and far plane values are swapped in dispatch params
    // the flags "inverted" and "infinite" will decide what transform to use
    let mut f_min = if params.camera_near < params.camera_far {
        params.camera_near
    } else {
        params.camera_far
    };
    let mut f_max = if params.camera_near > params.camera_far {
        params.camera_near
    } else {
        params.camera_far
    };

    if b_inverted {
        std::mem::swap(&mut f_min, &mut f_max);
    }

    // a 0 0 0   x
    // 0 b 0 0   y
    // 0 0 c d   z
    // 0 0 e 0   1

    let f_q = f_max / (f_min - f_max);
    let d = -1.0f32; // for clarity

    let matrix_elem_c: [[f32; 2]; 2] = [
        [
            f_q,                 // non reversed, non infinite
            -1.0 - f32::EPSILON, // non reversed, infinite
        ],
        [
            f_q,                // reversed, non infinite
            0.0 + f32::EPSILON, // reversed, infinite
        ],
    ];

    let matrix_elem_e: [[f32; 2]; 2] = [
        [
            f_q * f_min,           // non reversed, non infinite
            -f_min - f32::EPSILON, // non reversed, infinite
        ],
        [
            f_q * f_min, // reversed, non infinite
            f_max,       // reversed, infinite
        ],
    ];

    context.constants.device_to_view_depth[0] =
        d * matrix_elem_c[usize::from(b_inverted)][usize::from(b_infinite)];
    context.constants.device_to_view_depth[1] =
        matrix_elem_e[usize::from(b_inverted)][usize::from(b_infinite)];

    // revert x and y coords
    let aspect = params.render_size.width as f32 / params.render_size.height as f32;
    let cot_half_fov_y = (0.5 * params.camera_fov_angle_vertical).cos()
        / (0.5 * params.camera_fov_angle_vertical).sin();
    let a = cot_half_fov_y / aspect;
    let b = cot_half_fov_y;

    context.constants.device_to_view_depth[2] = 1.0 / a;
    context.constants.device_to_view_depth[3] = 1.0 / b;
}

/// `scheduleDispatch`.
fn schedule_dispatch(
    context: &FfxFsr3UpscalerContextPrivate,
    _params: &FfxFsr3UpscalerDispatchDescription,
    pipeline: &FfxPipelineState,
    dispatch_x: u32,
    dispatch_y: u32,
) {
    let mut compute_job_descriptor = FfxComputeJobDescription {
        srv_textures: vec![FfxTextureSRV::default(); pipeline.srv_texture_bindings.len()],
        uav_textures: vec![FfxTextureUAV::default(); pipeline.uav_texture_bindings.len()],
        cbs: vec![FfxConstantBuffer::default(); pipeline.constant_buffer_bindings.len()],
        ..Default::default()
    };

    for (current_shader_resource_view_index, binding) in
        pipeline.srv_texture_bindings.iter().enumerate()
    {
        let current_resource_id = binding.resource_identifier;
        let current_resource = context.srv_resources[current_resource_id as usize];
        compute_job_descriptor.srv_textures[current_shader_resource_view_index].resource =
            current_resource;
    }

    for (current_unordered_access_view_index, binding) in
        pipeline.uav_texture_bindings.iter().enumerate()
    {
        let current_resource_id = binding.resource_identifier;
        let uav = &mut compute_job_descriptor.uav_textures[current_unordered_access_view_index];
        if (FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_0
            ..=FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_5)
            .contains(&current_resource_id)
        {
            let current_resource =
                context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS as usize];
            uav.resource = current_resource;
            uav.mip = current_resource_id - FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS_LEVEL_0;
        } else {
            let current_resource = context.uav_resources[current_resource_id as usize];
            uav.resource = current_resource;
            uav.mip = 0;
        }
    }

    compute_job_descriptor.dimensions = [dispatch_x, dispatch_y, 1];
    compute_job_descriptor.pipeline = pipeline.clone();

    for (current_root_constant_index, binding) in
        pipeline.constant_buffer_bindings.iter().enumerate()
    {
        compute_job_descriptor.cbs[current_root_constant_index] =
            context.constant_buffers[binding.resource_identifier as usize].clone();
    }

    let dispatch_job = FfxGpuJobDescription {
        job_label: pipeline.name.clone(),
        descriptor: FfxGpuJobDescriptor::Compute(Box::new(compute_job_descriptor)),
    };
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&dispatch_job);
}

/// `fpRegisterResource` with its out-parameter left unchanged on failure.
fn register_resource(
    backend: &FfxInterfaceRef,
    in_resource: &FfxResource,
    effect_context_id: u32,
    out_resource: &mut FfxResourceInternal,
) {
    if let Ok(resource) = backend
        .borrow_mut()
        .register_resource(in_resource, effect_context_id)
    {
        *out_resource = resource;
    }
}

fn schedule_clear(
    backend: &FfxInterfaceRef,
    label: &str,
    target: FfxResourceInternal,
    color: [f32; 4],
) {
    let _ = backend
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: label.into(),
            descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                color,
                target,
            }),
        });
}

/// `ffxFsr3UpscalerGetSharedResourceDescriptions`.
pub fn ffx_fsr3_upscaler_get_shared_resource_descriptions(
    context: &FfxFsr3UpscalerContext,
) -> Result<FfxFsr3UpscalerSharedResourceDescriptions, FfxErrorCode> {
    let context = context
        .private
        .as_deref()
        .ok_or(FFX_ERROR_INVALID_POINTER)?;
    let size = context.context_description.max_render_size;
    let description = |id, name, format, usage| FfxCreateResourceDescription {
        heap_type: FfxHeapType::Default,
        resource_description: FfxResourceDescription {
            r#type: FfxResourceType::Texture2D,
            format,
            width: size.width,
            height: size.height,
            depth: 1,
            mip_count: 1,
            flags: FFX_RESOURCE_FLAGS_NONE,
            usage,
        },
        initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
        name,
        id,
        init_data: uninitialized(),
    };
    let usage = FFX_RESOURCE_USAGE_RENDERTARGET
        | FFX_RESOURCE_USAGE_UAV
        | FFX_RESOURCE_USAGE_DCC_RENDERTARGET;
    Ok(FfxFsr3UpscalerSharedResourceDescriptions {
        dilated_depth: description(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_DEPTH,
            "FSR3UPSCALER_DilatedDepth",
            FfxSurfaceFormat::R32Float,
            usage,
        ),
        dilated_motion_vectors: description(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
            "FSR3UPSCALER_DilatedVelocity",
            FfxSurfaceFormat::R16G16Float,
            usage,
        ),
        reconstructed_prev_nearest_depth: description(
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
            "FSR3UPSCALER_ReconstructedPrevNearestDepth",
            FfxSurfaceFormat::R32Uint,
            FFX_RESOURCE_USAGE_UAV,
        ),
    })
}

/// `fsr3upscalerDispatch`.
#[expect(clippy::too_many_lines, reason = "one SDK function")]
fn fsr3_upscaler_dispatch(
    context: &mut FfxFsr3UpscalerContextPrivate,
    params: &FfxFsr3UpscalerDispatchDescription,
) -> Result<(), FfxErrorCode> {
    if context.context_description.flags & FFX_FSR3UPSCALER_ENABLE_DEBUG_CHECKING != 0 {
        fsr3_upscaler_debug_check_dispatch(context, params);
    }
    let backend = context.context_description.backend_interface.clone();
    let effect_context_id = context.effect_context_id;
    let command_list = params.command_list;
    if context.first_execution {
        for (id, label) in [
            (
                FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_1,
                "Clear Accumulation 1",
            ),
            (
                FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_2,
                "Clear Accumulation 2",
            ),
            (
                FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_1,
                "Clear Temporal Luma 1",
            ),
            (
                FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_2,
                "Clear Temporal Luma 2",
            ),
        ] {
            schedule_clear(
                &backend,
                label,
                context.srv_resources[id as usize],
                [0.0; 4],
            );
        }
    }
    let is_odd_frame = context.resource_frame_index & 1 != 0;
    let accumulation_srv_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_2
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_1
    } as usize;
    let accumulation_uav_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_1
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION_2
    } as usize;
    let upscaled_color_srv_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_2
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_1
    } as usize;
    let upscaled_color_uav_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_1
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_2
    } as usize;
    let luma_history_srv_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY_2
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY_1
    } as usize;
    let luma_history_uav_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY_1
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY_2
    } as usize;
    let current_luma_srv_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_2
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_1
    } as usize;
    let previous_luma_srv_resource_index = if is_odd_frame {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_1
    } else {
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_2
    } as usize;
    let reset_accumulation = params.reset || context.first_execution;
    context.first_execution = false;

    for (id, resource) in [
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_COLOR,
            &params.color,
        ),
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_DEPTH,
            &params.depth,
        ),
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS,
            &params.motion_vectors,
        ),
    ] {
        register_resource(
            &backend,
            resource,
            effect_context_id,
            &mut context.srv_resources[id as usize],
        );
    }
    for (id, resource) in [
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
            &params.dilated_motion_vectors,
        ),
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_DEPTH,
            &params.dilated_depth,
        ),
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
            &params.reconstructed_prev_nearest_depth,
        ),
    ] {
        register_resource(
            &backend,
            resource,
            effect_context_id,
            &mut context.srv_resources[id as usize],
        );
        context.uav_resources[id as usize] = context.srv_resources[id as usize];
    }
    if context.context_description.flags & FFX_FSR3UPSCALER_ENABLE_AUTO_EXPOSURE != 0 {
        context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize] =
            context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FRAME_INFO as usize];
    } else if ffx_fsr3_upscaler_resource_is_null(&params.exposure) {
        context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize] =
            context.srv_resources
                [FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_EXPOSURE as usize];
    } else {
        register_resource(
            &backend,
            &params.exposure,
            effect_context_id,
            &mut context.srv_resources
                [FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize],
        );
    }
    for (id, resource) in [
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK,
            &params.reactive,
        ),
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK,
            &params.transparency_and_composition,
        ),
    ] {
        if ffx_fsr3_upscaler_resource_is_null(resource) {
            context.srv_resources[id as usize] = context.srv_resources
                [FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY as usize];
        } else {
            register_resource(
                &backend,
                resource,
                effect_context_id,
                &mut context.srv_resources[id as usize],
            );
        }
    }
    register_resource(
        &backend,
        &params.output,
        effect_context_id,
        &mut context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_UPSCALED_OUTPUT as usize],
    );
    context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION as usize] =
        context.srv_resources[accumulation_srv_resource_index];
    context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR as usize] =
        context.srv_resources[upscaled_color_srv_resource_index];
    context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_ACCUMULATION as usize] =
        context.uav_resources[accumulation_uav_resource_index];
    context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR as usize] =
        context.uav_resources[upscaled_color_uav_resource_index];
    context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RCAS_INPUT as usize] =
        context.uav_resources[upscaled_color_uav_resource_index];
    context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_CURRENT_LUMA as usize] =
        context.srv_resources[current_luma_srv_resource_index];
    context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_CURRENT_LUMA as usize] =
        context.uav_resources[current_luma_srv_resource_index];
    context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_PREVIOUS_LUMA as usize] =
        context.srv_resources[previous_luma_srv_resource_index];
    context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY as usize] =
        context.uav_resources[luma_history_uav_resource_index];
    context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_HISTORY as usize] =
        context.srv_resources[luma_history_srv_resource_index];
    for id in [
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_LUMA_INSTABILITY,
    ] {
        context.srv_resources[id as usize] = context.srv_resources
            [FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERMEDIATE_FP16x1 as usize];
        context.uav_resources[id as usize] = context.uav_resources
            [FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERMEDIATE_FP16x1 as usize];
    }
    let resource_desc_input_color = backend.borrow_mut().get_resource_description(
        context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_COLOR as usize],
    );
    let _resource_desc_reactive_mask = backend.borrow_mut().get_resource_description(
        context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK as usize],
    );
    crate::assert::ffx_assert!(resource_desc_input_color.r#type == FfxResourceType::Texture2D);
    context.constants.previous_frame_jitter_offset = context.constants.jitter_offset;
    context.constants.jitter_offset = [params.jitter_offset.x, params.jitter_offset.y];
    context.constants.previous_frame_render_size = context.constants.render_size;
    context.constants.render_size = [
        if params.render_size.width != 0 {
            params.render_size.width
        } else {
            resource_desc_input_color.width
        } as i32,
        if params.render_size.height != 0 {
            params.render_size.height
        } else {
            resource_desc_input_color.height
        } as i32,
    ];
    context.constants.max_render_size = [
        context.context_description.max_render_size.width as i32,
        context.context_description.max_render_size.height as i32,
    ];
    let aspect_ratio = params.render_size.width as f32 / params.render_size.height as f32;
    let camera_angle_horizontal =
        ((params.camera_fov_angle_vertical / 2.0).tan() * aspect_ratio).atan() * 2.0;
    context.constants.tan_half_fov = (camera_angle_horizontal * 0.5).tan();
    context.constants.view_space_to_meters_factor = if params.view_space_to_meters_factor > 0.0 {
        params.view_space_to_meters_factor
    } else {
        1.0
    };
    setup_device_depth_to_view_space_depth_params(context, params);
    context.constants.previous_frame_upscale_size = context.constants.upscale_size;
    context.constants.upscale_size =
        if params.upscale_size.height == 0 && params.upscale_size.width == 0 {
            [
                context.context_description.max_upscale_size.width as i32,
                context.context_description.max_upscale_size.height as i32,
            ]
        } else {
            [
                params.upscale_size.width as i32,
                params.upscale_size.height as i32,
            ]
        };
    context.constants.downscale_factor = [
        context.constants.render_size[0] as f32 / context.constants.upscale_size[0] as f32,
        context.constants.render_size[1] as f32 / context.constants.upscale_size[1] as f32,
    ];
    context.constants.delta_pre_exposure = 1.0;
    context.previous_frame_pre_exposure = context.pre_exposure;
    context.pre_exposure = if params.pre_exposure != 0.0 {
        params.pre_exposure
    } else {
        1.0
    };
    if context.previous_frame_pre_exposure > 0.0 {
        context.constants.delta_pre_exposure =
            context.pre_exposure / context.previous_frame_pre_exposure;
    }
    let motion_vectors_target_size = if context.context_description.flags
        & FFX_FSR3UPSCALER_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
        != 0
    {
        context.constants.upscale_size
    } else {
        context.constants.render_size
    };
    context.constants.motion_vector_scale = [
        params.motion_vector_scale.x / motion_vectors_target_size[0] as f32,
        params.motion_vector_scale.y / motion_vectors_target_size[1] as f32,
    ];
    if context.context_description.flags
        & FFX_FSR3UPSCALER_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
        != 0
    {
        context.constants.motion_vector_jitter_cancellation = [
            (context.previous_jitter_offset[0] - context.constants.jitter_offset[0])
                / motion_vectors_target_size[0] as f32,
            (context.previous_jitter_offset[1] - context.constants.jitter_offset[1])
                / motion_vectors_target_size[1] as f32,
        ];
        context.previous_jitter_offset = context.constants.jitter_offset;
    }
    let jitter_phase_count = ffx_fsr3_upscaler_get_jitter_phase_count(
        params.render_size.width as i32,
        context.constants.upscale_size[0],
    );
    if reset_accumulation || context.constants.jitter_phase_count == 0.0 {
        context.constants.jitter_phase_count = jitter_phase_count as f32;
    } else {
        let delta = (jitter_phase_count as f32 - context.constants.jitter_phase_count) as i32;
        if delta > 0 {
            context.constants.jitter_phase_count += 1.0;
        } else if delta < 0 {
            context.constants.jitter_phase_count -= 1.0;
        }
    }
    // FFX_MINIMUM/FFX_MAXIMUM preserve the SDK's operand ordering for NaN.
    let delta_time = params.frame_time_delta / 1000.0;
    let delta_time = if 1.0 < delta_time { 1.0 } else { delta_time };
    context.constants.delta_time = if 0.0 > delta_time { 0.0 } else { delta_time };
    if reset_accumulation {
        context.constants.frame_index = 0.0;
    } else {
        context.constants.frame_index += 1.0;
    }
    let dispatch_src_x = context.constants.render_size[0].wrapping_add(7) / 8;
    let dispatch_src_y = context.constants.render_size[1].wrapping_add(7) / 8;
    let dispatch_dst_x = context.constants.upscale_size[0].wrapping_add(7) / 8;
    let dispatch_dst_y = context.constants.upscale_size[1].wrapping_add(7) / 8;
    let dispatch_shading_change_x =
        ((context.constants.render_size[0] as f32 * 0.5) as i32).wrapping_add(7) / 8;
    let dispatch_shading_change_y =
        ((context.constants.render_size[1] as f32 * 0.5) as i32).wrapping_add(7) / 8;
    if reset_accumulation {
        schedule_clear(
            &backend,
            "Clear Resource",
            context.srv_resources[accumulation_srv_resource_index],
            [0.0; 4],
        );
        schedule_clear(
            &backend,
            "Clear Scene Luminance",
            context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS as usize],
            [0.0; 4],
        );
        schedule_clear(
            &backend,
            "Clear Frame Info",
            context.srv_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FRAME_INFO as usize],
            [-1.0, 1.0, 0.0, 0.0],
        );
    }
    let clear_depth =
        if context.context_description.flags & FFX_FSR3UPSCALER_ENABLE_DEPTH_INVERTED != 0 {
            0.0
        } else {
            1.0
        };
    schedule_clear(
        &backend,
        "Clear Reconstructed Previous Nearest Depth",
        context.srv_resources
            [FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH as usize],
        [clear_depth; 4],
    );
    schedule_clear(
        &backend,
        "Clear Spd Atomic Count",
        context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT as usize],
        [0.0; 4],
    );
    let mut dispatch_thread_group_count_xy = [0; 2];
    let mut work_group_offset = [0; 2];
    let mut num_work_groups_and_mips = [0; 2];
    ffx_spd_setup(
        &mut dispatch_thread_group_count_xy,
        &mut work_group_offset,
        &mut num_work_groups_and_mips,
        [0, 0, params.render_size.width, params.render_size.height],
    );
    let luminance_pyramid_constants = Fsr3UpscalerSpdConstants {
        numwork_groups: num_work_groups_and_mips[0],
        mips: num_work_groups_and_mips[1],
        work_group_offset,
        render_size: [params.render_size.width, params.render_size.height],
    };
    let mut rcas_constants = Fsr3UpscalerRcasConstants::default();
    fsr_rcas_con(
        &mut rcas_constants.rcas_config,
        -2.0 * params.sharpness + 2.0,
    );
    for (id, words) in [
        (
            FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_FSR3UPSCALER,
            context.constants.words(),
        ),
        (
            FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_SPD,
            luminance_pyramid_constants.words(),
        ),
        (
            FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_RCAS,
            rcas_constants.words(),
        ),
    ] {
        let _ = backend
            .borrow_mut()
            .stage_constant_buffer_data_func(&words, &mut context.constant_buffers[id as usize]);
    }
    for id in [
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INTERMEDIATE_FP16x1,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SHADING_CHANGE,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_NEW_LOCKS,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_FARTHEST_DEPTH_MIP1,
        FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
    ] {
        let _ = backend
            .borrow_mut()
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: String::new(),
                descriptor: FfxGpuJobDescriptor::Discard(FfxDiscardJobDescription {
                    target: context.uav_resources[id as usize],
                }),
            });
    }
    // Upstream labels this SPD-mips clear as an atomic-count clear.
    schedule_clear(
        &backend,
        "Clear Spd Atomic Count",
        context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_SPD_MIPS as usize],
        [0.0; 4],
    );
    for (pipeline, x, y) in [
        (
            &context.pipeline_prepare_inputs,
            dispatch_src_x as u32,
            dispatch_src_y as u32,
        ),
        (
            &context.pipeline_luma_pyramid,
            dispatch_thread_group_count_xy[0],
            dispatch_thread_group_count_xy[1],
        ),
        (
            &context.pipeline_shading_change_pyramid,
            dispatch_thread_group_count_xy[0],
            dispatch_thread_group_count_xy[1],
        ),
        (
            &context.pipeline_shading_change,
            dispatch_shading_change_x as u32,
            dispatch_shading_change_y as u32,
        ),
        (
            &context.pipeline_prepare_reactivity,
            dispatch_src_x as u32,
            dispatch_src_y as u32,
        ),
        (
            &context.pipeline_luma_instability,
            dispatch_src_x as u32,
            dispatch_src_y as u32,
        ),
        (
            if params.enable_sharpening {
                &context.pipeline_accumulate_sharpen
            } else {
                &context.pipeline_accumulate
            },
            dispatch_dst_x as u32,
            dispatch_dst_y as u32,
        ),
    ] {
        schedule_dispatch(context, params, pipeline, x, y);
    }
    if params.enable_sharpening {
        schedule_dispatch(
            context,
            params,
            &context.pipeline_rcas,
            (context.constants.upscale_size[0].wrapping_add(15) / 16) as u32,
            (context.constants.upscale_size[1].wrapping_add(15) / 16) as u32,
        );
    }
    if params.flags & FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW != 0 {
        schedule_dispatch(
            context,
            params,
            &context.pipeline_debug_view,
            dispatch_dst_x as u32,
            dispatch_dst_y as u32,
        );
    }
    context.resource_frame_index =
        (context.resource_frame_index + 1) % FSR3UPSCALER_MAX_QUEUED_FRAMES;
    let _ = backend
        .borrow_mut()
        .execute_gpu_jobs(command_list, effect_context_id);
    let _ = backend
        .borrow_mut()
        .unregister_resources(command_list, effect_context_id);
    Ok(())
}

/// `ffxFsr3UpscalerContextCreate`. The SDK's `NULL` pointer and `NULL` callback
/// checks hold statically for Rust references and trait implementations, and
/// the backend owns its memory (no `scratchBuffer`).
pub fn ffx_fsr3_upscaler_context_create(
    context: &mut FfxFsr3UpscalerContext,
    context_description: &FfxFsr3UpscalerContextDescription,
) -> Result<(), FfxErrorCode> {
    // zero context memory
    *context = FfxFsr3UpscalerContext::default();

    // create the context.
    let context_private = context
        .private
        .insert(Box::new(FfxFsr3UpscalerContextPrivate::zeroed(
            context_description.clone(),
        )));
    fsr3_upscaler_create(context_private, context_description)
}

/// `ffxFsr3UpscalerContextGetGpuMemoryUsage`. A context that was never created is the
/// SDK's `NULL` context.
pub fn ffx_fsr3_upscaler_context_get_gpu_memory_usage(
    context: &mut FfxFsr3UpscalerContext,
) -> Result<FfxEffectMemoryUsage, FfxErrorCode> {
    let Some(context_private) = context.private.as_deref_mut() else {
        return Err(FFX_ERROR_INVALID_POINTER);
    };

    ffx_return_on_error!(context_private.device != 0, FFX_ERROR_NULL_DEVICE);

    let vram_usage = context_private
        .context_description
        .backend_interface
        .borrow_mut()
        .get_effect_gpu_memory_usage(context_private.effect_context_id)?;

    Ok(vram_usage)
}

/// `ffxFsr3UpscalerContextDestroy`. A context that was never created is the SDK's
/// `NULL` context.
pub fn ffx_fsr3_upscaler_context_destroy(
    context: &mut FfxFsr3UpscalerContext,
) -> Result<(), FfxErrorCode> {
    let Some(context_private) = context.private.as_deref_mut() else {
        return Err(FFX_ERROR_INVALID_POINTER);
    };

    // destroy the context.
    fsr3_upscaler_release(context_private)
}

/// `ffxFsr3UpscalerContextDispatch`. A context that was never created is the SDK's
/// `NULL` context.
pub fn ffx_fsr3_upscaler_context_dispatch(
    context: &mut FfxFsr3UpscalerContext,
    dispatch_params: &FfxFsr3UpscalerDispatchDescription,
) -> Result<(), FfxErrorCode> {
    let Some(context_private) = context.private.as_deref_mut() else {
        return Err(FFX_ERROR_INVALID_POINTER);
    };

    // validate that renderSize is within the maximum.
    ffx_return_on_error!(
        dispatch_params.render_size.width
            <= context_private.context_description.max_render_size.width,
        FFX_ERROR_OUT_OF_RANGE
    );
    ffx_return_on_error!(
        dispatch_params.render_size.height
            <= context_private.context_description.max_render_size.height,
        FFX_ERROR_OUT_OF_RANGE
    );
    ffx_return_on_error!(
        dispatch_params.upscale_size.width
            <= context_private.context_description.max_upscale_size.width,
        FFX_ERROR_OUT_OF_RANGE
    );
    ffx_return_on_error!(
        dispatch_params.upscale_size.height
            <= context_private.context_description.max_upscale_size.height,
        FFX_ERROR_OUT_OF_RANGE
    );
    ffx_return_on_error!(context_private.device != 0, FFX_ERROR_NULL_DEVICE);

    // dispatch the FSR3 Upscaler passes.
    fsr3_upscaler_dispatch(context_private, dispatch_params)
}

/// `ffxFsr3UpscalerGetUpscaleRatioFromQualityMode`.
pub fn ffx_fsr3_upscaler_get_upscale_ratio_from_quality_mode(
    quality_mode: FfxFsr3UpscalerQualityMode,
) -> f32 {
    match quality_mode {
        FfxFsr3UpscalerQualityMode::NativeAa => 1.0,
        FfxFsr3UpscalerQualityMode::Quality => 1.5,
        FfxFsr3UpscalerQualityMode::Balanced => 1.7,
        FfxFsr3UpscalerQualityMode::Performance => 2.0,
        FfxFsr3UpscalerQualityMode::UltraPerformance => 3.0,
    }
}

/// `ffxFsr3UpscalerGetRenderResolutionFromQualityMode`; returns the render width and
/// height. The quality mode range check holds for every `FfxFsr3UpscalerQualityMode`.
pub fn ffx_fsr3_upscaler_get_render_resolution_from_quality_mode(
    display_width: u32,
    display_height: u32,
    quality_mode: FfxFsr3UpscalerQualityMode,
) -> Result<(u32, u32), FfxErrorCode> {
    // scale by the predefined ratios in each dimension.
    let ratio = ffx_fsr3_upscaler_get_upscale_ratio_from_quality_mode(quality_mode);
    let scaled_display_width = (display_width as f32 / ratio) as u32;
    let scaled_display_height = (display_height as f32 / ratio) as u32;

    Ok((scaled_display_width, scaled_display_height))
}

/// `ffxFsr3UpscalerGetJitterPhaseCount`.
pub fn ffx_fsr3_upscaler_get_jitter_phase_count(render_width: i32, display_width: i32) -> i32 {
    let base_phase_count = 8.0f32;
    (base_phase_count * (display_width as f32 / render_width as f32).powf(2.0)) as i32
}

/// `ffxFsr3UpscalerGetJitterOffset`; returns the x and y offsets.
pub fn ffx_fsr3_upscaler_get_jitter_offset(
    index: i32,
    phase_count: i32,
) -> Result<(f32, f32), FfxErrorCode> {
    ffx_return_on_error!(phase_count > 0, FFX_ERROR_INVALID_ARGUMENT);

    let x = halton((index % phase_count) + 1, 2) - 0.5;
    let y = halton((index % phase_count) + 1, 3) - 0.5;

    Ok((x, y))
}

/// `ffxFsr3UpscalerResourceIsNull`.
pub fn ffx_fsr3_upscaler_resource_is_null(resource: &FfxResource) -> bool {
    resource.resource == 0
}

/// `ffxFsr3UpscalerContextGenerateReactiveMask`.
pub fn ffx_fsr3_upscaler_context_generate_reactive_mask(
    context: &mut FfxFsr3UpscalerContext,
    params: &FfxFsr3UpscalerGenerateReactiveDescription,
) -> Result<(), FfxErrorCode> {
    let context = context
        .private
        .as_deref_mut()
        .ok_or(FFX_ERROR_INVALID_POINTER)?;
    ffx_return_on_error!(params.command_list != 0, FFX_ERROR_INVALID_POINTER);
    ffx_return_on_error!(context.device != 0, FFX_ERROR_NULL_DEVICE);
    let backend = context.context_description.backend_interface.clone();
    let effect_context_id = context.effect_context_id;
    let pipeline = &context.pipeline_generate_reactive;
    for (id, resource) in [
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY,
            &params.color_opaque_only,
        ),
        (
            FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_INPUT_COLOR,
            &params.color_pre_upscale,
        ),
    ] {
        register_resource(
            &backend,
            resource,
            effect_context_id,
            &mut context.srv_resources[id as usize],
        );
    }
    register_resource(
        &backend,
        &params.out_reactive,
        effect_context_id,
        &mut context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize],
    );
    let mut job_descriptor = FfxComputeJobDescription {
        pipeline: pipeline.clone(),
        dimensions: [
            params.render_size.width.wrapping_add(7) / 8,
            params.render_size.height.wrapping_add(7) / 8,
            1,
        ],
        srv_textures: pipeline
            .srv_texture_bindings
            .iter()
            .map(|binding| FfxTextureSRV {
                resource: context.srv_resources[binding.resource_identifier as usize],
            })
            .collect(),
        uav_textures: vec![FfxTextureUAV::default(); pipeline.uav_texture_bindings.len().max(1)],
        cbs: Vec::new(),
        ..Default::default()
    };
    job_descriptor.uav_textures[0].resource =
        context.uav_resources[FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize];
    let constants = Fsr3UpscalerGenerateReactiveConstants {
        scale: params.scale,
        threshold: params.cutoff_threshold,
        binary_value: params.binary_value,
        flags: params.flags,
    };
    let _ = backend.borrow_mut().stage_constant_buffer_data_func(
        &constants.words(),
        &mut context.constant_buffers
            [FFX_FSR3UPSCALER_CONSTANTBUFFER_IDENTIFIER_GENREACTIVE as usize],
    );
    job_descriptor.cbs = pipeline
        .constant_buffer_bindings
        .iter()
        .map(|binding| context.constant_buffers[binding.resource_identifier as usize].clone())
        .collect();
    let dispatch_job = FfxGpuJobDescription {
        job_label: String::new(),
        descriptor: FfxGpuJobDescriptor::Compute(Box::new(job_descriptor)),
    };
    let _ = backend.borrow_mut().schedule_gpu_job(&dispatch_job);
    let _ = backend
        .borrow_mut()
        .execute_gpu_jobs(params.command_list, effect_context_id);
    let _ = backend
        .borrow_mut()
        .unregister_resources(params.command_list, effect_context_id);
    Ok(())
}

/// `ffxFsr3UpscalerSetConstant`; `None` is the SDK's null value pointer and restores the key's default.
pub fn ffx_fsr3_upscaler_set_constant(
    context: &mut FfxFsr3UpscalerContext,
    key: FfxFsr3UpscalerConfigureKey,
    value: Option<f32>,
) -> Result<(), FfxErrorCode> {
    let context = context
        .private
        .as_deref_mut()
        .ok_or(FFX_ERROR_INVALID_POINTER)?;
    // Match ffxMin/ffxMax's comparison ordering, including NaN inputs.
    let max = |a: f32, b: f32| if a > b { a } else { b };
    let min = |a: f32, b: f32| if a < b { a } else { b };
    let saturate = |v| min(1.0, max(0.0, v));
    match key {
        FfxFsr3UpscalerConfigureKey::VelocityFactor => {
            context.constants.velocity_factor = saturate(value.unwrap_or(1.0))
        }
        FfxFsr3UpscalerConfigureKey::ReactivenessScale => {
            context.constants.reactiveness_scale = max(0.0, value.unwrap_or(1.0))
        }
        FfxFsr3UpscalerConfigureKey::ShadingChangeScale => {
            context.constants.shading_change_scale = max(0.0, value.unwrap_or(1.0))
        }
        FfxFsr3UpscalerConfigureKey::AccumulationAddedPerFrame => {
            context.constants.accumulation_added_per_frame = saturate(value.unwrap_or(1.0 / 3.0))
        }
        FfxFsr3UpscalerConfigureKey::MinDisocclusionAccumulation => {
            context.constants.min_disocclusion_accumulation =
                min(1.0, max(-1.0, value.unwrap_or(-1.0 / 3.0)))
        }
    }
    Ok(())
}

/// `ffxFsr3UpscalerGetEffectVersion`.
pub fn ffx_fsr3_upscaler_get_effect_version() -> FfxVersionNumber {
    ffx_sdk_make_version(
        FFX_FSR3UPSCALER_VERSION_MAJOR,
        FFX_FSR3UPSCALER_VERSION_MINOR,
        FFX_FSR3UPSCALER_VERSION_PATCH,
    )
}

/// `ffxFsr3UpscalerSetGlobalDebugMessage`.
pub fn ffx_fsr3_upscaler_set_global_debug_message(
    fp_message: Option<FfxMessageCallback>,
    debug_level: u32,
) -> Result<(), FfxErrorCode> {
    ffx_set_print_message_callback(fp_message, debug_level);
    Ok(())
}
