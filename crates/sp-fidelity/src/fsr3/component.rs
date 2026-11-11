//! Port of `sdk/src/components/fsr3/ffx_fsr3.cpp` (FSR 3.1.4).
use super::private::*;
use super::resources::*;
use super::*;
use crate::assert::ffx_assert;
use crate::error::*;
use crate::frameinterpolation::*;
use crate::fsr3upscaler::*;
use crate::interface::{
    FfxFrameGenerationConfig, FfxFrameGenerationDispatchFunc, ffx_sdk_make_version,
};
use crate::opticalflow::*;
use std::cell::RefMut;

fn state(context: &FfxFsr3Context) -> Result<RefMut<'_, FfxFsr3ContextPrivate>, FfxErrorCode> {
    context
        .private
        .as_ref()
        .ok_or(FFX_ERROR_INVALID_POINTER)?
        .try_borrow_mut()
        .map_err(|_| FFX_ERROR_INVALID_ARGUMENT)
}

/// `ffxFsr3ContextCreate`. Interface and pointer validity are represented by
/// Rust references and the backend trait.
pub fn ffx_fsr3_context_create(
    context: &mut FfxFsr3Context,
    description: &FfxFsr3ContextDescription,
) -> Result<(), FfxErrorCode> {
    *context = FfxFsr3Context::default();
    let private = Rc::new(RefCell::new(FfxFsr3ContextPrivate::zeroed(
        description.clone(),
    )));
    context.private = Some(private.clone());
    let mut p = private.borrow_mut();
    let upscaling_only = description.flags & FFX_FSR3_ENABLE_UPSCALING_ONLY != 0;
    let interpolation_only = description.flags & FFX_FSR3_ENABLE_INTERPOLATION_ONLY != 0;
    p.async_workload_supported = description.flags & FFX_FSR3_ENABLE_ASYNC_WORKLOAD_SUPPORT != 0;
    p.shared_resource_count = if p.async_workload_supported {
        FSR3_MAX_QUEUED_FRAMES
    } else {
        1
    };
    ffx_assert!(!upscaling_only || !interpolation_only);

    // These private mode fields remain zero in the SDK; use them at the same
    // original branch sites (see CONFORMANCE.md).
    if !p.upscaling_only {
        p.effect_context_id_shared_resources = description
            .backend_interface_shared_resources
            .borrow_mut()
            .create_backend_context(FfxEffect::SharedResources, None)?;
    } else {
        p.description.backend_interface_shared_resources =
            description.backend_interface_upscaling.clone();
    }

    if !interpolation_only {
        let flags = (description.flags
            & (FFX_FSR3_ENABLE_HIGH_DYNAMIC_RANGE
                | FFX_FSR3_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
                | FFX_FSR3_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION
                | FFX_FSR3_ENABLE_DEPTH_INVERTED
                | FFX_FSR3_ENABLE_DEPTH_INFINITE
                | FFX_FSR3_ENABLE_AUTO_EXPOSURE
                | FFX_FSR3_ENABLE_DYNAMIC_RESOLUTION
                | FFX_FSR3_ENABLE_DEBUG_CHECKING))
            | if description.flags & FFX_FSR3_ENABLE_HDR_UPSCALE_SDR_FINALOUTPUT != 0 {
                FFX_FSR3UPSCALER_ENABLE_HIGH_DYNAMIC_RANGE
            } else {
                0
            };
        ffx_fsr3_upscaler_context_create(
            &mut p.upscaler_context,
            &FfxFsr3UpscalerContextDescription {
                flags,
                max_render_size: description.max_render_size,
                max_upscale_size: description.max_upscale_size,
                backend_interface: description.backend_interface_upscaling.clone(),
                fp_message: description.fp_message,
            },
        )?;
    }

    if !upscaling_only {
        ffx_opticalflow_context_create(
            &mut p.of_context,
            &FfxOpticalflowContextDescription {
                backend_interface: description.backend_interface_frame_interpolation.clone(),
                flags: 0,
                resolution: description.display_size,
            },
        )?;
        let mut flags = 0;
        for (source, destination) in [
            (
                FFX_FSR3_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS,
                FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS,
            ),
            (
                FFX_FSR3_ENABLE_MOTION_VECTORS_JITTER_CANCELLATION,
                FFX_FRAMEINTERPOLATION_ENABLE_JITTER_MOTION_VECTORS,
            ),
            (
                FFX_FSR3_ENABLE_DEPTH_INVERTED,
                FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED,
            ),
            (
                FFX_FSR3_ENABLE_DEPTH_INFINITE,
                FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE,
            ),
            (
                FFX_FSR3_ENABLE_HIGH_DYNAMIC_RANGE | FFX_FSR3_ENABLE_SDR_UPSCALE_HDR_FINALOUTPUT,
                FFX_FRAMEINTERPOLATION_ENABLE_HDR_COLOR_INPUT,
            ),
        ] {
            if description.flags & source != 0 {
                flags |= destination;
            }
        }
        if p.async_workload_supported {
            flags |= FFX_FRAMEINTERPOLATION_ENABLE_ASYNC_SUPPORT;
        }
        ffx_frame_interpolation_context_create(
            &mut p.fi_context,
            &FfxFrameInterpolationContextDescription {
                flags,
                backend_interface: description.backend_interface_frame_interpolation.clone(),
                max_render_size: description.max_render_size,
                display_size: description.display_size,
                back_buffer_format: description.back_buffer_format,
                previous_interpolation_source_format: description.back_buffer_format,
            },
        )?;
        let of_resources = ffx_opticalflow_get_shared_resource_descriptions(&p.of_context)?;
        let mut backend = description.backend_interface_shared_resources.borrow_mut();
        p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR as usize] = backend
            .create_resource(
                &of_resources.optical_flow_vector,
                p.effect_context_id_shared_resources,
            )?;
        p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCD_OUTPUT as usize] = backend
            .create_resource(
                &of_resources.optical_flow_scd,
                p.effect_context_id_shared_resources,
            )?;
    }

    if !p.interpolation_only {
        let descriptions = ffx_fsr3_upscaler_get_shared_resource_descriptions(&p.upscaler_context)?;
        // FfxCreateResourceDescription names are static in this Rust port. The
        // SDK's indexed resource names are retained without leaking strings.
        const NAMES: [[&str; 3]; 2] = [
            [
                "FSR3UPSCALER_DilatedDepth0",
                "FSR3UPSCALER_DilatedVelocity0",
                "FSR3UPSCALER_ReconstructedPrevNearestDepth0",
            ],
            [
                "FSR3UPSCALER_DilatedDepth1",
                "FSR3UPSCALER_DilatedVelocity1",
                "FSR3UPSCALER_ReconstructedPrevNearestDepth1",
            ],
        ];
        let mut backend = description.backend_interface_shared_resources.borrow_mut();
        for i in 0..p.shared_resource_count {
            for (offset, mut resource) in [
                descriptions.dilated_depth,
                descriptions.dilated_motion_vectors,
                descriptions.reconstructed_prev_nearest_depth,
            ]
            .into_iter()
            .enumerate()
            {
                resource.name = NAMES[i as usize][offset];
                let index = FFX_FSR3_RESOURCE_IDENTIFIER_DILATED_DEPTH_0 as usize
                    + i as usize * FFX_FSR3_RESOURCE_IDENTIFIER_UPSCALED_COUNT as usize
                    + offset;
                p.shared_resources[index] =
                    backend.create_resource(&resource, p.effect_context_id_shared_resources)?;
            }
        }
    }
    Ok(())
}

