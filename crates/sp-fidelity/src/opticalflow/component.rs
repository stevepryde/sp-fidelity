//! Port of the FidelityFX SDK 1.1.4 host component.
use super::private::*;
use super::resources::*;
use super::*;
use crate::error::*;
use crate::gpu::spd::ffx_spd_setup_mips;
use crate::interface::ffx_sdk_make_version;
use crate::object_management::*;
const SRV: &[(u32, &str)] = &[
    (FFX_OF_BINDING_IDENTIFIER_INPUT_COLOR, "r_input_color"),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT,
        "r_optical_flow_input",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS_INPUT,
        "r_optical_flow_previous_input",
    ),
    (FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW, "r_optical_flow"),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS,
        "r_optical_flow_previous",
    ),
];
const UAV: &[(u32, &str)] = &[
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT,
        "rw_optical_flow_input",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_1,
        "rw_optical_flow_input_level_1",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_2,
        "rw_optical_flow_input_level_2",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_3,
        "rw_optical_flow_input_level_3",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_4,
        "rw_optical_flow_input_level_4",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_5,
        "rw_optical_flow_input_level_5",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT_LEVEL_6,
        "rw_optical_flow_input_level_6",
    ),
    (FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW, "rw_optical_flow"),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_NEXT_LEVEL,
        "rw_optical_flow_next_level",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_HISTOGRAM,
        "rw_optical_flow_scd_histogram",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_PREVIOUS_HISTOGRAM,
        "rw_optical_flow_scd_previous_histogram",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_TEMP,
        "rw_optical_flow_scd_temp",
    ),
    (
        FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_OUTPUT,
        "rw_optical_flow_scd_output",
    ),
];
const CB: &[(u32, &str)] = &[
    (FFX_OPTICALFLOW_CONSTANTBUFFER_IDENTIFIER, "cbOF"),
    (FFX_OPTICALFLOW_CONSTANTBUFFER_IDENTIFIER_SPD, "cbOF_SPD"),
];
fn patch(pipeline: &mut FfxPipelineState) -> Result<(), FfxErrorCode> {
    for (bindings, table) in [
        (&mut pipeline.srv_texture_bindings, SRV),
        (&mut pipeline.uav_texture_bindings, UAV),
        (&mut pipeline.constant_buffer_bindings, CB),
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

fn create_pipeline_states(context: &mut FfxOpticalflowContextPrivate) -> Result<(), FfxErrorCode> {
    let backend = context.context_description.backend_interface.clone();
    let mut backend = backend.borrow_mut();
    let capabilities = backend.get_device_capabilities().unwrap_or_default();
    let force64 = capabilities.wave_lane_count_min == 32
        && capabilities.wave_lane_count_max == 64
        && capabilities.maximum_supported_shader_model >= FfxShaderModel::ShaderModel6_6;
    let permutation = if force64 {
        OPTICALFLOW_SHADER_PERMUTATION_FORCE_WAVE64
    } else {
        0
    } | if capabilities.fp16_supported {
        OPTICALFLOW_SHADER_PERMUTATION_ALLOW_FP16
    } else {
        0
    };
    let samplers = [
        sampler(FfxFilterType::MinMagMipPoint),
        sampler(FfxFilterType::MinMagMipLinear),
    ];
    let constants = [
        FfxRootConstantDescription {
            size: OpticalflowConstants::WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
        FfxRootConstantDescription {
            size: 8,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];
    for (pass, name, pipeline, count) in [
        (
            FfxOpticalflowPass::GenerateOpticalFlowInputPyramid,
            "Opticalflow_InputPyramid",
            &mut context.pipeline_generate_optical_flow_input_pyramid,
            2,
        ),
        (
            FfxOpticalflowPass::PrepareLuma,
            "Opticalflow_Luma",
            &mut context.pipeline_prepare_luma,
            1,
        ),
        (
            FfxOpticalflowPass::GenerateScdHistogram,
            "Opticalflow_SCD_Histogram",
            &mut context.pipeline_generate_scd_histogram,
            1,
        ),
        (
            FfxOpticalflowPass::ComputeScdDivergence,
            "Opticalflow_SCD_Divergence",
            &mut context.pipeline_compute_scd_divergence,
            1,
        ),
        (
            FfxOpticalflowPass::ComputeOpticalFlowAdvancedV5,
            "Opticalflow_Search",
            &mut context.pipeline_compute_optical_flow_advanced_v5,
            1,
        ),
        (
            FfxOpticalflowPass::FilterOpticalFlowV5,
            "Opticalflow_Filter",
            &mut context.pipeline_filter_optical_flow_v5,
            1,
        ),
        (
            FfxOpticalflowPass::ScaleOpticalFlowAdvancedV5,
            "Opticalflow_Upscale",
            &mut context.pipeline_scale_optical_flow_advanced_v5,
            1,
        ),
    ] {
        ffx_safe_release_pipeline(&mut *backend, pipeline, context.effect_context_id);
        let description = FfxPipelineDescription {
            context_flags: context.context_description.flags,
            samplers: &samplers,
            root_constants: &constants[..count],
            name: name.into(),
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
            indirect_workload: 0,
            backbuffer_format: FfxSurfaceFormat::Unknown,
        };
        // The SDK ignores the helper's error at every call site.
        if let Ok(created) = backend.create_pipeline(
            FfxEffect::OpticalFlow,
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

pub fn ffx_opticalflow_context_create(
    context: &mut FfxOpticalflowContext,
    description: &FfxOpticalflowContextDescription,
) -> Result<(), FfxErrorCode> {
    let mut private = Box::new(FfxOpticalflowContextPrivate::zeroed(description.clone()));
    let backend = description.backend_interface.clone();
    let result = (|| {
        let mut backend = backend.borrow_mut();
        private.device = backend.device();
        if backend.get_sdk_version() != ffx_sdk_make_version(1, 1, 4) {
            return Err(FFX_ERROR_INVALID_VERSION);
        }
        private.effect_context_id = backend.create_backend_context(FfxEffect::OpticalFlow, None)?;
        private.device_capabilities = backend.get_device_capabilities()?;
        private.first_execution = true;
        private.constants.input_luma_resolution = [
            description.resolution.width as i32,
            description.resolution.height as i32,
        ];
        let mut flow_sizes = [FfxDimensions2D::default(); 7];
        flow_sizes[0] = FfxDimensions2D {
            width: description.resolution.width.div_ceil(8),
            height: description.resolution.height.div_ceil(8),
        };
        for i in 1..7 {
            flow_sizes[i] = FfxDimensions2D {
                width: flow_sizes[i - 1].width.div_ceil(2),
                height: flow_sizes[i - 1].height.div_ceil(2),
            }
        }
        for (base, format, input) in [
            (1, FfxSurfaceFormat::R8Uint, true),
            (8, FfxSurfaceFormat::R8Uint, true),
            (15, FfxSurfaceFormat::R16G16Sint, false),
            (22, FfxSurfaceFormat::R16G16Sint, false),
        ] {
            for (level, flow_size) in flow_sizes.iter().enumerate() {
                let (width, height) = if input {
                    (
                        description.resolution.width >> level,
                        description.resolution.height >> level,
                    )
                } else {
                    (flow_size.width, flow_size.height)
                };
                // Resource names are static in the SDK; select their equivalent literals below.
                let name = INTERNAL_NAMES[base + level];
                let mut rd = resource_description(format, width, height, FFX_RESOURCE_USAGE_UAV);
                if height <= 1 && description.flags & FFX_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE != 0 {
                    rd.r#type = FfxResourceType::Texture1D;
                }
                let create = FfxCreateResourceDescription {
                    heap_type: FfxHeapType::Default,
                    resource_description: rd,
                    initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                    name,
                    id: (base + level) as u32,
                    init_data: uninitialized(),
                };
                private.resources[base + level] =
                    backend.create_resource(&create, private.effect_context_id)?;
            }
        }
        for (id, width, format) in [
            (29, 2304, FfxSurfaceFormat::R32Uint),
            (30, 2304, FfxSurfaceFormat::R32Float),
            (31, 3, FfxSurfaceFormat::R32Uint),
        ] {
            let mut rd = resource_description(format, width, 1, FFX_RESOURCE_USAGE_UAV);
            if description.flags & FFX_OPTICALFLOW_ENABLE_TEXTURE1D_USAGE != 0 {
                rd.r#type = FfxResourceType::Texture1D;
            }
            private.resources[id] = backend.create_resource(
                &FfxCreateResourceDescription {
                    heap_type: FfxHeapType::Default,
                    resource_description: rd,
                    initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                    name: INTERNAL_NAMES[id],
                    id: id as u32,
                    init_data: uninitialized(),
                },
                private.effect_context_id,
            )?;
        }
        drop(backend);
        create_pipeline_states(&mut private)
    })();
    context.private = Some(private);
    result
}

pub fn ffx_opticalflow_context_destroy(
    context: &mut FfxOpticalflowContext,
) -> Result<(), FfxErrorCode> {
    let mut private = context.private.take().ok_or(FFX_ERROR_INVALID_POINTER)?;
    let mut backend = private.context_description.backend_interface.borrow_mut();
    for pipeline in [
        &mut private.pipeline_prepare_luma,
        &mut private.pipeline_generate_optical_flow_input_pyramid,
        &mut private.pipeline_generate_scd_histogram,
        &mut private.pipeline_compute_scd_divergence,
        &mut private.pipeline_compute_optical_flow_advanced_v5,
        &mut private.pipeline_filter_optical_flow_v5,
        &mut private.pipeline_scale_optical_flow_advanced_v5,
    ] {
        ffx_safe_release_pipeline(&mut *backend, pipeline, private.effect_context_id);
    }
    for resource in private.resources {
        ffx_safe_release_resource(&mut *backend, resource, private.effect_context_id);
    }
    let _ = backend.destroy_backend_context(private.effect_context_id);
    Ok(())
}

pub fn ffx_opticalflow_context_get_gpu_memory_usage(
    context: &FfxOpticalflowContext,
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

pub fn ffx_opticalflow_get_shared_resource_descriptions(
    context: &FfxOpticalflowContext,
) -> Result<FfxOpticalflowSharedResourceDescriptions<'static>, FfxErrorCode> {
    let context = context.private.as_ref().ok_or(FFX_ERROR_INVALID_POINTER)?;
    let resolution = context.context_description.resolution;
    Ok(FfxOpticalflowSharedResourceDescriptions {
        optical_flow_vector: FfxCreateResourceDescription {
            heap_type: FfxHeapType::Default,
            resource_description: resource_description(
                FfxSurfaceFormat::R16G16Sint,
                resolution.width.div_ceil(8),
                resolution.height.div_ceil(8),
                FFX_RESOURCE_USAGE_UAV,
            ),
            initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            name: "OPTICALFLOW_Result",
            id: 0,
            init_data: uninitialized(),
        },
        optical_flow_scd: FfxCreateResourceDescription {
            heap_type: FfxHeapType::Default,
            resource_description: resource_description(
                FfxSurfaceFormat::R32Uint,
                3,
                1,
                FFX_RESOURCE_USAGE_UAV,
            ),
            initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
            name: "OPTICALFLOW_SCDOutput",
            id: 0,
            init_data: uninitialized(),
        },
    })
}

pub fn ffx_opticalflow_resource_is_null(resource: &FfxResource) -> bool {
    resource.resource == 0
}
pub fn ffx_opticalflow_get_effect_version() -> FfxVersionNumber {
    ffx_sdk_make_version(
        FFX_OPTICALFLOW_VERSION_MAJOR,
        FFX_OPTICALFLOW_VERSION_MINOR,
        FFX_OPTICALFLOW_VERSION_PATCH,
    )
}

fn schedule(
    context: &FfxOpticalflowContextPrivate,
    pipeline: &FfxPipelineState,
    name: &str,
    x: u32,
    y: u32,
    z: u32,
) {
    let job = FfxComputeJobDescription {
        pipeline: pipeline.clone(),
        dimensions: [x, y, z],
        srv_textures: pipeline
            .srv_texture_bindings
            .iter()
            .map(|b| FfxTextureSRV {
                resource: context.srv_bindings[b.resource_identifier as usize],
            })
            .collect(),
        uav_textures: pipeline
            .uav_texture_bindings
            .iter()
            .map(|b| FfxTextureUAV {
                resource: context.uav_bindings[b.resource_identifier as usize],
                mip: 0,
            })
            .collect(),
        cbs: pipeline
            .constant_buffer_bindings
            .iter()
            .map(|b| context.constant_buffers[b.resource_identifier as usize].clone())
            .collect(),
        ..Default::default()
    };
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: name.into(),
            descriptor: FfxGpuJobDescriptor::Compute(Box::new(job)),
        });
}
fn clear(context: &FfxOpticalflowContextPrivate, resource: FfxResourceInternal, name: &str) {
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: name.into(),
            descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                target: resource,
                color: [0.0; 4],
            }),
        });
}
fn barrier(context: &FfxOpticalflowContextPrivate, resource: FfxResourceInternal, name: &str) {
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: name.into(),
            descriptor: FfxGpuJobDescriptor::Barrier(FfxBarrierDescription {
                resource,
                barrier_type: FfxBarrierType::Transition,
                current_state: FFX_RESOURCE_STATE_COMPUTE_READ,
                new_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                sub_resource_id: 0,
            }),
        });
}
fn stage(context: &mut FfxOpticalflowContextPrivate) {
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .stage_constant_buffer_data_func(
            &context.constants.words(),
            &mut context.constant_buffers[0],
        );
}
fn register(
    context: &mut FfxOpticalflowContextPrivate,
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
            context.uav_bindings[index as usize] = resource;
        } else {
            context.srv_bindings[index as usize] = resource;
        }
    }
}

