//! Optional port extension for static geometry leaving the current viewport.
//! See CONFORMANCE.md: SDK-P29. The AMD path does not allocate these resources.
use super::private::*;
use super::resources::*;
use super::*;
use crate::error::*;
use crate::object_management::*;

#[derive(Clone, Copy)]
struct Camera {
    position: [f32; 3],
    right: [f32; 3],
    up: [f32; 3],
    forward: [f32; 3],
    // device depth = projection.x + projection.y / view-space Z.
    projection: [f32; 4],
    jitter: [f32; 2],
    render_size: FfxDimensions2D,
    frame_id: u64,
}

impl Camera {
    fn from_prepare(p: &FfxFrameInterpolationPrepareDescription, flags: u32) -> Option<Self> {
        let dot = |a: [f32; 3], b: [f32; 3]| a.into_iter().zip(b).map(|(x, y)| x * y).sum::<f32>();
        let axes = [p.camera_right, p.camera_up, p.camera_forward];
        // Numerical orthonormality check, not a scene-dependent quality threshold.
        if !p.camera_position.into_iter().chain(axes.into_iter().flatten()).all(f32::is_finite)
            || axes.iter().any(|&a| (dot(a, a) - 1.0).abs() > 1e-3)
            || dot(axes[0], axes[1]).abs() > 1e-3
            || dot(axes[0], axes[2]).abs() > 1e-3
            || dot(axes[1], axes[2]).abs() > 1e-3
            || p.render_size.width == 0 || p.render_size.height == 0
            || !p.camera_near.is_finite() || !p.camera_far.is_finite()
            || p.camera_near <= 0.0 || p.camera_far <= 0.0 || p.camera_far == p.camera_near
            || !p.camera_fov_angle_vertical.is_finite()
            || !(0.0..std::f32::consts::PI).contains(&p.camera_fov_angle_vertical)
            || p.camera_fov_angle_vertical == 0.0
            || !p.jitter_offset.x.is_finite() || !p.jitter_offset.y.is_finite()
            // The SDK's jittered-MV path does not expose cancellation metadata.
            || flags & FFX_FRAMEINTERPOLATION_ENABLE_JITTER_MOTION_VECTORS != 0
        {
            return None;
        }
        let near = p.camera_near.min(p.camera_far);
        let far = p.camera_near.max(p.camera_far);
        let inverted = flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED != 0;
        let infinite = flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE != 0;
        let (a, b) = match (inverted, infinite) {
            (true, true) => (0.0, near),
            (false, true) => (1.0, -near),
            (true, false) => (near / (near - far), near * (far / (far - near))),
            (false, false) => (far / (far - near), near * (far / (near - far))),
        };
        let tan_y = (p.camera_fov_angle_vertical * 0.5).tan();
        Some(Self {
            position: p.camera_position,
            right: axes[0],
            up: axes[1],
            forward: axes[2],
            projection: [
                a,
                b,
                tan_y * p.render_size.width as f32 / p.render_size.height as f32,
                tan_y,
            ],
            jitter: [p.jitter_offset.x, p.jitter_offset.y],
            render_size: p.render_size,
            frame_id: p.frame_id,
        })
    }
    fn append_words(self, words: &mut Vec<u32>) {
        for v in [self.position, self.right, self.up, self.forward] {
            words.extend(v.map(f32::to_bits));
            words.push(0);
        }
        words.extend(self.projection.map(f32::to_bits));
        words.extend(self.jitter.map(f32::to_bits));
        words.extend([0, 0]);
    }
}

#[derive(Default)]
pub(super) struct EdgeHistory {
    pending: Option<Camera>,
    previous: Option<Camera>,
    older: Option<Camera>,
    viewport: Option<(FfxDimensions2D, FfxRect2D)>,
    depth: FfxResourceInternal,
    motion: FfxResourceInternal,
    pipeline: Option<FfxPipelineState>,
    visibility_pipeline: Option<FfxPipelineState>,
    camera_constants: FfxConstantBuffer,
}

