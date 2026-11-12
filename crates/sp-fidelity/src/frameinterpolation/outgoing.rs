//! Rust-only correction for outgoing stationary geometry. SDK-P34.
//! Vendored AMD host/shaders remain unchanged; see CONFORMANCE.md.
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
            // Display-grid motion is sampled at a different ray than raw LR
            // depth. Do not treat that mismatch as independent object motion.
            || flags & (FFX_FRAMEINTERPOLATION_ENABLE_JITTER_MOTION_VECTORS
                | FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS) != 0
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

// Raw input history is captured during prepare, before the SDK dilates it.
// Two slots preserve the previous inputs until the matching dispatch succeeds.
#[derive(Default)]
pub(super) struct OutgoingHistory {
    pub(super) disabled: bool,
    pending: Option<Camera>,
    previous: Option<Camera>,
    older: Option<Camera>,
    viewport: Option<(FfxDimensions2D, FfxRect2D)>,
    slot: usize,
    depth: [FfxResourceInternal; 2],
    motion: [FfxResourceInternal; 2],
    candidates: [FfxResourceInternal; 2],
    distortion: FfxResourceInternal,
    pipelines: [Option<FfxPipelineState>; 6],
}
impl OutgoingHistory {
    pub(super) fn invalidate(&mut self) {
        self.previous = None;
        self.older = None;
    }
    pub(super) fn destroy(
        &mut self,
        backend: &mut dyn crate::interface::FfxInterface,
        context: u32,
    ) {
        for pipeline in self.pipelines.iter_mut().filter_map(Option::take) {
            ffx_safe_release_pipeline(backend, &mut { pipeline }, context);
        }
        for resource in self
            .depth
            .into_iter()
            .chain(self.motion)
            .chain(self.candidates)
            .chain([self.distortion])
        {
            if resource.internal_index != 0 {
                ffx_safe_release_resource(backend, resource, context);
            }
        }
    }
}
const CAMERA_WORDS: u32 = 72;