pub fn ffx_opticalflow_context_dispatch(
    context: &mut FfxOpticalflowContext,
    params: &FfxOpticalflowDispatchDescription,
) -> Result<(), FfxErrorCode> {
    if params.command_list == 0
        || params.color.resource == 0
        || params.optical_flow_vector.resource == 0
        || params.optical_flow_scd.resource == 0
    {
        return Err(FFX_ERROR_INVALID_POINTER);
    }
    if params.color.description.r#type != FfxResourceType::Texture2D {
        return Err(FFX_ERROR_INVALID_ARGUMENT);
    }
    let context = context.private.as_mut().ok_or(FFX_ERROR_INVALID_POINTER)?;
    if context.device == 0 {
        return Err(FFX_ERROR_NULL_DEVICE);
    }
    let resolution = context.context_description.resolution;
    if params.color.description.width > resolution.width
        || params.color.description.height > resolution.height
    {
        return Err(FFX_ERROR_INVALID_ARGUMENT);
    }
    register(
        context,
        &params.optical_flow_vector,
        FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_VECTOR,
        true,
    );
    register(
        context,
        &params.optical_flow_scd,
        FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_SCD_OUTPUT,
        true,
    );
    register(
        context,
        &params.color,
        FFX_OF_BINDING_IDENTIFIER_INPUT_COLOR,
        false,
    );
    if context.refresh_pipeline_states {
        context.refresh_pipeline_states = false;
        create_pipeline_states(context)?;
    }
    let input_description = context
        .context_description
        .backend_interface
        .borrow_mut()
        .get_resource_description(
            context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_INPUT_COLOR as usize],
        );
    crate::assert::ffx_assert!(input_description.r#type == FfxResourceType::Texture2D);
    context.constants.backbuffer_transfer_function = params.backbuffer_transfer_function as u32;
    context.constants.min_max_luminance = [params.min_max_luminance.x, params.min_max_luminance.y];
    let reset = params.reset || context.first_execution;
    context.first_execution = false;
    context.constants.frame_index = if reset {
        0
    } else {
        context.constants.frame_index.wrapping_add(1)
    };
    if reset {
        for (id, name) in [
            (31, "Clear Optical Flow SCD Temp"),
            (29, "Clear Optical Flow SCD Histogram"),
            (30, "Clear Optical Flow SCD Previous histogram"),
        ] {
            clear(context, context.resources[id], name);
            if id == 31 {
                clear(
                    context,
                    context.uav_bindings
                        [FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_SCD_OUTPUT as usize],
                    name,
                );
            }
        }
        for id in 1..15 {
            let name = if id == 1 {
                "Clear Optical Flow Input 1".into()
            } else if id == 8 {
                "Clear Optical Flow Input 2".into()
            } else {
                format!(
                    "Clear Optical Flow Input {} Level {}",
                    if id < 8 { 1 } else { 2 },
                    if id < 8 { id - 1 } else { id - 8 }
                )
            };
            clear(context, context.resources[id], &name);
        }
    }
    let mut groups = [0; 2];
    let mut offset = [0; 2];
    let mut num = [0; 2];
    ffx_spd_setup_mips(
        &mut groups,
        &mut offset,
        &mut num,
        [0, 0, resolution.width, resolution.height],
        4,
    );
    stage(context);
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .stage_constant_buffer_data_func(
            &[num[1], num[0], offset[0], offset[1], num[0], 0, 0, 0],
            &mut context.constant_buffers[1],
        );
    for (b, r) in [
        (FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_HISTOGRAM, 29),
        (
            FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_PREVIOUS_HISTOGRAM,
            30,
        ),
        (FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_TEMP, 31),
    ] {
        context.uav_bindings[b as usize] = context.resources[r];
    }
    context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_SCD_OUTPUT as usize] =
        context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_SCD_OUTPUT as usize];
    let odd = context.resource_frame_index & 1 != 0;
    let input_a = if odd { 8 } else { 1 };
    let input_b = if odd { 1 } else { 8 };
    let flow_a = if odd { 22 } else { 15 };
    let flow_b = if odd { 15 } else { 22 };
    for level in 0..7 {
        context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT as usize + level] =
            context.resources[input_a + level];
    }
    context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT as usize] =
        context.resources[input_a];
    context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS_INPUT as usize] =
        context.resources[input_b];
    context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize] =
        context.resources[flow_a];
    context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize] =
        context.resources[flow_a];
    context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS as usize] =
        context.resources[flow_b];
    schedule(
        context,
        &context.pipeline_prepare_luma,
        "OF PrepareLuma",
        resolution.width.div_ceil(2).div_ceil(16),
        resolution.height.div_ceil(2).div_ceil(16),
        1,
    );
    schedule(
        context,
        &context.pipeline_generate_optical_flow_input_pyramid,
        "OF GenerateOpticalFlowInputPyramid",
        groups[0],
        groups[1],
        1,
    );
    schedule(
        context,
        &context.pipeline_generate_scd_histogram,
        "OF GenerateSCDHistogram",
        (resolution.width / 4 / 3).div_ceil(32),
        16,
        9,
    );
    schedule(
        context,
        &context.pipeline_compute_scd_divergence,
        "OF ComputeSCDDivergence",
        9,
        3,
        1,
    );
    let mut sizes = [FfxDimensions2D::default(); 7];
    sizes[0] = FfxDimensions2D {
        width: resolution.width.div_ceil(8),
        height: resolution.height.div_ceil(8),
    };
    for level in 1..7 {
        sizes[level] = FfxDimensions2D {
            width: sizes[level - 1].width.div_ceil(2),
            height: sizes[level - 1].height.div_ceil(2),
        };
    }
    for level in (0..7).rev() {
        let (a, b) = if odd != (level & 1 != 0) {
            (22, 15)
        } else {
            (15, 22)
        };
        context.constants.optical_flow_pyramid_level = level as u32;
        context.constants.optical_flow_pyramid_level_count = 7;
        stage(context);
        context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_INPUT as usize] =
            context.resources[input_a + level];
        context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS_INPUT as usize] =
            context.resources[input_b + level];
        context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize] =
            context.resources[a + level];
        context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS as usize] =
            context.resources[b + level];
        let w = (resolution.width >> level).max(1);
        let h = (resolution.height >> level).max(1);
        schedule(
            context,
            &context.pipeline_compute_optical_flow_advanced_v5,
            &format!("OF {level} Search"),
            (w.div_ceil(4) * 16).div_ceil(64),
            h.div_ceil(16),
            1,
        );
        context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS as usize] =
            context.resources[a + level];
        context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize] = if level == 0 {
            context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_SHARED_OPTICAL_FLOW_VECTOR as usize]
        } else {
            context.resources[b + level]
        };
        schedule(
            context,
            &context.pipeline_filter_optical_flow_v5,
            &format!("OF {level} Filter"),
            sizes[level].width.div_ceil(16),
            sizes[level].height.div_ceil(4),
            1,
        );
        if level > 0 {
            context.srv_bindings
                [FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_ALIAS_LEVEL_1 as usize + level - 1] =
                context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize];
            context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize] =
                context.resources[b + level];
            context.uav_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_NEXT_LEVEL as usize] =
                context.resources[b + level - 1];
            schedule(
                context,
                &context.pipeline_scale_optical_flow_advanced_v5,
                &format!("OF {level} Scale"),
                sizes[level - 1].width.div_ceil(4),
                sizes[level - 1].height.div_ceil(4),
                1,
            );
            barrier(
                context,
                context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW as usize],
                "",
            );
        }
        barrier(
            context,
            context.srv_bindings[FFX_OF_BINDING_IDENTIFIER_OPTICAL_FLOW_PREVIOUS as usize],
            "",
        );
    }
    for id in 1..15 {
        let name = if id == 1 {
            "Transition Optical Flow Input 1".into()
        } else if id == 8 {
            "Transition Optical Flow Input 2".into()
        } else {
            format!(
                "Transition Optical Flow Input {} Level {}",
                if id < 8 { 1 } else { 2 },
                if id < 8 { id - 1 } else { id - 8 }
            )
        };
        barrier(context, context.resources[id], &name);
    }
    context.resource_frame_index = (context.resource_frame_index + 1) % 16;
    context
        .context_description
        .backend_interface
        .borrow_mut()
        .execute_gpu_jobs(params.command_list, context.effect_context_id)?;
    let _ = context
        .context_description
        .backend_interface
        .borrow_mut()
        .unregister_resources(params.command_list, context.effect_context_id);
    Ok(())
}

