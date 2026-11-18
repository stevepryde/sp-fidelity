//! Reflection paths of `sdk/src/components/denoiser/ffx_denoiser.cpp` (SDK 1.1.4).
use super::private::*;
use super::resources::{
    FFX_DENOISER_RESOURCE_IDENTIFIER_AVERAGE_RADIANCE as AVERAGE_RADIANCE,
    FFX_DENOISER_RESOURCE_IDENTIFIER_AVERAGE_RADIANCE_0 as AVERAGE_RADIANCE_0,
    FFX_DENOISER_RESOURCE_IDENTIFIER_AVERAGE_RADIANCE_1 as AVERAGE_RADIANCE_1,
    FFX_DENOISER_RESOURCE_IDENTIFIER_DENOISER_TILE_LIST as DENOISER_TILE_LIST,
    FFX_DENOISER_RESOURCE_IDENTIFIER_DEPTH_HISTORY as DEPTH_HISTORY,
    FFX_DENOISER_RESOURCE_IDENTIFIER_EXTRACTED_ROUGHNESS as EXTRACTED_ROUGHNESS,
    FFX_DENOISER_RESOURCE_IDENTIFIER_INDIRECT_ARGS as INDIRECT_ARGS,
    FFX_DENOISER_RESOURCE_IDENTIFIER_INPUT_DEPTH_HIERARCHY as INPUT_DEPTH_HIERARCHY,
    FFX_DENOISER_RESOURCE_IDENTIFIER_INPUT_MOTION_VECTORS as INPUT_MOTION_VECTORS,
    FFX_DENOISER_RESOURCE_IDENTIFIER_INPUT_NORMAL as INPUT_NORMAL,
    FFX_DENOISER_RESOURCE_IDENTIFIER_NORMAL_HISTORY as NORMAL_HISTORY,
    FFX_DENOISER_RESOURCE_IDENTIFIER_OUTPUT as OUTPUT,
    FFX_DENOISER_RESOURCE_IDENTIFIER_RADIANCE as RADIANCE,
    FFX_DENOISER_RESOURCE_IDENTIFIER_RADIANCE_0 as RADIANCE_0,
    FFX_DENOISER_RESOURCE_IDENTIFIER_RADIANCE_1 as RADIANCE_1,
    FFX_DENOISER_RESOURCE_IDENTIFIER_RADIANCE_HISTORY as RADIANCE_HISTORY,
    FFX_DENOISER_RESOURCE_IDENTIFIER_REPROJECTED_RADIANCE as REPROJECTED_RADIANCE,
    FFX_DENOISER_RESOURCE_IDENTIFIER_ROUGHNESS_HISTORY as ROUGHNESS_HISTORY,
    FFX_DENOISER_RESOURCE_IDENTIFIER_SAMPLE_COUNT as SAMPLE_COUNT,
    FFX_DENOISER_RESOURCE_IDENTIFIER_SAMPLE_COUNT_0 as SAMPLE_COUNT_0,
    FFX_DENOISER_RESOURCE_IDENTIFIER_SAMPLE_COUNT_1 as SAMPLE_COUNT_1,
    FFX_DENOISER_RESOURCE_IDENTIFIER_VARIANCE as VARIANCE,
    FFX_DENOISER_RESOURCE_IDENTIFIER_VARIANCE_0 as VARIANCE_0,
    FFX_DENOISER_RESOURCE_IDENTIFIER_VARIANCE_1 as VARIANCE_1,
};
use super::*;
use crate::error::*;
use crate::interface::{FfxInterface, ffx_sdk_make_version};
use crate::object_management::{ffx_safe_release_pipeline, ffx_safe_release_resource};