/// `ffxFsr3ContextGetGpuMemoryUsage`. The nullable out parameters become
/// independent usage values. As in the SDK, a failed constituent query leaves
/// its zero-initialized usage unchanged.
pub fn ffx_fsr3_context_get_gpu_memory_usage(
    context: &FfxFsr3Context,
) -> Result<
    (
        FfxEffectMemoryUsage,
        FfxEffectMemoryUsage,
        FfxEffectMemoryUsage,
    ),
    FfxErrorCode,
> {
    let mut p = state(context)?;
    Ok((
        ffx_fsr3_upscaler_context_get_gpu_memory_usage(&mut p.upscaler_context).unwrap_or_default(),
        ffx_opticalflow_context_get_gpu_memory_usage(&p.of_context).unwrap_or_default(),
        ffx_frame_interpolation_context_get_gpu_memory_usage(&p.fi_context).unwrap_or_default(),
    ))
}

/// `ffxFsr3ContextGenerateReactiveMask`.
pub fn ffx_fsr3_context_generate_reactive_mask(
    context: &mut FfxFsr3Context,
    params: &FfxFsr3GenerateReactiveDescription,
) -> Result<(), FfxErrorCode> {
    ffx_fsr3_upscaler_context_generate_reactive_mask(
        &mut state(context)?.upscaler_context,
        &FfxFsr3UpscalerGenerateReactiveDescription {
            command_list: params.command_list,
            color_opaque_only: params.color_opaque_only.clone(),
            color_pre_upscale: params.color_pre_upscale.clone(),
            out_reactive: params.out_reactive.clone(),
            render_size: params.render_size,
            scale: params.scale,
            cutoff_threshold: params.cutoff_threshold,
            binary_value: params.binary_value,
            flags: params.flags,
        },
    )
}

