//! Port of `sdk/src/components/fsr2/ffx_fsr2.cpp` (FidelityFX SDK 1.1.4).
//!
//! The `_GAMING_XBOX` branch of `getPipelinePermutationFlags` is not ported.
use super::common::{LOCK_LIFETIME_REMAINING, LOCK_TEMPORAL_LUMA};
use super::maximum_bias::{
    FFX_FSR2_MAXIMUM_BIAS, FFX_FSR2_MAXIMUM_BIAS_TEXTURE_HEIGHT,
    FFX_FSR2_MAXIMUM_BIAS_TEXTURE_WIDTH,
};
use super::private::*;
use super::resources::*;
use super::{
    FFX_FSR2_ENABLE_AUTO_EXPOSURE, FFX_FSR2_ENABLE_DEBUG_CHECKING, FFX_FSR2_ENABLE_DEPTH_INFINITE,
    FFX_FSR2_ENABLE_DEPTH_INVERTED, FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS,
    FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE, FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
    FFX_FSR2_VERSION_MAJOR, FFX_FSR2_VERSION_MINOR, FFX_FSR2_VERSION_PATCH, FfxFsr2Context,
    FfxFsr2ContextDescription, FfxFsr2DispatchDescription, FfxFsr2GenerateReactiveDescription,
    FfxFsr2Pass, FfxFsr2QualityMode,
};
use crate::assert::ffx_assert;
use crate::error::*;
use crate::gpu::fsr1::fsr_rcas_con;
use crate::gpu::spd::ffx_spd_setup;
use crate::interface::{FfxInterfaceRef, FfxPass, ffx_sdk_make_version};
use crate::message::{ffx_print_message, ffx_set_print_message_callback};
use crate::object_management::{
    ffx_safe_release_copy_resource, ffx_safe_release_pipeline, ffx_safe_release_resource,
};
use crate::types::*;
use crate::util::{FFX_EPSILON, FFX_PI};

/// max queued frames for descriptor management
const FSR2_MAX_QUEUED_FRAMES: u32 = 16;

/// `ResourceBinding`: maps a shader resource bind point name to a resource
/// identifier.
struct ResourceBinding {
    index: u32,
    name: &'static str,
}

const fn resource_binding(index: u32, name: &'static str) -> ResourceBinding {
    ResourceBinding { index, name }
}

const SRV_TEXTURE_BINDING_TABLE: &[ResourceBinding] = &[
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_COLOR,
        "r_input_color_jittered",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY,
        "r_input_opaque_only",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS,
        "r_input_motion_vectors",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_DEPTH, "r_input_depth"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_EXPOSURE,
        "r_input_exposure",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_AUTO_EXPOSURE,
        "r_auto_exposure",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK,
        "r_reactive_mask",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK,
        "r_transparency_and_composition_mask",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
        "r_reconstructed_previous_nearest_depth",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        "r_dilated_motion_vectors",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREVIOUS_DILATED_MOTION_VECTORS,
        "r_previous_dilated_motion_vectors",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_DEPTH, "r_dilatedDepth"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR,
        "r_internal_upscaled_color",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS, "r_lock_status"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREPARED_INPUT_COLOR,
        "r_prepared_input_color",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY, "r_luma_history"),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_RCAS_INPUT, "r_rcas_input"),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_LANCZOS_LUT, "r_lanczos_lut"),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE, "r_imgMips"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_SHADING_CHANGE,
        "r_img_mip_shading_change",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_5,
        "r_img_mip_5",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTITIER_UPSAMPLE_MAXIMUM_BIAS_LUT,
        "r_upsample_maximum_bias_lut",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
        "r_dilated_reactive_masks",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_NEW_LOCKS, "r_new_locks"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_INPUT_LUMA,
        "r_lock_input_luma",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR,
        "r_input_prev_color_pre_alpha",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR,
        "r_input_prev_color_post_alpha",
    ),
];

const UAV_TEXTURE_BINDING_TABLE: &[ResourceBinding] = &[
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
        "rw_reconstructed_previous_nearest_depth",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
        "rw_dilated_motion_vectors",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_DEPTH,
        "rw_dilatedDepth",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR,
        "rw_internal_upscaled_color",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS, "rw_lock_status"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREPARED_INPUT_COLOR,
        "rw_prepared_input_color",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY, "rw_luma_history"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_UPSCALED_OUTPUT,
        "rw_upscaled_output",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_SHADING_CHANGE,
        "rw_img_mip_shading_change",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_5,
        "rw_img_mip_5",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
        "rw_dilated_reactive_masks",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_AUTO_EXPOSURE,
        "rw_auto_exposure",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT,
        "rw_spd_global_atomic",
    ),
    resource_binding(FFX_FSR2_RESOURCE_IDENTIFIER_NEW_LOCKS, "rw_new_locks"),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_INPUT_LUMA,
        "rw_lock_input_luma",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE,
        "rw_output_autoreactive",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_AUTOCOMPOSITION,
        "rw_output_autocomposition",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR,
        "rw_output_prev_color_pre_alpha",
    ),
    resource_binding(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR,
        "rw_output_prev_color_post_alpha",
    ),
];

const CONSTANT_BUFFER_BINDING_TABLE: &[ResourceBinding] = &[
    resource_binding(FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_FSR2, "cbFSR2"),
    resource_binding(FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_SPD, "cbSPD"),
    resource_binding(FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_RCAS, "cbRCAS"),
    resource_binding(
        FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_GENREACTIVE,
        "cbGenerateReactive",
    ),
];

/// `Fsr2RcasConstants` (`FfxRcasConstants`).
#[derive(Clone, Copy, Default)]
struct Fsr2RcasConstants {
    rcas_config: [u32; 4],
}

impl Fsr2RcasConstants {
    const WORDS: u32 = 4;

    fn words(&self) -> Vec<u32> {
        self.rcas_config.to_vec()
    }
}

/// `Fsr2SpdConstants`.
#[derive(Clone, Copy, Default)]
struct Fsr2SpdConstants {
    mips: u32,
    numwork_groups: u32,
    work_group_offset: [u32; 2],
    render_size: [u32; 2],
}

impl Fsr2SpdConstants {
    const WORDS: u32 = 6;

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

/// `Fsr2GenerateReactiveConstants`.
#[derive(Clone, Copy, Default)]
struct Fsr2GenerateReactiveConstants {
    scale: f32,
    threshold: f32,
    binary_value: f32,
    flags: u32,
}

impl Fsr2GenerateReactiveConstants {
    const WORDS: u32 = 4;

    fn words(&self) -> Vec<u32> {
        vec![
            self.scale.to_bits(),
            self.threshold.to_bits(),
            self.binary_value.to_bits(),
            self.flags,
        ]
    }
}

/// `Fsr2GenerateReactiveConstants2`.
#[derive(Clone, Copy, Default)]
struct Fsr2GenerateReactiveConstants2 {
    auto_tc_threshold: f32,
    auto_tc_scale: f32,
    auto_reactive_scale: f32,
    auto_reactive_max: f32,
}

impl Fsr2GenerateReactiveConstants2 {
    const WORDS: u32 = 4;