const SRV_TEXTURES: &[(u32, &str)] = &[
    (INPUT_DEPTH_HIERARCHY, "r_input_depth_hierarchy"),
    (INPUT_MOTION_VECTORS, "r_input_motion_vectors"),
    (INPUT_NORMAL, "r_input_normal"),
    (RADIANCE, "r_radiance"),
    (RADIANCE_HISTORY, "r_radiance_history"),
    (VARIANCE, "r_variance"),
    (SAMPLE_COUNT, "r_sample_count"),
    (AVERAGE_RADIANCE, "r_average_radiance"),
    (EXTRACTED_ROUGHNESS, "r_extracted_roughness"),
    (DEPTH_HISTORY, "r_depth_history"),
    (NORMAL_HISTORY, "r_normal_history"),
    (ROUGHNESS_HISTORY, "r_roughness_history"),
    (REPROJECTED_RADIANCE, "r_reprojected_radiance"),
];
const UAV_TEXTURES: &[(u32, &str)] = &[
    (RADIANCE, "rw_radiance"),
    (VARIANCE, "rw_variance"),
    (SAMPLE_COUNT, "rw_sample_count"),
    (AVERAGE_RADIANCE, "rw_average_radiance"),
    (REPROJECTED_RADIANCE, "rw_reprojected_radiance"),
];
const UAV_BUFFERS: &[(u32, &str)] = &[
    (DENOISER_TILE_LIST, "rw_denoiser_tile_list"),
    (INDIRECT_ARGS, "rw_indirect_args"),
];
const CB: &[(u32, &str)] = &[(
    resources::FFX_DENOISER_REFLECTIONS_CONSTANTBUFFER_IDENTIFIER,
    "cbDenoiserReflections",
)];

// sizeof(DenoiserReflectionsConstants) / sizeof(uint32_t). The C++ bool and its
// three zero padding bytes occupy one word. Uniform binding padding is backend-owned.
const CONSTANT_WORDS: u32 = 59;

fn reflection_constants(
    params: &FfxDenoiserReflectionsDispatchDescription,
    size: FfxDimensions2D,
) -> Vec<u32> {
    let mut words = Vec::with_capacity(CONSTANT_WORDS as usize);
    words.extend(params.inv_projection.map(f32::to_bits));
    words.extend(params.inv_view.map(f32::to_bits));
    words.extend(params.prev_view_projection.map(f32::to_bits));
    words.extend([size.width, size.height]);
    words.extend(
        [
            1.0 / size.width as f32,
            1.0 / size.height as f32,
            params.motion_vector_scale.x,
            params.motion_vector_scale.y,
            params.normals_unpack_mul,
            params.normals_unpack_add,
        ]
        .map(f32::to_bits),
    );
    words.push(u32::from(params.is_roughness_perceptual));
    words.push(params.temporal_stability_factor.to_bits());
    words.push(params.roughness_threshold.to_bits());
    words
}