fn allocate(context: &mut FfxFrameInterpolationContextPrivate) -> Result<(), FfxErrorCode> {
    let mut backend = context.context_description.backend_interface.borrow_mut();
    let size = context.context_description.max_render_size;
    let o = &mut context.outgoing;
    let [depth0, depth1] = &mut o.depth;
    let [motion0, motion1] = &mut o.motion;
    let [candidate0, candidate1] = &mut o.candidates;
    for (target, format, name) in [
        (depth0, FfxSurfaceFormat::R32Float, "FI_OutgoingDepth0"),
        (depth1, FfxSurfaceFormat::R32Float, "FI_OutgoingDepth1"),
        (motion0, FfxSurfaceFormat::R16G16Float, "FI_OutgoingMotion0"),
        (motion1, FfxSurfaceFormat::R16G16Float, "FI_OutgoingMotion1"),
        (candidate0, FfxSurfaceFormat::R32Uint, "FI_OutgoingFieldX"),
        (candidate1, FfxSurfaceFormat::R32Uint, "FI_OutgoingFieldY"),
        (
            &mut o.distortion,
            FfxSurfaceFormat::R16G16Float,
            "FI_OutgoingPreviousDistortion",
        ),
    ] {
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
            size: CAMERA_WORDS,
            stage: FFX_BIND_COMPUTE_SHADER_STAGE,
        },
    ];
    let flags = context.context_description.flags;
    let permutation =
        if flags & FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED != 0 {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED
        } else {
            0
        } | if flags & FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS == 0 {
            FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS
        } else {
            0
        };
    let samplers = [FfxSamplerDescription {
        filter: FfxFilterType::MinMagMipLinear,
        address_mode_u: FfxAddressMode::Clamp,
        address_mode_v: FfxAddressMode::Clamp,
        address_mode_w: FfxAddressMode::Clamp,
        stage: FFX_BIND_COMPUTE_SHADER_STAGE,
    }];
    for (index, (pass, name)) in [
        (
            FfxFrameInterpolationPass::RetainOutgoingGeometry,
            "RETAIN_OUTGOING_GEOMETRY",
        ),
        (
            FfxFrameInterpolationPass::ReconstructOutgoingGeometry,
            "RECONSTRUCT_OUTGOING_GEOMETRY",
        ),
        (
            FfxFrameInterpolationPass::ResolveOutgoingGeometry,
            "RESOLVE_OUTGOING_GEOMETRY",
        ),
        (
            FfxFrameInterpolationPass::RetainOutgoingDistortion,
            "RETAIN_OUTGOING_DISTORTION",
        ),
        (
            FfxFrameInterpolationPass::ReconstructCurrentGeometry,
            "RECONSTRUCT_CURRENT_GEOMETRY",
        ),
        (
            FfxFrameInterpolationPass::ResolveCurrentGeometry,
            "RESOLVE_CURRENT_GEOMETRY",
        ),
    ]
    .into_iter()
    .enumerate()
    {
        if o.pipelines[index].is_some() {
            continue;
        }
        o.pipelines[index] = Some(backend.create_pipeline(
            FfxEffect::FrameInterpolation,
            pass as u32,
            permutation,
            &FfxPipelineDescription {
                context_flags: flags,
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
    Ok(())
}

pub(super) fn prepare(
    context: &mut FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationPrepareDescription,
) -> Result<(), FfxErrorCode> {
    context.outgoing.pending = if context.outgoing.disabled {
        None
    } else {
        Camera::from_prepare(params, context.context_description.flags)
    };
    if context.outgoing.pending.is_none() {
        context.outgoing.invalidate();
        return Ok(());
    }
    // Allocate before registering inputs or queuing any per-frame SDK work.
    if let Err(error) = allocate(context) {
        context.outgoing.pending = None;
        context.outgoing.invalidate();
        return Err(error);
    }
    Ok(())
}
fn job(
    context: &FfxFrameInterpolationContextPrivate,
    index: usize,
    size: FfxDimensions2D,
    srvs: &[FfxResourceInternal],
    uavs: &[FfxResourceInternal],
    camera: Option<FfxConstantBuffer>,
) -> Result<(), FfxErrorCode> {
    let pipeline = context.outgoing.pipelines[index].as_ref().unwrap();
    let mut cbs = vec![context.constant_buffers[0].clone()];
    if let Some(camera) = camera {
        cbs.push(camera);
    }
    context
        .context_description
        .backend_interface
        .borrow_mut()
        .schedule_gpu_job(&FfxGpuJobDescription {
            job_label: pipeline.name.clone(),
            descriptor: FfxGpuJobDescriptor::Compute(Box::new(FfxComputeJobDescription {
                pipeline: pipeline.clone(),
                dimensions: [size.width.div_ceil(8), size.height.div_ceil(8), 1],
                srv_textures: srvs
                    .iter()
                    .map(|&resource| FfxTextureSRV { resource })
                    .collect(),
                uav_textures: uavs
                    .iter()
                    .map(|&resource| FfxTextureUAV { resource, mip: 0 })
                    .collect(),
                cbs,
                ..Default::default()
            })),
        })
}
pub(super) fn capture(context: &FfxFrameInterpolationContextPrivate) -> Result<(), FfxErrorCode> {
    let Some(camera) = context.outgoing.pending else {
        return Ok(());
    };
    let o = &context.outgoing;
    job(
        context,
        0,
        camera.render_size,
        &[
            context.srv_resources[FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DEPTH as usize],
            context.srv_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_MOTION_VECTORS as usize],
        ],
        &[o.depth[o.slot], o.motion[o.slot]],
        None,
    )
}
pub(super) fn begin_dispatch(
    context: &mut FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) {
    let valid = context
        .outgoing
        .pending
        .is_some_and(|c| c.frame_id == params.frame_id && c.render_size == params.render_size);
    let adjacent = context.outgoing.previous.is_some_and(|c| {
        c.frame_id.checked_add(1) == Some(params.frame_id) && c.render_size == params.render_size
    });
    let viewport = (params.display_size, params.interpolation_rect);
    if context.constants.reset != 0
        || !valid
        || !adjacent
        || context.outgoing.viewport != Some(viewport)
    {
        context.outgoing.invalidate();
    }
    if !valid {
        context.outgoing.pending = None;
    }
    context.outgoing.viewport = Some(viewport);
}
// Fill sparse current-source splats before AMD constructs the motion pyramid
// and visibility masks. No previous-source inference or new color blending.
pub(super) fn reconstruct_current(
    context: &FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    let o = &context.outgoing;
    let (Some(current), Some(previous)) = (o.pending, o.previous) else {
        return Ok(());
    };
    let mut words = Vec::with_capacity(CAMERA_WORDS as usize);
    for camera in [current, previous, o.older.unwrap_or(previous)] {
        camera.append_words(&mut words);
    }
    let mut constant = FfxConstantBuffer::default();
    {
        let mut backend = context.context_description.backend_interface.borrow_mut();
        backend.stage_constant_buffer_data_func(&words, &mut constant)?;
        for target in o.candidates {
            backend.schedule_gpu_job(&FfxGpuJobDescription {
                job_label: "Clear current geometry candidates".into(),
                descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                    target,
                    color: [0.; 4],
                }),
            })?;
        }
    }
    job(
        context,
        4,
        params.render_size,
        &[
            o.depth[o.slot],
            o.motion[o.slot],
            context.srv_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD as usize],
        ],
        &o.candidates,
        Some(constant.clone()),
    )?;
    job(
        context,
        5,
        params.render_size,
        &[
            o.candidates[0],
            o.candidates[1],
            o.distortion,
            context.srv_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD as usize],
            o.depth[o.slot],
            o.motion[o.slot],
        ],
        &[
            context.uav_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X as usize],
            context.uav_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y as usize],
            context.uav_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME
                    as usize],
        ],
        Some(constant),
    )
}