    /// The first `sizeof(Fsr2GenerateReactiveConstants)` bytes of the structure,
    /// as the SDK stages it.
    fn words(&self) -> Vec<u32> {
        let words = [
            self.auto_tc_threshold.to_bits(),
            self.auto_tc_scale.to_bits(),
            self.auto_reactive_scale.to_bits(),
            self.auto_reactive_max.to_bits(),
        ];
        words[..Fsr2GenerateReactiveConstants::WORDS as usize].to_vec()
    }
}

/// `sizeof(Fsr2SecondaryUnion) / sizeof(uint32_t)`: the union of
/// `Fsr2RcasConstants`, `Fsr2SpdConstants` and `Fsr2GenerateReactiveConstants2`.
const FSR2_SECONDARY_UNION_WORDS: u32 = {
    let mut words = Fsr2RcasConstants::WORDS;
    if Fsr2SpdConstants::WORDS > words {
        words = Fsr2SpdConstants::WORDS;
    }
    if Fsr2GenerateReactiveConstants2::WORDS > words {
        words = Fsr2GenerateReactiveConstants2::WORDS;
    }
    words
};

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

/// `fsr2DebugCheckDispatch`.
fn fsr2_debug_check_dispatch(context: &FfxFsr2ContextPrivate, params: &FfxFsr2DispatchDescription) {
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
        && (context.context_description.flags & FFX_FSR2_ENABLE_AUTO_EXPOSURE)
            == FFX_FSR2_ENABLE_AUTO_EXPOSURE
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

    let infinite_depth = (context.context_description.flags & FFX_FSR2_ENABLE_DEPTH_INFINITE)
        == FFX_FSR2_ENABLE_DEPTH_INFINITE;
    let inverse_depth = (context.context_description.flags & FFX_FSR2_ENABLE_DEPTH_INVERTED)
        == FFX_FSR2_ENABLE_DEPTH_INVERTED;

    if inverse_depth {
        if params.camera_near < params.camera_far {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR2_ENABLE_DEPTH_INVERTED flag is present yet cameraNear is less than cameraFar",
            );
        }
        if infinite_depth && params.camera_near != f32::MAX {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR2_ENABLE_DEPTH_INFINITE and FFX_FSR2_ENABLE_DEPTH_INVERTED present, yet cameraNear != FLT_MAX",
            );
        }
        if params.camera_far < 0.075 {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR2_ENABLE_DEPTH_INFINITE and FFX_FSR2_ENABLE_DEPTH_INVERTED present, cameraFar value is very low which may result in depth separation artefacting",
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
                "FFX_FSR2_ENABLE_DEPTH_INFINITE and FFX_FSR2_ENABLE_DEPTH_INVERTED present, yet cameraFar != FLT_MAX",
            );
        }
        if params.camera_near < 0.075 {
            ffx_print_message(
                FfxMsgType::Warning as u32,
                "FFX_FSR2_ENABLE_DEPTH_INFINITE and FFX_FSR2_ENABLE_DEPTH_INVERTED present, cameraNear value is very low which may result in depth separation artefacting",
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
    pass_id: FfxFsr2Pass,
    fp16: bool,
    force64: bool,
    use_lut: bool,
) -> u32 {
    // work out what permutation to load.
    let mut flags = 0;
    flags |= if context_flags & FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE != 0 {
        FSR2_SHADER_PERMUTATION_HDR_COLOR_INPUT
    } else {
        0
    };
    flags |= if context_flags & FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS != 0 {
        0
    } else {
        FSR2_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS
    };
    flags |= if context_flags & FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION != 0 {
        FSR2_SHADER_PERMUTATION_JITTER_MOTION_VECTORS
    } else {
        0
    };
    flags |= if context_flags & FFX_FSR2_ENABLE_DEPTH_INVERTED != 0 {
        FSR2_SHADER_PERMUTATION_DEPTH_INVERTED
    } else {
        0
    };
    flags |= if pass_id == FfxFsr2Pass::AccumulateSharpen {
        FSR2_SHADER_PERMUTATION_ENABLE_SHARPENING
    } else {
        0
    };
    flags |= if use_lut {
        FSR2_SHADER_PERMUTATION_USE_LANCZOS_TYPE
    } else {
        0
    };
    flags |= if force64 {
        FSR2_SHADER_PERMUTATION_FORCE_WAVE64
    } else {
        0
    };
    flags |= if fp16 && (pass_id != FfxFsr2Pass::Rcas) {
        FSR2_SHADER_PERMUTATION_ALLOW_FP16
    } else {
        0
    };
    flags
}

/// `createPipelineStates`.
fn create_pipeline_states(context: &mut FfxFsr2ContextPrivate) -> Result<(), FfxErrorCode> {
    // Samplers
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

    // Root constants
    let root_constant_descs = [
        FfxRootConstantDescription {
            size: Fsr2Constants::WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
        FfxRootConstantDescription {
            size: FSR2_SECONDARY_UNION_WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];

    // `FfxPipelineDescription pipelineDescription = {};`
    let mut pipeline_description = FfxPipelineDescription {
        context_flags: context.context_description.flags,
        samplers: &sampler_descs,
        root_constants: &root_constant_descs,
        name: String::new(),
        stage: 0,
        indirect_workload: 0,
        backbuffer_format: FfxSurfaceFormat::Unknown,
    };

    // Query device capabilities
    let backend = context.context_description.backend_interface.clone();
    // The SDK ignores this call's result; its capabilities are then undefined.
    let capabilities = backend
        .borrow_mut()
        .get_device_capabilities()
        .unwrap_or_default();

    // Setup a few options used to determine permutation flags
    let have_shader_model66 =
        capabilities.maximum_supported_shader_model >= FfxShaderModel::ShaderModel6_6;
    let supported_fp16 = capabilities.fp16_supported;
    let can_force_wave64;
    let mut use_lut = false;

    let wave_lane_count_min = capabilities.wave_lane_count_min;
    let wave_lane_count_max = capabilities.wave_lane_count_max;
    if wave_lane_count_min <= 64 && wave_lane_count_max >= 64 {
        use_lut = true;
        can_force_wave64 = have_shader_model66;
    } else {
        can_force_wave64 = false;
    }

    // Work out what permutation to load.
    let context_flags = context.context_description.flags;
    let create = |pass: FfxFsr2Pass, description: &FfxPipelineDescription<'_>, id: u32| {
        backend.borrow_mut().create_pipeline(
            FfxEffect::Fsr2,
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

    // Set up pipeline descriptor (basically RootSignature and binding)
    pipeline_description.name = "FSR2-LUM_PYRAMID".into();
    context.pipeline_compute_luminance_pyramid = ffx_validate!(create(
        FfxFsr2Pass::ComputeLuminancePyramid,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-RCAS".into();
    context.pipeline_rcas = ffx_validate!(create(
        FfxFsr2Pass::Rcas,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-GEN_REACTIVE".into();
    context.pipeline_generate_reactive = ffx_validate!(create(
        FfxFsr2Pass::GenerateReactive,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-TCR_AUTOGENERATE".into();
    context.pipeline_tcr_autogenerate = ffx_validate!(create(
        FfxFsr2Pass::TcrAutogenerate,
        &pipeline_description,
        context.effect_context_id
    ));

    // `pipelineDescription.rootConstantBufferCount = 1;`
    pipeline_description.root_constants = &root_constant_descs[..1];

    pipeline_description.name = "FSR2-DEPTH_CLIP".into();
    context.pipeline_depth_clip = ffx_validate!(create(
        FfxFsr2Pass::DepthClip,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-RECON_PREV_DEPTH".into();
    context.pipeline_reconstruct_previous_depth = ffx_validate!(create(
        FfxFsr2Pass::ReconstructPreviousDepth,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-LOCK".into();
    context.pipeline_lock = ffx_validate!(create(
        FfxFsr2Pass::Lock,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-ACCUMULATE".into();
    context.pipeline_accumulate = ffx_validate!(create(
        FfxFsr2Pass::Accumulate,
        &pipeline_description,
        context.effect_context_id
    ));
    pipeline_description.name = "FSR2-ACCUM_SHARP".into();
    context.pipeline_accumulate_sharpen = ffx_validate!(create(
        FfxFsr2Pass::AccumulateSharpen,
        &pipeline_description,
        context.effect_context_id
    ));

    // for each pipeline: re-route/fix-up IDs based on names; the SDK ignores
    // the results.
    let _ = patch_resource_bindings(&mut context.pipeline_depth_clip);
    let _ = patch_resource_bindings(&mut context.pipeline_reconstruct_previous_depth);
    let _ = patch_resource_bindings(&mut context.pipeline_lock);
    let _ = patch_resource_bindings(&mut context.pipeline_accumulate);
    let _ = patch_resource_bindings(&mut context.pipeline_compute_luminance_pyramid);
    let _ = patch_resource_bindings(&mut context.pipeline_accumulate_sharpen);
    let _ = patch_resource_bindings(&mut context.pipeline_rcas);
    let _ = patch_resource_bindings(&mut context.pipeline_generate_reactive);
    let _ = patch_resource_bindings(&mut context.pipeline_tcr_autogenerate);

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

/// `fsr2Create`.
#[expect(clippy::too_many_lines, reason = "one SDK function")]
fn fsr2_create(
    context: &mut FfxFsr2ContextPrivate,
    context_description: &FfxFsr2ContextDescription,
) -> Result<(), FfxErrorCode> {
    // Setup the data for implementation.
    *context = FfxFsr2ContextPrivate::zeroed(context_description.clone());
    let backend = context.context_description.backend_interface.clone();
    context.device = backend.borrow().device();

    // Check version info - make sure we are linked with the right backend version
    let version = backend.borrow_mut().get_sdk_version();
    ffx_return_on_error!(
        version == ffx_sdk_make_version(1, 1, 4),
        FFX_ERROR_INVALID_VERSION
    );

    // Setup constant buffer sizes.
    context.constant_buffers[0].num_32bit_entries = Fsr2Constants::WORDS;
    context.constant_buffers[1].num_32bit_entries = Fsr2SpdConstants::WORDS;
    context.constant_buffers[2].num_32bit_entries = Fsr2RcasConstants::WORDS;
    context.constant_buffers[3].num_32bit_entries = Fsr2GenerateReactiveConstants::WORDS;

    // Create the context.
    context.effect_context_id = backend
        .borrow_mut()
        .create_backend_context(FfxEffect::Fsr2, None)?;

    // call out for device caps.
    context.device_capabilities = backend.borrow_mut().get_device_capabilities()?;

    // set defaults
    context.first_execution = true;
    context.resource_frame_index = 0;

    context.constants.display_size[0] = context_description.display_size.width as i32;
    context.constants.display_size[1] = context_description.display_size.height as i32;

    // generate the data for the LUT.
    const LANCZOS2_LUT_WIDTH: u32 = 128;
    let mut lanczos2_weights = [0i16; LANCZOS2_LUT_WIDTH as usize];

    for current_lanczos_width_index in 0..LANCZOS2_LUT_WIDTH {
        let x = 2.0 * current_lanczos_width_index as f32 / (LANCZOS2_LUT_WIDTH - 1) as f32;
        let y = lanczos2(x);
        lanczos2_weights[current_lanczos_width_index as usize] = (y * 32767.0).round() as i16;
    }

    // upload path only supports R16_SNORM, let's go and convert
    let mut maximum_bias = [0i16;
        (FFX_FSR2_MAXIMUM_BIAS_TEXTURE_WIDTH * FFX_FSR2_MAXIMUM_BIAS_TEXTURE_HEIGHT) as usize];
    for i in
        0..(FFX_FSR2_MAXIMUM_BIAS_TEXTURE_WIDTH * FFX_FSR2_MAXIMUM_BIAS_TEXTURE_HEIGHT) as usize
    {
        maximum_bias[i] = (FFX_FSR2_MAXIMUM_BIAS[i] / 2.0 * 32767.0).round() as i16;
    }
    let lanczos2_weights = int16_bytes(&lanczos2_weights);
    let maximum_bias = int16_bytes(&maximum_bias);

    let max_render_size = context_description.max_render_size;
    let display_size = context_description.display_size;
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

    // declare internal resources needed
    let internal_surface_desc = [
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_PREPARED_INPUT_COLOR,
            "FSR2_PreparedInputColor",
            FFX_RESOURCE_USAGE_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16B16A16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH,
            "FSR2_ReconstructedPrevNearestDepth",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R32Uint,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DILATED_MOTION_VECTORS_1,
            "FSR2_InternalDilatedVelocity1",
            FFX_RESOURCE_USAGE_RENDERTARGET
                | FFX_RESOURCE_USAGE_UAV
                | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DILATED_MOTION_VECTORS_2,
            "FSR2_InternalDilatedVelocity2",
            FFX_RESOURCE_USAGE_RENDERTARGET
                | FFX_RESOURCE_USAGE_UAV
                | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_DEPTH,
            "FSR2_DilatedDepth",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R32Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_1,
            "FSR2_LockStatus1",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16G16Float,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_2,
            "FSR2_LockStatus2",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16G16Float,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_INPUT_LUMA,
            "FSR2_LockInputLuma",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_NEW_LOCKS,
            "FSR2_NewLocks",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8Unorm,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_1,
            "FSR2_InternalUpscaled1",
            FFX_RESOURCE_USAGE_RENDERTARGET
                | FFX_RESOURCE_USAGE_UAV
                | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16B16A16Float,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_2,
            "FSR2_InternalUpscaled2",
            FFX_RESOURCE_USAGE_RENDERTARGET
                | FFX_RESOURCE_USAGE_UAV
                | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R16G16B16A16Float,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE,
            "FSR2_ExposureMips",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R16Float,
            max_render_size.width / 2,
            max_render_size.height / 2,
            0,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY_1,
            "FSR2_LumaHistory1",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8G8B8A8Unorm,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY_2,
            "FSR2_LumaHistory2",
            FFX_RESOURCE_USAGE_RENDERTARGET | FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8G8B8A8Unorm,
            display_size.width,
            display_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT,
            "FSR2_SpdAtomicCounter",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R32Uint,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            FfxResourceInitData::ffx_resource_init_value(size_of::<u32>(), 0),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_REACTIVE_MASKS,
            "FSR2_DilatedReactiveMasks",
            FFX_RESOURCE_USAGE_UAV | FFX_RESOURCE_USAGE_DCC_RENDERTARGET,
            FfxSurfaceFormat::R8G8Unorm,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_ALIASABLE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_LANCZOS_LUT,
            "FSR2_LanczosLutData",
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
            FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY,
            "FSR2_DefaultReactivityMask",
            FFX_RESOURCE_USAGE_READ_ONLY,
            FfxSurfaceFormat::R8Unorm,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_value(size_of::<u8>(), 0),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTITIER_UPSAMPLE_MAXIMUM_BIAS_LUT,
            "FSR2_MaximumUpsampleBias",
            FFX_RESOURCE_USAGE_READ_ONLY,
            FfxSurfaceFormat::R16Snorm,
            FFX_FSR2_MAXIMUM_BIAS_TEXTURE_WIDTH as u32,
            FFX_FSR2_MAXIMUM_BIAS_TEXTURE_HEIGHT as u32,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_buffer(maximum_bias.len(), &maximum_bias),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_EXPOSURE,
            "FSR2_DefaultExposure",
            FFX_RESOURCE_USAGE_READ_ONLY,
            FfxSurfaceFormat::R32G32Float,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            FfxResourceInitData::ffx_resource_init_value(size_of::<f32>() * 2, 0),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_AUTO_EXPOSURE,
            "FSR2_AutoExposure",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R32G32Float,
            1,
            1,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        // only one for now, will need ping pong to respect the motion vectors
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE,
            "FSR2_AutoReactive",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8Unorm,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_AUTOCOMPOSITION,
            "FSR2_AutoComposition",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R8Unorm,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR_1,
            "FSR2_PrevPreAlpha0",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R11G11B10Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR_1,
            "FSR2_PrevPostAlpha0",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R11G11B10Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR_2,
            "FSR2_PrevPreAlpha1",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R11G11B10Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
        surface(
            FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR_2,
            "FSR2_PrevPostAlpha1",
            FFX_RESOURCE_USAGE_UAV,
            FfxSurfaceFormat::R11G11B10Float,
            max_render_size.width,
            max_render_size.height,
            1,
            FFX_RESOURCE_FLAGS_NONE,
            uninitialized(),
        ),
    ];

    // clear the SRV resources to NULL.
    context.srv_resources =
        [FfxResourceInternal::default(); FFX_FSR2_RESOURCE_IDENTIFIER_COUNT as usize];

    for current_surface_description in &internal_surface_desc {
        let resource_type = current_surface_description.r#type;
        let resource_description = FfxResourceDescription {
            r#type: resource_type,
            format: current_surface_description.format,
            width: current_surface_description.width,
            height: current_surface_description.height,
            depth: 1,
            mip_count: current_surface_description.mip_count,
            flags: FFX_RESOURCE_FLAGS_NONE,
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

/// `fsr2Release`.
fn fsr2_release(context: &mut FfxFsr2ContextPrivate) -> Result<(), FfxErrorCode> {
    let backend = context.context_description.backend_interface.clone();
    let effect_context_id = context.effect_context_id;

    for pipeline in [
        &mut context.pipeline_depth_clip,
        &mut context.pipeline_reconstruct_previous_depth,
        &mut context.pipeline_lock,
        &mut context.pipeline_accumulate,
        &mut context.pipeline_accumulate_sharpen,
        &mut context.pipeline_rcas,
        &mut context.pipeline_compute_luminance_pyramid,
        &mut context.pipeline_generate_reactive,
        &mut context.pipeline_tcr_autogenerate,
    ] {
        ffx_safe_release_pipeline(&mut *backend.borrow_mut(), pipeline, effect_context_id);
    }

    // unregister resources not created internally
    let null = FfxResourceInternal {
        internal_index: FFX_FSR2_RESOURCE_IDENTIFIER_NULL as i32,
    };
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_COLOR as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_DEPTH as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK as usize] = null;
    context.srv_resources
        [FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_RCAS_INPUT as usize] = null;
    context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_UPSCALED_OUTPUT as usize] = null;

    // Release the copy resources for those that had init data
    for id in [
        FFX_FSR2_RESOURCE_IDENTIFIER_SPD_ATOMIC_COUNT,
        FFX_FSR2_RESOURCE_IDENTIFIER_LANCZOS_LUT,
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY,
        FFX_FSR2_RESOURCE_IDENTITIER_UPSAMPLE_MAXIMUM_BIAS_LUT,
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_EXPOSURE,
    ] {
        ffx_safe_release_copy_resource(
            &mut *backend.borrow_mut(),
            context.srv_resources[id as usize],
            effect_context_id,
        );
    }

    // release internal resources
    for current_resource_index in 0..FFX_FSR2_RESOURCE_IDENTIFIER_COUNT as usize {
        ffx_safe_release_resource(
            &mut *backend.borrow_mut(),
            context.srv_resources[current_resource_index],
            effect_context_id,
        );
    }

    // Destroy the context
    let _ = backend
        .borrow_mut()
        .destroy_backend_context(effect_context_id);

    Ok(())
}

/// `setupDeviceDepthToViewSpaceDepthParams`.
fn setup_device_depth_to_view_space_depth_params(
    context: &mut FfxFsr2ContextPrivate,
    params: &FfxFsr2DispatchDescription,
) {
    let b_inverted = (context.context_description.flags & FFX_FSR2_ENABLE_DEPTH_INVERTED)
        == FFX_FSR2_ENABLE_DEPTH_INVERTED;
    let b_infinite = (context.context_description.flags & FFX_FSR2_ENABLE_DEPTH_INFINITE)
        == FFX_FSR2_ENABLE_DEPTH_INFINITE;

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
    context: &FfxFsr2ContextPrivate,
    _params: &FfxFsr2DispatchDescription,
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
        if (FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_0
            ..=FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_12)
            .contains(&current_resource_id)
        {
            let current_resource =
                context.uav_resources[FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE as usize];
            uav.resource = current_resource;
            uav.mip = current_resource_id - FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE_MIPMAP_0;
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

/// `fpScheduleGpuJob` of a `FFX_GPU_JOB_CLEAR_FLOAT` job.
fn schedule_clear(backend: &FfxInterfaceRef, clear_job_descriptor: FfxClearFloatJobDescription) {
    let _ = backend
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: "Zero initialize resource".into(),
            descriptor: FfxGpuJobDescriptor::ClearFloat(clear_job_descriptor),
        });
}

/// `fsr2Dispatch`.
#[expect(clippy::too_many_lines, reason = "one SDK function")]
fn fsr2_dispatch(
    context: &mut FfxFsr2ContextPrivate,
    params: &FfxFsr2DispatchDescription,
) -> Result<(), FfxErrorCode> {
    if (context.context_description.flags & FFX_FSR2_ENABLE_DEBUG_CHECKING)
        == FFX_FSR2_ENABLE_DEBUG_CHECKING
    {
        fsr2_debug_check_dispatch(context, params);
    }

    let backend = context.context_description.backend_interface.clone();
    // take a short cut to the command list
    let command_list = params.command_list;

    if context.first_execution {
        let mut clear_job = FfxClearFloatJobDescription {
            color: [0.0, 0.0, 0.0, 0.0],
            target: FfxResourceInternal::default(),
        };

        clear_job.target =
            context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_1 as usize];
        schedule_clear(&backend, clear_job);
        clear_job.target =
            context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_2 as usize];
        schedule_clear(&backend, clear_job);
        clear_job.target =
            context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_PREPARED_INPUT_COLOR as usize];
        schedule_clear(&backend, clear_job);
    }

    // Prepare per frame descriptor tables
    let is_odd_frame = (context.resource_frame_index & 1) != 0;
    let pick = |odd: u32, even: u32| (if is_odd_frame { odd } else { even }) as usize;
    let lock_status_srv_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_2,
        FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_1,
    );
    let lock_status_uav_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_1,
        FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS_2,
    );
    let upscaled_color_srv_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_2,
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_1,
    );
    let upscaled_color_uav_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_1,
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR_2,
    );
    let dilated_motion_vectors_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DILATED_MOTION_VECTORS_2,
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DILATED_MOTION_VECTORS_1,
    );
    let previous_dilated_motion_vectors_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DILATED_MOTION_VECTORS_1,
        FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DILATED_MOTION_VECTORS_2,
    );
    let luma_history_srv_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY_2,
        FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY_1,
    );
    let luma_history_uav_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY_1,
        FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY_2,
    );

    let prev_pre_alpha_color_srv_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR_2,
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR_1,
    );
    let prev_pre_alpha_color_uav_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR_1,
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR_2,
    );
    let prev_post_alpha_color_srv_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR_2,
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR_1,
    );
    let prev_post_alpha_color_uav_resource_index = pick(
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR_1,
        FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR_2,
    );

    let reset_accumulation = params.reset || context.first_execution;
    context.first_execution = false;

    let effect_context_id = context.effect_context_id;
    let srv = &mut context.srv_resources;
    register_resource(
        &backend,
        &params.color,
        effect_context_id,
        &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_COLOR as usize],
    );
    register_resource(
        &backend,
        &params.depth,
        effect_context_id,
        &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_DEPTH as usize],
    );
    register_resource(
        &backend,
        &params.motion_vectors,
        effect_context_id,
        &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS as usize],
    );

    // if auto exposure is enabled use the auto exposure SRV, otherwise what the app sends.
    if context.context_description.flags & FFX_FSR2_ENABLE_AUTO_EXPOSURE != 0 {
        srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize] =
            srv[FFX_FSR2_RESOURCE_IDENTIFIER_AUTO_EXPOSURE as usize];
    } else if ffx_fsr2_resource_is_null(&params.exposure) {
        srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize] =
            srv[FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_EXPOSURE as usize];
    } else {
        register_resource(
            &backend,
            &params.exposure,
            effect_context_id,
            &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_EXPOSURE as usize],
        );
    }

    if params.enable_auto_reactive {
        register_resource(
            &backend,
            &params.color_opaque_only,
            effect_context_id,
            &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR as usize],
        );
    }

    if ffx_fsr2_resource_is_null(&params.reactive) {
        srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK as usize] =
            srv[FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY as usize];
    } else {
        register_resource(
            &backend,
            &params.reactive,
            effect_context_id,
            &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK as usize],
        );
    }

    if ffx_fsr2_resource_is_null(&params.transparency_and_composition) {
        srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK as usize] =
            srv[FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_DEFAULT_REACTIVITY as usize];
    } else {
        register_resource(
            &backend,
            &params.transparency_and_composition,
            effect_context_id,
            &mut srv[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK as usize],
        );
    }

    register_resource(
        &backend,
        &params.output,
        effect_context_id,
        &mut context.uav_resources[FFX_FSR2_RESOURCE_IDENTIFIER_UPSCALED_OUTPUT as usize],
    );
    let srv = &mut context.srv_resources;
    let uav = &mut context.uav_resources;
    srv[FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS as usize] = srv[lock_status_srv_resource_index];
    srv[FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR as usize] =
        srv[upscaled_color_srv_resource_index];
    uav[FFX_FSR2_RESOURCE_IDENTIFIER_LOCK_STATUS as usize] = uav[lock_status_uav_resource_index];
    uav[FFX_FSR2_RESOURCE_IDENTIFIER_INTERNAL_UPSCALED_COLOR as usize] =
        uav[upscaled_color_uav_resource_index];
    srv[FFX_FSR2_RESOURCE_IDENTIFIER_RCAS_INPUT as usize] = uav[upscaled_color_uav_resource_index];

    srv[FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS as usize] =
        srv[dilated_motion_vectors_resource_index];
    uav[FFX_FSR2_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS as usize] =
        uav[dilated_motion_vectors_resource_index];
    srv[FFX_FSR2_RESOURCE_IDENTIFIER_PREVIOUS_DILATED_MOTION_VECTORS as usize] =
        srv[previous_dilated_motion_vectors_resource_index];

    uav[FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY as usize] = uav[luma_history_uav_resource_index];
    srv[FFX_FSR2_RESOURCE_IDENTIFIER_LUMA_HISTORY as usize] = srv[luma_history_srv_resource_index];

    srv[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR as usize] =
        srv[prev_pre_alpha_color_srv_resource_index];
    uav[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR as usize] =
        uav[prev_pre_alpha_color_uav_resource_index];
    srv[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR as usize] =
        srv[prev_post_alpha_color_srv_resource_index];
    uav[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR as usize] =
        uav[prev_post_alpha_color_uav_resource_index];

    // actual resource size may differ from render/display resolution (e.g. due to Hw/API restrictions), so query the descriptor for UVs adjustment
    let resource_desc_input_color = backend.borrow_mut().get_resource_description(
        context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_COLOR as usize],
    );
    let resource_desc_lock_status = backend
        .borrow_mut()
        .get_resource_description(context.srv_resources[lock_status_srv_resource_index]);
    let _resource_desc_reactive_mask = backend.borrow_mut().get_resource_description(
        context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK as usize],
    );
    ffx_assert!(resource_desc_input_color.r#type == FfxResourceType::Texture2D);
    ffx_assert!(resource_desc_lock_status.r#type == FfxResourceType::Texture2D);

    let constants = &mut context.constants;
    constants.jitter_offset[0] = params.jitter_offset.x;
    constants.jitter_offset[1] = params.jitter_offset.y;
    constants.render_size[0] = (if params.render_size.width != 0 {
        params.render_size.width
    } else {
        resource_desc_input_color.width
    }) as i32;
    constants.render_size[1] = (if params.render_size.height != 0 {
        params.render_size.height
    } else {
        resource_desc_input_color.height
    }) as i32;
    constants.max_render_size[0] = context.context_description.max_render_size.width as i32;
    constants.max_render_size[1] = context.context_description.max_render_size.height as i32;
    constants.input_color_resource_dimensions[0] = resource_desc_input_color.width as i32;
    constants.input_color_resource_dimensions[1] = resource_desc_input_color.height as i32;

    // compute the horizontal FOV for the shader from the vertical one.
    let aspect_ratio = params.render_size.width as f32 / params.render_size.height as f32;
    let camera_angle_horizontal =
        ((params.camera_fov_angle_vertical / 2.0).tan() * aspect_ratio).atan() * 2.0;
    constants.tan_half_fov = (camera_angle_horizontal * 0.5).tan();
    constants.view_space_to_meters_factor = if params.view_space_to_meters_factor > 0.0 {
        params.view_space_to_meters_factor
    } else {
        1.0
    };

    // compute params to enable device depth to view space depth computation in shader
    setup_device_depth_to_view_space_depth_params(context, params);

    // To be updated if resource is larger than the actual image size
    let constants = &mut context.constants;
    constants.downscale_factor[0] =
        constants.render_size[0] as f32 / context.context_description.display_size.width as f32;
    constants.downscale_factor[1] =
        constants.render_size[1] as f32 / context.context_description.display_size.height as f32;
    constants.previous_frame_pre_exposure = constants.pre_exposure;
    constants.pre_exposure = if params.pre_exposure != 0.0 {
        params.pre_exposure
    } else {
        1.0
    };

    // motion vector data
    let motion_vectors_target_size = if context.context_description.flags
        & FFX_FSR2_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
        != 0
    {
        constants.display_size
    } else {
        constants.render_size
    };

    constants.motion_vector_scale[0] =
        params.motion_vector_scale.x / motion_vectors_target_size[0] as f32;
    constants.motion_vector_scale[1] =
        params.motion_vector_scale.y / motion_vectors_target_size[1] as f32;

    // compute jitter cancellation
    if context.context_description.flags & FFX_FSR2_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION != 0 {
        constants.motion_vector_jitter_cancellation[0] = (context.previous_jitter_offset[0]
            - constants.jitter_offset[0])
            / motion_vectors_target_size[0] as f32;
        constants.motion_vector_jitter_cancellation[1] = (context.previous_jitter_offset[1]
            - constants.jitter_offset[1])
            / motion_vectors_target_size[1] as f32;

        context.previous_jitter_offset[0] = constants.jitter_offset[0];
        context.previous_jitter_offset[1] = constants.jitter_offset[1];
    }

    // lock data, assuming jitter sequence length computation for now
    let jitter_phase_count = ffx_fsr2_get_jitter_phase_count(
        params.render_size.width as i32,
        context.context_description.display_size.width as i32,
    );

    // init on first frame
    if reset_accumulation || constants.jitter_phase_count == 0.0 {
        constants.jitter_phase_count = jitter_phase_count as f32;
    } else {
        let jitter_phase_count_delta =
            (jitter_phase_count as f32 - constants.jitter_phase_count) as i32;
        if jitter_phase_count_delta > 0 {
            constants.jitter_phase_count += 1.0;
        } else if jitter_phase_count_delta < 0 {
            constants.jitter_phase_count -= 1.0;
        }
    }

    // convert delta time to seconds and clamp to [0, 1].
    // FFX_MAXIMUM(0.0f, FFX_MINIMUM(1.0f, params->frameTimeDelta / 1000.0f))
    let minimum = if 1.0 < params.frame_time_delta / 1000.0 {
        1.0
    } else {
        params.frame_time_delta / 1000.0
    };
    constants.delta_time = if 0.0 > minimum { 0.0 } else { minimum };

    if reset_accumulation {
        constants.frame_index = 0;
    } else {
        constants.frame_index += 1;
    }

    // shading change usage of the SPD mip levels.
    constants.luma_mip_level_to_use = FFX_FSR2_SHADING_CHANGE_MIP_LEVEL as i32;

    let mip_div = (2 << constants.luma_mip_level_to_use) as f32;
    constants.luma_mip_dimensions[0] =
        (constants.max_render_size[0] as f32 / mip_div) as u32 as i32;
    constants.luma_mip_dimensions[1] =
        (constants.max_render_size[1] as f32 / mip_div) as u32 as i32;

    // reactive mask bias
    let thread_group_work_region_dim: i32 = 8;
    let dispatch_src_x = (constants.render_size[0] + thread_group_work_region_dim - 1)
        / thread_group_work_region_dim;
    let dispatch_src_y = (constants.render_size[1] + thread_group_work_region_dim - 1)
        / thread_group_work_region_dim;
    // FFX_DIVIDE_ROUNDING_UP of the unsigned display size.
    let dispatch_dst_x = (context
        .context_description
        .display_size
        .width
        .wrapping_add(thread_group_work_region_dim as u32)
        .wrapping_sub(1)
        / thread_group_work_region_dim as u32) as i32;
    let dispatch_dst_y = (context
        .context_description
        .display_size
        .height
        .wrapping_add(thread_group_work_region_dim as u32)
        .wrapping_sub(1)
        / thread_group_work_region_dim as u32) as i32;

    // Clear reconstructed depth for max depth store.
    if reset_accumulation {
        // LockStatus resource has no sign bit, callback functions are compensating for this.
        // Clearing the resource must follow the same logic.
        let mut clear_values_lock_status = [0.0f32; 4];
        clear_values_lock_status[LOCK_LIFETIME_REMAINING] = 0.0;
        clear_values_lock_status[LOCK_TEMPORAL_LUMA] = 0.0;

        let mut clear_job = FfxClearFloatJobDescription {
            color: clear_values_lock_status,
            target: context.srv_resources[lock_status_srv_resource_index],
        };
        schedule_clear(&backend, clear_job);

        let clear_values_to_zero_float = [0.0f32, 0.0, 0.0, 0.0];
        clear_job.color = clear_values_to_zero_float;
        clear_job.target = context.srv_resources[upscaled_color_srv_resource_index];
        schedule_clear(&backend, clear_job);

        clear_job.target =
            context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_SCENE_LUMINANCE as usize];
        schedule_clear(&backend, clear_job);

        //if (context->contextDescription.flags & FFX_FSR2_ENABLE_AUTO_EXPOSURE)
        // Auto exposure always used to track luma changes in locking logic
        {
            let clear_values_exposure = [-1.0f32, 1e8, 0.0, 0.0];
            clear_job.color = clear_values_exposure;
            clear_job.target =
                context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTO_EXPOSURE as usize];
            schedule_clear(&backend, clear_job);
        }
    }

    // Auto exposure
    let mut dispatch_thread_group_count_xy = [0u32; 2];
    let mut work_group_offset = [0u32; 2];
    let mut num_work_groups_and_mips = [0u32; 2];
    let rect_info = [0, 0, params.render_size.width, params.render_size.height];
    ffx_spd_setup(
        &mut dispatch_thread_group_count_xy,
        &mut work_group_offset,
        &mut num_work_groups_and_mips,
        rect_info,
    );

    // downsample
    let luminance_pyramid_constants = Fsr2SpdConstants {
        numwork_groups: num_work_groups_and_mips[0],
        mips: num_work_groups_and_mips[1],
        work_group_offset,
        render_size: [params.render_size.width, params.render_size.height],
    };

    // compute the constants.
    let mut rcas_consts = Fsr2RcasConstants::default();
    let sharpeness_remapped = (-2.0 * params.sharpness) + 2.0;
    fsr_rcas_con(&mut rcas_consts.rcas_config, sharpeness_remapped);

    let gen_reactive_consts = Fsr2GenerateReactiveConstants2 {
        auto_tc_threshold: params.auto_tc_threshold,
        auto_tc_scale: params.auto_tc_scale,
        auto_reactive_scale: params.auto_reactive_scale,
        auto_reactive_max: params.auto_reactive_max,
    };

    // initialize constantBuffers data
    let _ = backend.borrow_mut().stage_constant_buffer_data_func(
        &context.constants.words(),
        &mut context.constant_buffers[FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_FSR2 as usize],
    );
    let _ = backend.borrow_mut().stage_constant_buffer_data_func(
        &luminance_pyramid_constants.words(),
        &mut context.constant_buffers[FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_SPD as usize],
    );
    let _ = backend.borrow_mut().stage_constant_buffer_data_func(
        &rcas_consts.words(),
        &mut context.constant_buffers[FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_RCAS as usize],
    );
    let _ = backend.borrow_mut().stage_constant_buffer_data_func(
        &gen_reactive_consts.words(),
        &mut context.constant_buffers[FFX_FSR2_CONSTANTBUFFER_IDENTIFIER_GENREACTIVE as usize],
    );

    // Auto reactive
    if params.enable_auto_reactive {
        let _ = generate_reactive_mask_internal(context, params);
        context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_REACTIVE_MASK as usize] =
            context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize];
        context.srv_resources
            [FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_TRANSPARENCY_AND_COMPOSITION_MASK as usize] =
            context.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOCOMPOSITION as usize];
    }

    schedule_dispatch(
        context,
        params,
        &context.pipeline_compute_luminance_pyramid,
        dispatch_thread_group_count_xy[0],
        dispatch_thread_group_count_xy[1],
    );
    schedule_dispatch(
        context,
        params,
        &context.pipeline_reconstruct_previous_depth,
        dispatch_src_x as u32,
        dispatch_src_y as u32,
    );
    schedule_dispatch(
        context,
        params,
        &context.pipeline_depth_clip,
        dispatch_src_x as u32,
        dispatch_src_y as u32,
    );

    let sharpen_enabled = params.enable_sharpening;

    schedule_dispatch(
        context,
        params,
        &context.pipeline_lock,
        dispatch_src_x as u32,
        dispatch_src_y as u32,
    );
    schedule_dispatch(
        context,
        params,
        if sharpen_enabled {
            &context.pipeline_accumulate_sharpen
        } else {
            &context.pipeline_accumulate
        },
        dispatch_dst_x as u32,
        dispatch_dst_y as u32,
    );

    // RCAS
    if sharpen_enabled {
        // dispatch RCAS
        let thread_group_work_region_dim_rcas: i32 = 16;
        let dispatch_x = context
            .context_description
            .display_size
            .width
            .wrapping_add(thread_group_work_region_dim_rcas as u32)
            .wrapping_sub(1)
            / thread_group_work_region_dim_rcas as u32;
        let dispatch_y = context
            .context_description
            .display_size
            .height
            .wrapping_add(thread_group_work_region_dim_rcas as u32)
            .wrapping_sub(1)
            / thread_group_work_region_dim_rcas as u32;
        schedule_dispatch(
            context,
            params,
            &context.pipeline_rcas,
            dispatch_x,
            dispatch_y,
        );
    }

    context.resource_frame_index = (context.resource_frame_index + 1) % FSR2_MAX_QUEUED_FRAMES;

    // Fsr2MaxQueuedFrames must be an even number.
    const { assert!((FSR2_MAX_QUEUED_FRAMES & 1) == 0) };

    let _ = backend
        .borrow_mut()
        .execute_gpu_jobs(command_list, effect_context_id);

    // release dynamic resources
    let _ = backend
        .borrow_mut()
        .unregister_resources(command_list, effect_context_id);

    Ok(())
}