fn patch_resource_bindings(pipeline: &mut FfxPipelineState) -> Result<(), FfxErrorCode> {
    for (bindings, table) in [
        (&mut pipeline.srv_texture_bindings, SRV_TEXTURES),
        (&mut pipeline.uav_texture_bindings, UAV_TEXTURES),
        (&mut pipeline.uav_buffer_bindings, UAV_BUFFERS),
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

fn create_pipeline_states(
    backend: &mut dyn FfxInterface,
    private: &mut FfxDenoiserContextPrivate,
) -> Result<(), FfxErrorCode> {
    let capabilities = backend.get_device_capabilities()?;
    let force64 = capabilities.maximum_supported_shader_model >= FfxShaderModel::ShaderModel6_6
        && capabilities.wave_lane_count_min <= 64
        && capabilities.wave_lane_count_max >= 64;
    let samplers = [FfxSamplerDescription {
        filter: FfxFilterType::MinMagLinearMipPoint,
        address_mode_u: FfxAddressMode::Clamp,
        address_mode_v: FfxAddressMode::Clamp,
        address_mode_w: FfxAddressMode::Clamp,
        stage: FFX_BIND_COMPUTE_SHADER_STAGE,
    }];
    let constants = [FfxRootConstantDescription {
        size: CONSTANT_WORDS,
        stage: FFX_BIND_COMPUTE_SHADER_STAGE,
    }];
    for (pass, name, pipeline) in [
        (
            FfxDenoiserPass::ReprojectReflections,
            "DENOISER-REFLECTIONS_REPROJECT",
            &mut private.reproject,
        ),
        (
            FfxDenoiserPass::PrefilterReflections,
            "DENOISER-REFLECTIONS_PREFILTER",
            &mut private.prefilter,
        ),
        (
            FfxDenoiserPass::ResolveTemporalReflections,
            "DENOISER-REFLECTIONS_RESOLVE_TEMPORAL",
            &mut private.resolve_temporal,
        ),
    ] {
        // SDK 1.1.4 calls getPipelinePermutationFlags with the pass ID in the
        // contextFlags argument. Preserve its permutation keys on both depth conventions.
        let mut permutation = 0;
        if force64 {
            permutation |= DENOISER_SHADER_PERMUTATION_FORCE_WAVE64;
        }
        if capabilities.fp16_supported {
            permutation |= DENOISER_SHADER_PERMUTATION_ALLOW_FP16;
        }
        if pass as u32 & FFX_DENOISER_ENABLE_DEPTH_INVERTED != 0 {
            permutation |= DENOISER_SHADER_PERMUTATION_DEPTH_INVERTED;
        }
        *pipeline = backend.create_pipeline(
            FfxEffect::Denoiser,
            pass as u32,
            permutation,
            &FfxPipelineDescription {
                context_flags: 0,
                samplers: &samplers,
                root_constants: &constants,
                name: name.into(),
                stage: FFX_BIND_COMPUTE_SHADER_STAGE,
                indirect_workload: 1,
                backbuffer_format: FfxSurfaceFormat::Unknown,
            },
            private.effect_context_id,
        )?;
    }
    for pipeline in [
        &mut private.reproject,
        &mut private.prefilter,
        &mut private.resolve_temporal,
    ] {
        patch_resource_bindings(pipeline)?;
    }
    Ok(())
}

fn create_resources(
    backend: &mut dyn FfxInterface,
    private: &mut FfxDenoiserContextPrivate,
) -> Result<(), FfxErrorCode> {
    let size = private.description.window_size;
    let tiles = FfxDimensions2D {
        width: size.width.div_ceil(8),
        height: size.height.div_ceil(8),
    };
    use FfxSurfaceFormat::{R8Unorm, R11G11B10Float, R16Float, R16G16B16A16Float, R32Float};
    for (id, name, format, size, usage) in [
        (
            DEPTH_HISTORY,
            "DENOISER_DepthHistory",
            R32Float,
            size,
            FFX_RESOURCE_USAGE_READ_ONLY,
        ),
        (
            NORMAL_HISTORY,
            "DENOISER_NormalHistory",
            private.description.normals_history_buffer_format,
            size,
            FFX_RESOURCE_USAGE_READ_ONLY,
        ),
        (
            ROUGHNESS_HISTORY,
            "DENOISER_RoughnessHistory",
            R8Unorm,
            size,
            FFX_RESOURCE_USAGE_READ_ONLY,
        ),
        (
            SAMPLE_COUNT_0,
            "DENOISER_SampleCount0",
            R16Float,
            size,
            FFX_RESOURCE_USAGE_UAV,
        ),
        (
            SAMPLE_COUNT_1,
            "DENOISER_SampleCount1",
            R16Float,
            size,
            FFX_RESOURCE_USAGE_UAV,
        ),
        (
            AVERAGE_RADIANCE_0,
            "DENOISER_AverageRadiance0",
            R11G11B10Float,
            tiles,
            FFX_RESOURCE_USAGE_UAV,
        ),
        (
            AVERAGE_RADIANCE_1,
            "DENOISER_AverageRadiance1",
            R11G11B10Float,
            tiles,
            FFX_RESOURCE_USAGE_UAV,
        ),
        (
            REPROJECTED_RADIANCE,
            "DENOISER_ReprojectedRadiance",
            R16G16B16A16Float,
            size,
            FFX_RESOURCE_USAGE_UAV,
        ),
    ] {
        private.resources[id as usize] = backend.create_resource(
            &FfxCreateResourceDescription {
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
                initial_state: if usage == FFX_RESOURCE_USAGE_READ_ONLY {
                    FFX_RESOURCE_STATE_COMPUTE_READ
                } else {
                    FFX_RESOURCE_STATE_UNORDERED_ACCESS
                },
                name,
                id,
                init_data: FfxResourceInitData {
                    r#type: FfxResourceInitDataType::Uninitialized,
                    ..Default::default()
                },
            },
            private.effect_context_id,
        )?;
    }
    Ok(())
}

pub fn ffx_denoiser_get_effect_version() -> FfxVersionNumber {
    ffx_sdk_make_version(
        FFX_DENOISER_VERSION_MAJOR,
        FFX_DENOISER_VERSION_MINOR,
        FFX_DENOISER_VERSION_PATCH,
    )
}

pub fn ffx_denoiser_context_create(
    context: &mut FfxDenoiserContext,
    description: &FfxDenoiserContextDescription,
) -> Result<(), FfxErrorCode> {
    // This port implements the reflections mode of the SDK component.
    if context.private.is_some()
        || description.flags & FFX_DENOISER_REFLECTIONS == 0
        || description.flags & !(FFX_DENOISER_REFLECTIONS | FFX_DENOISER_ENABLE_DEPTH_INVERTED) != 0
    {
        return Err(FFX_ERROR_INVALID_ARGUMENT);
    }
    let mut backend = description.backend_interface.borrow_mut();
    let device = backend.device();
    if backend.get_sdk_version() != ffx_sdk_make_version(1, 1, 4) {
        return Err(FFX_ERROR_INVALID_VERSION);
    }
    let effect_context_id = backend.create_backend_context(FfxEffect::Denoiser, None)?;
    let mut private = Box::new(FfxDenoiserContextPrivate {
        description: description.clone(),
        device,
        effect_context_id,
        reproject: Default::default(),
        prefilter: Default::default(),
        resolve_temporal: Default::default(),
        resources: std::array::from_fn(|_| FfxResourceInternal::default()),
        constants: FfxConstantBuffer {
            num_32bit_entries: CONSTANT_WORDS,
            data: Vec::new(),
        },
        first_frame: true,
    });
    let initialize = (|| {
        backend.get_device_capabilities()?;
        create_resources(&mut *backend, &mut private)?;
        create_pipeline_states(&mut *backend, &mut private)
    })();
    if let Err(error) = initialize {
        let _ = release(&mut *backend, &mut private);
        return Err(error);
    }
    context.private = Some(private);
    Ok(())
}

fn release(
    backend: &mut dyn FfxInterface,
    private: &mut FfxDenoiserContextPrivate,
) -> Result<(), FfxErrorCode> {
    for pipeline in [
        &mut private.prefilter,
        &mut private.reproject,
        &mut private.resolve_temporal,
    ] {
        ffx_safe_release_pipeline(backend, pipeline, private.effect_context_id);
    }
    for resource in private.resources {
        ffx_safe_release_resource(backend, resource, private.effect_context_id);
    }
    backend.destroy_backend_context(private.effect_context_id)
}

pub fn ffx_denoiser_context_destroy(context: &mut FfxDenoiserContext) -> Result<(), FfxErrorCode> {
    let mut private = context.private.take().ok_or(FFX_ERROR_INVALID_POINTER)?;
    let backend = private.description.backend_interface.clone();
    release(&mut *backend.borrow_mut(), &mut private)
}

fn clear_zero(
    backend: &mut dyn FfxInterface,
    target: FfxResourceInternal,
) -> Result<(), FfxErrorCode> {
    backend.schedule_gpu_job(&FfxGpuJobDescription {
        job_label: "Zero initialize resource".into(),
        descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
            color: [0.0; 4],
            target,
        }),
    })
}