pub(super) fn reconstruct(
    context: &FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    let o = &context.outgoing;
    let (Some(current), Some(previous), Some(older)) = (o.pending, o.previous, o.older) else {
        return Ok(());
    };
    let mut words = Vec::with_capacity(CAMERA_WORDS as usize);
    for camera in [current, previous, older] {
        camera.append_words(&mut words);
    }
    let mut constant = FfxConstantBuffer::default();
    {
        let mut backend = context.context_description.backend_interface.borrow_mut();
        backend.stage_constant_buffer_data_func(&words, &mut constant)?;
        for target in o.candidates {
            backend.schedule_gpu_job(&FfxGpuJobDescription {
                job_label: "Clear outgoing candidates".into(),
                descriptor: FfxGpuJobDescriptor::ClearFloat(FfxClearFloatJobDescription {
                    target,
                    color: [0.; 4],
                }),
            })?;
        }
    }
    let previous_slot = 1 - o.slot;
    job(
        context,
        1,
        params.render_size,
        &[o.depth[previous_slot], o.motion[previous_slot]],
        &o.candidates,
        Some(constant),
    )?;
    job(
        context,
        2,
        params.render_size,
        &[
            o.candidates[0],
            o.candidates[1],
            o.distortion,
            context.srv_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD as usize],
        ],
        &[
            context.uav_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_X as usize],
            context.uav_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_GAME_MOTION_VECTOR_FIELD_Y as usize],
            context.uav_resources
                [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISOCCLUSION_MASK as usize],
        ],
        None,
    )
}
pub(super) fn retain_distortion(
    context: &FfxFrameInterpolationContextPrivate,
    params: &FfxFrameInterpolationDispatchDescription,
) -> Result<(), FfxErrorCode> {
    if context.outgoing.pending.is_none() {
        return Ok(());
    }
    job(
        context,
        3,
        params.render_size,
        &[context.srv_resources
            [FFX_FRAMEINTERPOLATION_RESOURCE_IDENTIFIER_DISTORTION_FIELD as usize]],
        &[context.outgoing.distortion],
        None,
    )
}
pub(super) fn finish(
    context: &mut FfxFrameInterpolationContextPrivate,
    success: bool,
    dispatch: bool,
) {
    if !success {
        context.outgoing.pending = None;
        context.outgoing.invalidate();
    }
    if dispatch && let Some(current) = context.outgoing.pending.take() {
        context.outgoing.older = context.outgoing.previous;
        context.outgoing.previous = Some(current);
        context.outgoing.slot = 1 - context.outgoing.slot;
    }
}