/// `ffxFsr2ContextCreate`. The SDK's `NULL` pointer and `NULL` callback
/// checks hold statically for Rust references and trait implementations, and
/// the backend owns its memory (no `scratchBuffer`).
pub fn ffx_fsr2_context_create(
    context: &mut FfxFsr2Context,
    context_description: &FfxFsr2ContextDescription,
) -> Result<(), FfxErrorCode> {
    // zero context memory
    *context = FfxFsr2Context::default();

    // create the context.
    let context_private = context
        .private
        .insert(Box::new(FfxFsr2ContextPrivate::zeroed(
            context_description.clone(),
        )));
    fsr2_create(context_private, context_description)
}

/// `ffxFsr2ContextGetGpuMemoryUsage`. A context that was never created is the
/// SDK's `NULL` context.
pub fn ffx_fsr2_context_get_gpu_memory_usage(
    context: &mut FfxFsr2Context,
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

/// `ffxFsr2ContextDestroy`. A context that was never created is the SDK's
/// `NULL` context.
pub fn ffx_fsr2_context_destroy(context: &mut FfxFsr2Context) -> Result<(), FfxErrorCode> {
    let Some(context_private) = context.private.as_deref_mut() else {
        return Err(FFX_ERROR_INVALID_POINTER);
    };

    // destroy the context.
    fsr2_release(context_private)
}

/// `ffxFsr2ContextDispatch`. A context that was never created is the SDK's
/// `NULL` context.
pub fn ffx_fsr2_context_dispatch(
    context: &mut FfxFsr2Context,
    dispatch_params: &FfxFsr2DispatchDescription,
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
    ffx_return_on_error!(context_private.device != 0, FFX_ERROR_NULL_DEVICE);

    // dispatch the FSR2 passes.
    fsr2_dispatch(context_private, dispatch_params)
}

/// `ffxFsr2GetUpscaleRatioFromQualityMode`.
pub fn ffx_fsr2_get_upscale_ratio_from_quality_mode(quality_mode: FfxFsr2QualityMode) -> f32 {
    match quality_mode {
        FfxFsr2QualityMode::Quality => 1.5,
        FfxFsr2QualityMode::Balanced => 1.7,
        FfxFsr2QualityMode::Performance => 2.0,
        FfxFsr2QualityMode::UltraPerformance => 3.0,
    }
}

/// `ffxFsr2GetRenderResolutionFromQualityMode`; returns the render width and
/// height. The quality mode range check holds for every `FfxFsr2QualityMode`.
pub fn ffx_fsr2_get_render_resolution_from_quality_mode(
    display_width: u32,
    display_height: u32,
    quality_mode: FfxFsr2QualityMode,
) -> Result<(u32, u32), FfxErrorCode> {
    ffx_return_on_error!(
        FfxFsr2QualityMode::Quality as u32 <= quality_mode as u32
            && quality_mode as u32 <= FfxFsr2QualityMode::UltraPerformance as u32,
        FFX_ERROR_INVALID_ENUM
    );

    // scale by the predefined ratios in each dimension.
    let ratio = ffx_fsr2_get_upscale_ratio_from_quality_mode(quality_mode);
    let scaled_display_width = (display_width as f32 / ratio) as u32;
    let scaled_display_height = (display_height as f32 / ratio) as u32;

    Ok((scaled_display_width, scaled_display_height))
}

/// `ffxFsr2GetJitterPhaseCount`.
pub fn ffx_fsr2_get_jitter_phase_count(render_width: i32, display_width: i32) -> i32 {
    let base_phase_count = 8.0f32;
    (base_phase_count * (display_width as f32 / render_width as f32).powf(2.0)) as i32
}

/// `ffxFsr2GetJitterOffset`; returns the x and y offsets.
pub fn ffx_fsr2_get_jitter_offset(
    index: i32,
    phase_count: i32,
) -> Result<(f32, f32), FfxErrorCode> {
    ffx_return_on_error!(phase_count > 0, FFX_ERROR_INVALID_ARGUMENT);

    let x = halton((index % phase_count) + 1, 2) - 0.5;
    let y = halton((index % phase_count) + 1, 3) - 0.5;

    Ok((x, y))
}

/// `ffxFsr2ResourceIsNull`.
pub fn ffx_fsr2_resource_is_null(resource: &FfxResource) -> bool {
    resource.resource == 0
}

/// `ffxFsr2ContextGenerateReactiveMask`. A context that was never created is
/// the SDK's `NULL` context. As in the SDK, the job is built but not scheduled.
pub fn ffx_fsr2_context_generate_reactive_mask(
    context: &mut FfxFsr2Context,
    params: &FfxFsr2GenerateReactiveDescription,
) -> Result<(), FfxErrorCode> {
    let Some(context_private) = context.private.as_deref_mut() else {
        return Err(FFX_ERROR_INVALID_POINTER);
    };
    ffx_return_on_error!(params.command_list != 0, FFX_ERROR_INVALID_POINTER);

    ffx_return_on_error!(context_private.device != 0, FFX_ERROR_NULL_DEVICE);

    let backend = context_private
        .context_description
        .backend_interface
        .clone();
    let effect_context_id = context_private.effect_context_id;

    // take a short cut to the command list
    let command_list = params.command_list;

    let pipeline = context_private.pipeline_generate_reactive.clone();

    let thread_group_work_region_dim: i32 = 8;
    let dispatch_src_x = params
        .render_size
        .width
        .wrapping_add((thread_group_work_region_dim - 1) as u32)
        / thread_group_work_region_dim as u32;
    let dispatch_src_y = params
        .render_size
        .height
        .wrapping_add((thread_group_work_region_dim - 1) as u32)
        / thread_group_work_region_dim as u32;

    // save internal reactive resource
    let internal_reactive =
        context_private.uav_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize];

    // The SDK's fixed-size job arrays; it writes slot 0 of each.
    let mut job_descriptor = FfxComputeJobDescription {
        srv_textures: vec![FfxTextureSRV::default(); pipeline.srv_texture_bindings.len()],
        uav_textures: vec![FfxTextureUAV::default(); pipeline.uav_texture_bindings.len().max(1)],
        cbs: vec![FfxConstantBuffer::default(); pipeline.constant_buffer_bindings.len().max(1)],
        ..Default::default()
    };
    register_resource(
        &backend,
        &params.color_opaque_only,
        effect_context_id,
        &mut context_private.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY as usize],
    );
    register_resource(
        &backend,
        &params.color_pre_upscale,
        effect_context_id,
        &mut context_private.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_COLOR as usize],
    );
    register_resource(
        &backend,
        &params.out_reactive,
        effect_context_id,
        &mut context_private.uav_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize],
    );

    job_descriptor.uav_textures[0].resource =
        context_private.uav_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize];

    job_descriptor.dimensions = [dispatch_src_x, dispatch_src_y, 1];
    job_descriptor.pipeline = pipeline.clone();

    for (current_shader_resource_view_index, binding) in
        pipeline.srv_texture_bindings.iter().enumerate()
    {
        let current_resource_id = binding.resource_identifier;
        let current_resource = context_private.srv_resources[current_resource_id as usize];
        job_descriptor.srv_textures[current_shader_resource_view_index].resource = current_resource;
    }

    let constants = Fsr2GenerateReactiveConstants {
        scale: params.scale,
        threshold: params.cutoff_threshold,
        binary_value: params.binary_value,
        flags: params.flags,
    };

    let _ = backend
        .borrow_mut()
        .stage_constant_buffer_data_func(&constants.words(), &mut job_descriptor.cbs[0]);
    let _dispatch_job = FfxGpuJobDescription {
        job_label: pipeline.name.clone(),
        descriptor: FfxGpuJobDescriptor::Compute(Box::new(job_descriptor)),
    };

    //contextPrivate->contextDescription.backendInterface.fpScheduleGpuJob(&contextPrivate->contextDescription.backendInterface, &dispatchJob);

    let _ = backend
        .borrow_mut()
        .execute_gpu_jobs(command_list, effect_context_id);

    // restore internal reactive
    context_private.uav_resources[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize] =
        internal_reactive;

    // release dynamic resources
    let _ = backend
        .borrow_mut()
        .unregister_resources(command_list, effect_context_id);

    Ok(())
}