fn select_shared_resources(p: &mut FfxFsr3ContextPrivate, frame_id: u64) {
    let slot = (frame_id % u64::from(p.shared_resource_count)) as usize;
    let offset = slot * FFX_FSR3_RESOURCE_IDENTIFIER_UPSCALED_COUNT as usize;
    let mut backend = p
        .description
        .backend_interface_shared_resources
        .borrow_mut();
    p.dilated_depth = backend.get_resource(
        p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_DILATED_DEPTH_0 as usize + offset],
    );
    p.dilated_motion_vectors = backend.get_resource(
        p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS_0 as usize + offset],
    );
    p.reconstructed_prev_nearest_depth = backend.get_resource(
        p.shared_resources
            [FFX_FSR3_RESOURCE_IDENTIFIER_RECONSTRUCTED_PREVIOUS_NEAREST_DEPTH_0 as usize + offset],
    );
}

/// `ffxFsr3ContextDispatchUpscale`.
pub fn ffx_fsr3_context_dispatch_upscale(
    context: &mut FfxFsr3Context,
    params: &FfxFsr3DispatchUpscaleDescription,
) -> Result<(), FfxErrorCode> {
    let mut p = state(context)?;
    ffx_assert!(p.description.flags & FFX_FSR3_ENABLE_INTERPOLATION_ONLY == 0);
    p.delta_time = (params.frame_time_delta / 1000.0).clamp(0.0, 1.0);
    select_shared_resources(&mut p, params.frame_id);
    let dispatch = FfxFsr3UpscalerDispatchDescription {
        command_list: params.command_list,
        color: params.color.clone(),
        depth: params.depth.clone(),
        motion_vectors: params.motion_vectors.clone(),
        exposure: params.exposure.clone(),
        reactive: params.reactive.clone(),
        transparency_and_composition: params.transparency_and_composition.clone(),
        output: params.upscale_output.clone(),
        jitter_offset: params.jitter_offset,
        motion_vector_scale: params.motion_vector_scale,
        render_size: params.render_size,
        // The composite SDK does not forward its upscaleSize member.
        upscale_size: FfxDimensions2D::default(),
        enable_sharpening: params.enable_sharpening,
        sharpness: params.sharpness,
        frame_time_delta: params.frame_time_delta,
        pre_exposure: params.pre_exposure,
        reset: params.reset,
        camera_near: params.camera_near,
        camera_far: params.camera_far,
        camera_fov_angle_vertical: params.camera_fov_angle_vertical,
        view_space_to_meters_factor: params.view_space_to_meters_factor,
        dilated_depth: p.dilated_depth.clone(),
        dilated_motion_vectors: p.dilated_motion_vectors.clone(),
        reconstructed_prev_nearest_depth: p.reconstructed_prev_nearest_depth.clone(),
        flags: if params.flags & FFX_FSR3_UPSCALER_FLAG_DRAW_DEBUG_VIEW != 0 {
            FFX_FSR3UPSCALER_DISPATCH_DRAW_DEBUG_VIEW
        } else {
            0
        },
    };
    ffx_fsr3_upscaler_context_dispatch(&mut p.upscaler_context, &dispatch)
}