impl EdgeHistory {
    pub(super) fn prepare(&mut self, params: &FfxFrameInterpolationPrepareDescription, flags: u32) {
        self.pending = Camera::from_prepare(params, flags);
    }
    pub(super) fn failed_execution(&mut self) {
        self.pending = None;
        self.invalidate();
    }
    pub(super) fn invalidate(&mut self) {
        self.previous = None;
        self.older = None;
    }
    pub(super) fn destroy(
        &mut self,
        backend: &mut dyn crate::interface::FfxInterface,
        context: u32,
    ) {
        if let Some(mut pipeline) = self.pipeline.take() {
            ffx_safe_release_pipeline(backend, &mut pipeline, context);
        }
        if let Some(mut pipeline) = self.visibility_pipeline.take() {
            ffx_safe_release_pipeline(backend, &mut pipeline, context);
        }
        for resource in [self.depth, self.motion] {
            if resource.internal_index != 0 {
                ffx_safe_release_resource(backend, resource, context);
            }
        }
    }
}

// Three camera records, each six vec4s. Separate from the unchanged AMD cbFI.
const EDGE_WORDS: u32 = 72;

fn ensure_resources(context: &mut FfxFrameInterpolationContextPrivate) -> Result<(), FfxErrorCode> {
    if context.edge.pipeline.is_some() && context.edge.visibility_pipeline.is_some() {
        return Ok(());
    }
    let mut backend = context.context_description.backend_interface.borrow_mut();
    let size = context.context_description.max_render_size;
    for (target, format, name) in [
        (
            &mut context.edge.depth,
            FfxSurfaceFormat::R32Float,
            "FI_EdgePreviousDepth",
        ),
        (
            &mut context.edge.motion,
            FfxSurfaceFormat::R16G16Float,
            "FI_EdgePreviousMotion",
        ),
    ] {
        // Keep successfully allocated resources if a later allocation fails.
        if target.internal_index != 0 {
            continue;
        }
        *target = backend.create_resource(
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
                    usage: FFX_RESOURCE_USAGE_UAV,
                },
                initial_state: FFX_RESOURCE_STATE_UNORDERED_ACCESS,
                name,
                id: 0,
                init_data: FfxResourceInitData {
                    r#type: FfxResourceInitDataType::Uninitialized,
                    ..Default::default()
                },
            },
            context.effect_context_id,
        )?;
    }
    let constants = [
        FfxRootConstantDescription {
            size: FrameInterpolationConstants::WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
        FfxRootConstantDescription {
            size: EDGE_WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];
    let permutation =
        if context.context_description.flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED != 0 {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED
        } else {
            0
        };
    let samplers = [FfxSamplerDescription {
        filter: FfxFilterType::MinMagMipPoint,
        address_mode_u: FfxAddressMode::Clamp,
        address_mode_v: FfxAddressMode::Clamp,
        address_mode_w: FfxAddressMode::Clamp,
        stage: FFX_BIND_COMPUTE_SHADER_STAGE,
    }];
    for (pass, name, target) in [
        (
            FfxFrameInterpolationPass::ReconstructOutgoingGeometry,
            "RECONSTRUCT_OUTGOING_GEOMETRY",
            &mut context.edge.pipeline,
        ),
        (
            FfxFrameInterpolationPass::DisocclusionWithCameraVisibility,
            "DISOCCLUSION_CAMERA_VISIBILITY",
            &mut context.edge.visibility_pipeline,
        ),
    ] {
        if target.is_none() {
            *target = Some(backend.create_pipeline(
                FfxEffect::FrameInterpolation,
                pass as u32,
                permutation,
                &FfxPipelineDescription {
                    context_flags: context.context_description.flags,
                    samplers: &samplers,
                    root_constants: &constants,
                    name: name.into(),
                    stage: FFX_BIND_COMPUTE_SHADER_STAGE,
                    indirect_workload: 0,
                    backbuffer_format: FfxSurfaceFormat::Unknown,
                },
                context.effect_context_id,
            )?);
        }
    }
    Ok(())
}

pub(super) fn begin_dispatch(
    context: &mut FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) {
    let valid = params.distortion_field.resource == 0
        && context
            .edge
            .pending
            .is_some_and(|c| c.frame_id == params.frame_id && c.render_size == params.render_size);
    let adjacent = context.edge.previous.is_some_and(|c| {
        c.frame_id.checked_add(1) == Some(params.frame_id) && c.render_size == params.render_size
    });
    let viewport = (params.display_size, params.interpolation_rect);
    if context.constants.reset != 0
        || !valid
        || !adjacent
        || context.edge.viewport != Some(viewport)
    {
        context.edge.invalidate();
    }
    if !valid {
        context.edge.pending = None;
    }
    context.edge.viewport = Some(viewport);
    // The SDK leaves Mode unused. Keep zero in the original path; bit zero
    // enables only the camera-supported visibility/feather extension.
    context.constants.mode = i32::from(
        context.edge.pending.is_some()
            && context.edge.previous.is_some()
            && context.edge.older.is_some()
            && params.distortion_field.resource == 0,
    );
}

pub(super) fn schedule(
    context: &mut FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    let (Some(current), Some(previous), Some(older)) = (
        context.edge.pending,
        context.edge.previous,
        context.edge.older,
    ) else {
        return Ok(());
    };
    // A nonzero distortion field changes screen-space correspondence; do not
    // apply a pinhole-camera reconstruction to that image.
    if params.distortion_field.resource != 0 {
        return Ok(());
    }
    ensure_resources(context)?;
    let mut words = Vec::with_capacity(EDGE_WORDS as usize);
    for camera in [current, previous, older] {
        camera.append_words(&mut words);
    }
    let mut constant = FfxConstantBuffer::default();
    let mut backend = context.context_description.backend_interface.borrow_mut();
    backend.stage_constant_buffer_data_func(&words, &mut constant)?;
    context.edge.camera_constants = constant.clone();
    backend.schedule_gpu_job(&FfxGpuJobDescription {
        job_label: "RECONSTRUCT_OUTGOING_GEOMETRY".into(),
        descriptor: FfxGpuJobDescriptor::Compute(Box::new(FfxComputeJobDescription {
            pipeline: context.edge.pipeline.as_ref().unwrap().clone(),
            dimensions: [
                params.render_size.width.div_ceil(8),
                params.render_size.height.div_ceil(8),
                1,
            ],
            srv_textures: [context.edge.depth, context.edge.motion]
                .into_iter()
                .map(|resource| FfxTextureSRV { resource })
                .collect(),
            uav_textures: [
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X,
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y,
                FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME,
            ]
            .into_iter()
            .map(|id| FfxTextureUAV {
                resource: context.uav_resources[id as usize],
                mip: 0,
            })
            .collect(),
            cbs: vec![context.constant_buffers[0].clone(), constant],
            ..Default::default()
        })),
    })
}

pub(super) fn schedule_disocclusion(
    context: &mut FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) -> Result<bool, FfxErrorCode> {
    if context.constants.mode == 0 {
        return Ok(false);
    }
    let resources = [
        context.srv_resources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH as usize],
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME
                as usize],
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME
                as usize],
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X as usize],
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y as usize],
        context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_INPAINTING_PYRAMID as usize],
        context.srv_resources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD as usize],
        context.edge.depth,
        context.edge.motion,
    ];
    context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: "DISOCCLUSION_CAMERA_VISIBILITY".into(),
            descriptor: FfxGpuJobDescriptor::Compute(Box::new(FfxComputeJobDescription {
                pipeline: context.edge.visibility_pipeline.as_ref().unwrap().clone(),
                dimensions: [
                    params.render_size.width.div_ceil(8),
                    params.render_size.height.div_ceil(8),
                    1,
                ],
                srv_textures: resources
                    .into_iter()
                    .map(|resource| FfxTextureSRV { resource })
                    .collect(),
                uav_textures: vec![FfxTextureUAV {
                    resource: context.uav_resources
                        [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK as usize],
                    mip: 0,
                }],
                cbs: vec![
                    context.constant_buffers[0].clone(),
                    context.edge.camera_constants.clone(),
                ],
                ..Default::default()
            })),
        })?;
    Ok(true)
}

pub(super) fn retain(
    context: &mut FfxFrameInterpolationContextPrivate,
) -> Result<(), FfxErrorCode> {
    let Some(current) = context.edge.pending.take() else {
        context.edge.invalidate();
        return Ok(());
    };
    ensure_resources(context)?;
    let mut backend = context.context_description.backend_interface.borrow_mut();
    for (source, target) in [
        (
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_DEPTH,
            context.edge.depth,
        ),
        (
            FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DILATED_MOTION_VECTORS,
            context.edge.motion,
        ),
    ] {
        backend.schedule_gpu_job(&FfxGpuJobDescription {
            job_label: "Retain previous geometry".into(),
            descriptor: FfxGpuJobDescriptor::Copy(FfxCopyJobDescription {
                src: context.srv_resources[source as usize],
                dst: target,
                ..Default::default()
            }),
        })?;
    }
    context.edge.older = context.edge.previous;
    context.edge.previous = Some(current);
    Ok(())
}