/// `generateReactiveMaskInternal`.
fn generate_reactive_mask_internal(
    context_private: &mut FfxFsr2ContextPrivate,
    params: &FfxFsr2DispatchDescription,
) -> Result<(), FfxErrorCode> {
    let backend = context_private
        .context_description
        .backend_interface
        .clone();
    let effect_context_id = context_private.effect_context_id;
    let pipeline = context_private.pipeline_tcr_autogenerate.clone();

    let thread_group_work_region_dim: i32 = 8;
    let dispatch_src_x = params
        .render_size
        .width
        .wrapping_add((thread_group_work_region_dim - 1) as u32)
        / thread_group_work_region_dim as u32;
    let dispatch_src_y = params
        .render_size
        .height
        .wrapping_add((thread_group_work_region_dim - 1) as u32)
        / thread_group_work_region_dim as u32;

    // The SDK's fixed-size job arrays; it writes UAV slots 0 to 3.
    let mut job_descriptor = FfxComputeJobDescription {
        srv_textures: vec![FfxTextureSRV::default(); pipeline.srv_texture_bindings.len()],
        uav_textures: vec![FfxTextureUAV::default(); pipeline.uav_texture_bindings.len().max(4)],
        cbs: vec![FfxConstantBuffer::default(); pipeline.constant_buffer_bindings.len()],
        ..Default::default()
    };
    register_resource(
        &backend,
        &params.color_opaque_only,
        effect_context_id,
        &mut context_private.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_OPAQUE_ONLY as usize],
    );
    register_resource(
        &backend,
        &params.color,
        effect_context_id,
        &mut context_private.srv_resources[FFX_FSR2_RESOURCE_IDENTIFIER_INPUT_COLOR as usize],
    );

    let uav = &context_private.uav_resources;
    job_descriptor.uav_textures[0].resource =
        uav[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOREACTIVE as usize];
    job_descriptor.uav_textures[1].resource =
        uav[FFX_FSR2_RESOURCE_IDENTIFIER_AUTOCOMPOSITION as usize];
    job_descriptor.uav_textures[2].resource =
        uav[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR as usize];
    job_descriptor.uav_textures[3].resource =
        uav[FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR as usize];

    job_descriptor.dimensions = [dispatch_src_x, dispatch_src_y, 1];
    job_descriptor.pipeline = pipeline.clone();

    for (current_shader_resource_view_index, binding) in
        pipeline.srv_texture_bindings.iter().enumerate()
    {
        let current_resource_id = binding.resource_identifier;
        let current_resource = context_private.srv_resources[current_resource_id as usize];
        job_descriptor.srv_textures[current_shader_resource_view_index].resource = current_resource;
    }

    for (current_root_constant_index, binding) in
        pipeline.constant_buffer_bindings.iter().enumerate()
    {
        job_descriptor.cbs[current_root_constant_index] =
            context_private.constant_buffers[binding.resource_identifier as usize].clone();
    }

    let dispatch_job = FfxGpuJobDescription {
        job_label: pipeline.name.clone(),
        descriptor: FfxGpuJobDescriptor::Compute(Box::new(job_descriptor)),
    };

    let _ = backend.borrow_mut().schedule_gpu_job(&dispatch_job);

    Ok(())
}

/// `ffxFsr2GetEffectVersion`.
pub fn ffx_fsr2_get_effect_version() -> FfxVersionNumber {
    ffx_sdk_make_version(
        FFX_FSR2_VERSION_MAJOR,
        FFX_FSR2_VERSION_MINOR,
        FFX_FSR2_VERSION_PATCH,
    )
}

/// `ffxFsr2SetGlobalDebugMessage`.
pub fn ffx_fsr2_set_global_debug_message(
    fp_message: Option<FfxMessageCallback>,
    debug_level: u32,
) -> Result<(), FfxErrorCode> {
    ffx_set_print_message_callback(fp_message, debug_level);
    Ok(())
}