/// `ffxFsr3ContextDispatchFrameGenerationPrepare`.
pub fn ffx_fsr3_context_dispatch_frame_generation_prepare(
    context: &mut FfxFsr3Context,
    params: &FfxFsr3DispatchFrameGenerationPrepareDescription,
) -> Result<(), FfxErrorCode> {
    let mut p = state(context)?;
    ffx_assert!(p.description.flags & FFX_FSR3_ENABLE_UPSCALING_ONLY == 0);
    select_shared_resources(&mut p, params.frame_id);
    let prepare = FfxFrameInterpolationPrepareDescription {
        command_list: params.command_list,
        render_size: params.render_size,
        depth: params.depth.clone(),
        motion_vectors: params.motion_vectors.clone(),
        jitter_offset: params.jitter_offset,
        motion_vector_scale: params.motion_vector_scale,
        frame_time_delta: params.frame_time_delta,
        camera_near: params.camera_near,
        camera_far: params.camera_far,
        view_space_to_meters_factor: params.view_space_to_meters_factor,
        camera_fov_angle_vertical: params.camera_fov_angle_vertical,
        frame_id: params.frame_id,
        dilated_depth: p.dilated_depth.clone(),
        dilated_motion_vectors: p.dilated_motion_vectors.clone(),
        reconstructed_prev_depth: p.reconstructed_prev_nearest_depth.clone(),
        ..Default::default()
    };
    let result = if p.description.flags & FFX_FSR3_ENABLE_INTERPOLATION_ONLY != 0 {
        ffx_frame_interpolation_prepare(&mut p.fi_context, &prepare)
    } else {
        Ok(())
    };
    p.fg_prepare_descriptions[(params.frame_id & 1) as usize] = prepare;
    result
}