const INTERNAL_NAMES: &[&str] = &[
    "",
    "OPTICALFLOW_OpticalFlowInput1",
    "OPTICALFLOW_OpticalFlowInput1Level1",
    "OPTICALFLOW_OpticalFlowInput1Level2",
    "OPTICALFLOW_OpticalFlowInput1Level3",
    "OPTICALFLOW_OpticalFlowInput1Level4",
    "OPTICALFLOW_OpticalFlowInput1Level5",
    "OPTICALFLOW_OpticalFlowInput1Level6",
    "OPTICALFLOW_OpticalFlowInput2",
    "OPTICALFLOW_OpticalFlowInput2Level1",
    "OPTICALFLOW_OpticalFlowInput2Level2",
    "OPTICALFLOW_OpticalFlowInput2Level3",
    "OPTICALFLOW_OpticalFlowInput2Level4",
    "OPTICALFLOW_OpticalFlowInput2Level5",
    "OPTICALFLOW_OpticalFlowInput2Level6",
    "OPTICALFLOW_OpticalFlow1",
    "OPTICALFLOW_OpticalFlow1Level1",
    "OPTICALFLOW_OpticalFlow1Level2",
    "OPTICALFLOW_OpticalFlow1Level3",
    "OPTICALFLOW_OpticalFlow1Level4",
    "OPTICALFLOW_OpticalFlow1Level5",
    "OPTICALFLOW_OpticalFlow1Level6",
    "OPTICALFLOW_OpticalFlow2",
    "OPTICALFLOW_OpticalFlow2Level1",
    "OPTICALFLOW_OpticalFlow2Level2",
    "OPTICALFLOW_OpticalFlow2Level3",
    "OPTICALFLOW_OpticalFlow2Level4",
    "OPTICALFLOW_OpticalFlow2Level5",
    "OPTICALFLOW_OpticalFlow2Level6",
    "OPTICALFLOW_OpticalFlowSCDHistogram",
    "OPTICALFLOW_OpticalFlowSCDPreviousHistogram",
    "OPTICALFLOW_OpticalFlowSCDTemp",
];