fn schedule_indirect(
    backend: &mut dyn FfxInterface,
    pipeline: &FfxPipelineState,
    srv: &ResourceTable,
    uav: &ResourceTable,
    constants: &FfxConstantBuffer,
) -> Result<(), FfxErrorCode> {
    let job = FfxComputeJobDescription {
        pipeline: pipeline.clone(),
        cmd_argument: uav[INDIRECT_ARGS as usize],
        cmd_argument_offset: 12,
        srv_textures: pipeline
            .srv_texture_bindings
            .iter()
            .map(|binding| FfxTextureSRV {
                resource: srv[binding.resource_identifier as usize],
            })
            .collect(),
        uav_textures: pipeline
            .uav_texture_bindings
            .iter()
            .map(|binding| {
                let resource = uav[binding.resource_identifier as usize];
                let mip_count = backend.get_resource_description(resource).mip_count;
                FfxTextureUAV {
                    resource,
                    mip: if binding.array_index < mip_count {
                        binding.array_index
                    } else {
                        0
                    },
                }
            })
            .collect(),
        uav_buffers: pipeline
            .uav_buffer_bindings
            .iter()
            .map(|binding| FfxBufferUAV {
                resource: uav[binding.resource_identifier as usize],
                ..Default::default()
            })
            .collect(),
        cbs: vec![constants.clone(); pipeline.constant_buffer_bindings.len()],
        ..Default::default()
    };
    backend.schedule_gpu_job(&FfxGpuJobDescription {
        job_label: pipeline.name.clone(),
        descriptor: FfxGpuJobDescriptor::Compute(Box::new(job)),
    })
}