fn dispatch_frame_generation(
    p: &mut FfxFsr3ContextPrivate,
    params: &FfxFrameGenerationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    // The SDK's global context is populated only while frame generation is enabled.
    ffx_return_on_error!(p.frame_generation_enabled, FFX_ERROR_INVALID_POINTER);
    ffx_assert!(p.description.flags & FFX_FSR3_ENABLE_UPSCALING_ONLY == 0);
    let prepare = p.fg_prepare_descriptions[(params.frame_id & 1) as usize].clone();
    let (optical_flow_vector, optical_flow_scd) = {
        let mut backend = p
            .description
            .backend_interface_shared_resources
            .borrow_mut();
        (
            backend.get_resource(
                p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR as usize],
            ),
            backend.get_resource(
                p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCD_OUTPUT as usize],
            ),
        )
    };
    let optical_result = ffx_opticalflow_context_dispatch(
        &mut p.of_context,
        &FfxOpticalflowDispatchDescription {
            command_list: params.command_list,
            color: if p.hudless_color.resource != 0 {
                p.hudless_color.clone()
            } else {
                params.present_color.clone()
            },
            reset: params.reset,
            backbuffer_transfer_function: params.back_buffer_transfer_function as i32,
            min_max_luminance: FfxFloatCoords2D {
                x: params.min_max_luminance[0],
                y: params.min_max_luminance[1],
            },
            optical_flow_vector: optical_flow_vector.clone(),
            optical_flow_scd: optical_flow_scd.clone(),
        },
    );
    let display_size = FfxDimensions2D {
        width: params.present_color.description.width,
        height: params.present_color.description.height,
    };
    // The SDK resolves the shared handles again for interpolation.
    let (optical_flow_vector, optical_flow_scd) = {
        let mut backend = p
            .description
            .backend_interface_shared_resources
            .borrow_mut();
        (
            backend.get_resource(
                p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_OPTICAL_FLOW_VECTOR as usize],
            ),
            backend.get_resource(
                p.shared_resources[FFX_FSR3_RESOURCE_IDENTIFIER_OPTICAL_FLOW_SCD_OUTPUT as usize],
            ),
        )
    };
    let dispatch = FfxFrameInterpolationDispatchDescription {
        command_list: params.command_list,
        display_size,
        current_back_buffer: params.present_color.clone(),
        current_back_buffer_hud_less: p.hudless_color.clone(),
        render_size: prepare.render_size,
        output: params.outputs[0].clone(),
        optical_flow_vector,
        optical_flow_scene_change_detection: optical_flow_scd,
        optical_flow_block_size: 8,
        optical_flow_scale: FfxFloatCoords2D {
            x: 1.0 / display_size.width as f32,
            y: 1.0 / display_size.height as f32,
        },
        frame_time_delta: prepare.frame_time_delta,
        reset: params.reset,
        camera_near: prepare.camera_near,
        camera_far: prepare.camera_far,
        view_space_to_meters_factor: prepare.view_space_to_meters_factor,
        camera_fov_angle_vertical: prepare.camera_fov_angle_vertical,
        interpolation_rect: params.interpolation_rect,
        frame_id: params.frame_id,
        dilated_depth: p.dilated_depth.clone(),
        dilated_motion_vectors: p.dilated_motion_vectors.clone(),
        reconstructed_prev_depth: p.reconstructed_prev_nearest_depth.clone(),
        flags: p.frame_generation_flags
            & (FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_TEAR_LINES
                | FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW),
        back_buffer_transfer_function: params.back_buffer_transfer_function,
        min_max_luminance: params.min_max_luminance,
        ..Default::default()
    };
    // The SDK accumulates error codes with bitwise OR and executes interpolation
    // even when optical flow failed.
    let interpolation_result = ffx_frame_interpolation_dispatch(&mut p.fi_context, &dispatch);
    let error =
        optical_result.err().unwrap_or(FFX_OK) | interpolation_result.err().unwrap_or(FFX_OK);
    if error == FFX_OK { Ok(()) } else { Err(error) }
}

/// `ffxFsr3DispatchFrameGeneration`, with the active context passed explicitly
/// instead of obtained from the SDK's process-global pointer.
pub fn ffx_fsr3_dispatch_frame_generation(
    context: &FfxFsr3Context,
    params: &FfxFrameGenerationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    dispatch_frame_generation(&mut *state(context)?, params)
}

/// Obtain a callback for `FfxFrameGenerationConfig::frame_generation_callback`.
/// It captures weak context ownership; destroying or replacing the context
/// invalidates the callback without leaving a dangling pointer.
pub fn ffx_fsr3_get_frame_generation_callback(
    context: &FfxFsr3Context,
) -> Result<FfxFrameGenerationDispatchFunc, FfxErrorCode> {
    let weak = Rc::downgrade(context.private.as_ref().ok_or(FFX_ERROR_INVALID_POINTER)?);
    Ok(Rc::new(move |params| {
        let private = weak.upgrade().ok_or(FFX_ERROR_INVALID_POINTER)?;
        let mut p = private
            .try_borrow_mut()
            .map_err(|_| FFX_ERROR_INVALID_ARGUMENT)?;
        dispatch_frame_generation(&mut p, params)
    }))
}

/// `ffxFsr3ConfigureFrameGeneration`. The caller's callback and presentation
/// settings are passed to the backend, with the SDK debug flag adjustments.
pub fn ffx_fsr3_configure_frame_generation(
    context: &mut FfxFsr3Context,
    config: &FfxFrameGenerationConfig,
) -> Result<(), FfxErrorCode> {
    let backend = {
        let mut p = state(context)?;
        ffx_assert!(p.description.flags & FFX_FSR3_ENABLE_UPSCALING_ONLY == 0);
        ffx_assert!(
            !p.frame_generation_enabled
                || !config.allow_async_workloads
                || p.async_workload_supported
        );
        p.frame_generation_flags = config.flags;
        p.hudless_color = config.hudless_color.clone();
        p.frame_generation_enabled = config.frame_generation_enabled;
        p.description.backend_interface_frame_interpolation.clone()
    };
    let mut patched = config.clone();
    if patched.flags & FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_VIEW != 0 {
        patched.only_present_interpolated = true;
    }
    if patched.flags & FFX_FSR3_FRAME_GENERATION_FLAG_DRAW_DEBUG_PACING_LINES != 0 {
        patched.draw_debug_pacing_lines = true;
    }
    // Release the context borrow before entering the presentation backend;
    // it can retain (and later call) the supplied weak callback.
    backend
        .borrow_mut()
        .swap_chain_configure_frame_generation(&patched)
}

/// `ffxFsr3ContextDestroy`. GPU synchronization is the caller's responsibility.
pub fn ffx_fsr3_context_destroy(context: &mut FfxFsr3Context) -> Result<(), FfxErrorCode> {
    {
        let mut p = state(context)?;
        {
            let mut backend = p
                .description
                .backend_interface_shared_resources
                .borrow_mut();
            for resource in p.shared_resources {
                backend.destroy_resource(resource, p.effect_context_id_shared_resources)?;
            }
            // The original destroy ignores the backend-context destruction code.
            let _ = backend.destroy_backend_context(p.effect_context_id_shared_resources);
        }
        if p.description.flags & FFX_FSR3_ENABLE_UPSCALING_ONLY == 0 {
            ffx_frame_interpolation_context_destroy(&mut p.fi_context)?;
            ffx_opticalflow_context_destroy(&mut p.of_context)?;
        }
        if p.description.flags & FFX_FSR3_ENABLE_INTERPOLATION_ONLY == 0 {
            ffx_fsr3_upscaler_context_destroy(&mut p.upscaler_context)?;
        }
        p.frame_generation_enabled = false;
    }
    context.private = None;
    Ok(())
}

fn upscale_quality(mode: FfxFsr3QualityMode) -> FfxFsr3UpscalerQualityMode {
    match mode {
        FfxFsr3QualityMode::Quality => FfxFsr3UpscalerQualityMode::Quality,
        FfxFsr3QualityMode::Balanced => FfxFsr3UpscalerQualityMode::Balanced,
        FfxFsr3QualityMode::Performance => FfxFsr3UpscalerQualityMode::Performance,
        FfxFsr3QualityMode::UltraPerformance => FfxFsr3UpscalerQualityMode::UltraPerformance,
    }
}

pub fn ffx_fsr3_get_upscale_ratio_from_quality_mode(mode: FfxFsr3QualityMode) -> f32 {
    ffx_fsr3_upscaler_get_upscale_ratio_from_quality_mode(upscale_quality(mode))
}
pub fn ffx_fsr3_get_render_resolution_from_quality_mode(
    display_width: u32,
    display_height: u32,
    mode: FfxFsr3QualityMode,
) -> Result<(u32, u32), FfxErrorCode> {
    ffx_fsr3_upscaler_get_render_resolution_from_quality_mode(
        display_width,
        display_height,
        upscale_quality(mode),
    )
}
pub fn ffx_fsr3_get_jitter_phase_count(render_width: i32, display_width: i32) -> i32 {
    ffx_fsr3_upscaler_get_jitter_phase_count(render_width, display_width)
}
pub fn ffx_fsr3_get_jitter_offset(
    index: i32,
    phase_count: i32,
) -> Result<(f32, f32), FfxErrorCode> {
    ffx_fsr3_upscaler_get_jitter_offset(index, phase_count)
}
pub fn ffx_fsr3_resource_is_null(resource: &FfxResource) -> bool {
    ffx_fsr3_upscaler_resource_is_null(resource)
}
pub fn ffx_fsr3_get_effect_version() -> FfxVersionNumber {
    ffx_sdk_make_version(
        FFX_FSR3_VERSION_MAJOR,
        FFX_FSR3_VERSION_MINOR,
        FFX_FSR3_VERSION_PATCH,
    )
}