fn dispatch_reflections(
    backend: &mut dyn FfxInterface,
    private: &mut FfxDenoiserContextPrivate,
    params: &FfxDenoiserReflectionsDispatchDescription,
) -> Result<(), FfxErrorCode> {
    // Only the owned resources persist across dispatches. Registered and aliased
    // handles live through execute/unregister and must never reach destruction.
    let mut srv = private.resources;
    let mut uav = private.resources;

    if private.first_frame {
        for id in [
            SAMPLE_COUNT_0,
            SAMPLE_COUNT_1,
            AVERAGE_RADIANCE_0,
            AVERAGE_RADIANCE_1,
            REPROJECTED_RADIANCE,
        ] {
            clear_zero(backend, uav[id as usize])?;
        }
    }

    for (id, resource) in [
        (INPUT_DEPTH_HIERARCHY, &params.depth_hierarchy),
        (INPUT_MOTION_VECTORS, &params.motion_vectors),
        (INPUT_NORMAL, &params.normal),
        (RADIANCE_0, &params.radiance_a),
        (RADIANCE_1, &params.radiance_b),
        (VARIANCE_0, &params.variance_a),
        (VARIANCE_1, &params.variance_b),
        (EXTRACTED_ROUGHNESS, &params.extracted_roughness),
        (DENOISER_TILE_LIST, &params.denoiser_tile_list),
        (INDIRECT_ARGS, &params.indirect_arguments_buffer),
        (OUTPUT, &params.output),
    ] {
        srv[id as usize] = backend.register_resource(resource, private.effect_context_id)?;
    }
    for id in [
        RADIANCE_0,
        RADIANCE_1,
        VARIANCE_0,
        VARIANCE_1,
        EXTRACTED_ROUGHNESS,
        DENOISER_TILE_LIST,
        INDIRECT_ARGS,
    ] {
        uav[id as usize] = srv[id as usize];
    }

    let (count_read, count_write, average_read, average_write) = if params.frame_index & 1 != 0 {
        (
            SAMPLE_COUNT_1,
            SAMPLE_COUNT_0,
            AVERAGE_RADIANCE_1,
            AVERAGE_RADIANCE_0,
        )
    } else {
        (
            SAMPLE_COUNT_0,
            SAMPLE_COUNT_1,
            AVERAGE_RADIANCE_0,
            AVERAGE_RADIANCE_1,
        )
    };

    srv[RADIANCE as usize] = srv[RADIANCE_0 as usize];
    srv[RADIANCE_HISTORY as usize] = srv[RADIANCE_1 as usize];
    srv[VARIANCE as usize] = srv[VARIANCE_1 as usize];
    srv[SAMPLE_COUNT as usize] = srv[count_read as usize];
    srv[AVERAGE_RADIANCE as usize] = srv[average_read as usize];

    uav[RADIANCE as usize] = uav[RADIANCE_1 as usize];
    uav[VARIANCE as usize] = uav[VARIANCE_0 as usize];
    uav[SAMPLE_COUNT as usize] = uav[count_write as usize];
    uav[AVERAGE_RADIANCE as usize] = uav[average_write as usize];

    if params.reset {
        for id in [AVERAGE_RADIANCE_0, AVERAGE_RADIANCE_1] {
            clear_zero(backend, uav[id as usize])?;
        }
    }

    let words = reflection_constants(params, private.description.window_size);
    backend.stage_constant_buffer_data_func(&words, &mut private.constants)?;
    schedule_indirect(backend, &private.reproject, &srv, &uav, &private.constants)?;

    srv[VARIANCE as usize] = srv[VARIANCE_0 as usize];
    uav[VARIANCE as usize] = uav[VARIANCE_1 as usize];
    schedule_indirect(backend, &private.prefilter, &srv, &uav, &private.constants)?;

    srv[RADIANCE as usize] = srv[RADIANCE_1 as usize];
    uav[RADIANCE as usize] = uav[RADIANCE_0 as usize];
    srv[VARIANCE as usize] = srv[VARIANCE_1 as usize];
    uav[VARIANCE as usize] = uav[VARIANCE_0 as usize];
    schedule_indirect(
        backend,
        &private.resolve_temporal,
        &srv,
        &uav,
        &private.constants,
    )?;

    for (src, dst) in [
        (RADIANCE_0, OUTPUT),
        (INPUT_NORMAL, NORMAL_HISTORY),
        (EXTRACTED_ROUGHNESS, ROUGHNESS_HISTORY),
        (INPUT_DEPTH_HIERARCHY, DEPTH_HISTORY),
    ] {
        backend.schedule_gpu_job(&FfxGpuJobDescription {
            job_label: "Copy to output".into(),
            descriptor: FfxGpuJobDescriptor::Copy(FfxCopyJobDescription {
                src: srv[src as usize],
                dst: srv[dst as usize],
                ..Default::default()
            }),
        })?;
    }

    backend.execute_gpu_jobs(params.command_list, private.effect_context_id)?;
    private.first_frame = false;
    Ok(())
}

pub fn ffx_denoiser_context_dispatch_reflections(
    context: &mut FfxDenoiserContext,
    params: &FfxDenoiserReflectionsDispatchDescription,
) -> Result<(), FfxErrorCode> {
    let private = context.private.as_mut().ok_or(FFX_ERROR_INVALID_POINTER)?;
    if private.device == 0 {
        return Err(FFX_ERROR_NULL_DEVICE);
    }
    let backend = private.description.backend_interface.clone();
    let mut backend = backend.borrow_mut();
    let dispatch = dispatch_reflections(&mut *backend, private, params);
    let unregister = backend.unregister_resources(params.command_list, private.effect_context_id);
    dispatch.and(unregister)
}
