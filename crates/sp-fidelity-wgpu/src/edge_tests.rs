//! Analytic GPU checks for the optional camera-supported outgoing-edge pass.
use super::*;
use sp_fidelity::frameinterpolation::*;

const WIDTH: u32 = 96;
const HEIGHT: u32 = 64;

fn texture(
    device: &wgpu::Device,
    format: wgpu::TextureFormat,
    width: u32,
    height: u32,
) -> wgpu::Texture {
    let mut usage = wgpu::TextureUsages::TEXTURE_BINDING
        | wgpu::TextureUsages::COPY_SRC
        | wgpu::TextureUsages::COPY_DST;
    if format != wgpu::TextureFormat::Rg16Sint {
        usage |= wgpu::TextureUsages::STORAGE_BINDING;
    }
    if format == wgpu::TextureFormat::R32Uint {
        usage |= wgpu::TextureUsages::STORAGE_ATOMIC;
    }
    device.create_texture(&wgpu::TextureDescriptor {
        label: None,
        size: wgpu::Extent3d {
            width,
            height,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format,
        usage,
        view_formats: &[],
    })
}
fn upload(queue: &wgpu::Queue, texture: &wgpu::Texture, bytes: &[u8]) {
    queue.write_texture(
        texture.as_image_copy(),
        bytes,
        wgpu::TexelCopyBufferLayout {
            offset: 0,
            bytes_per_row: Some(texture.width() * texture.format().block_copy_size(None).unwrap()),
            rows_per_image: Some(texture.height()),
        },
        texture.size(),
    );
}

fn unpack_half(bits: u16) -> f32 {
    let sign = if bits & 0x8000 == 0 { 1.0 } else { -1.0 };
    let exponent = (bits >> 10) & 31;
    let fraction = f32::from(bits & 1023) / 1024.0;
    if exponent == 0 {
        sign * fraction * 2.0f32.powi(-14)
    } else {
        sign * (1.0 + fraction) * 2.0f32.powi(i32::from(exponent) - 15)
    }
}

struct Frame {
    game: Vec<u32>,
    edge: Option<Vec<u32>>,
    color: Vec<u16>,
    visibility: Vec<u8>,
}

enum Scene {
    ExpandedPlane,
    AttachedForeground,
    DepthStep,
    MovingOccluder,
    BrightnessContinuity,
    DistortionTransition,
}

fn sequence(device: &wgpu::Device, queue: &wgpu::Queue, camera: bool, scene: Scene) -> Vec<Frame> {
    let expansion = matches!(scene, Scene::ExpandedPlane | Scene::DepthStep);
    let dynamic = matches!(scene, Scene::AttachedForeground);
    let (backend, _) = ffx_get_interface_wgpu(device);
    let captures = Rc::new(RefCell::new(Vec::new()));
    let captured = captures.clone();
    backend
        .borrow_mut()
        .set_job_observer(Some(Box::new(move |observation| {
            let Some((FfxEffect::FrameInterpolation, pass)) = observation.pass else {
                return;
            };
            let binding = if pass == FfxFrameInterpolationPass::GameMotionVectorField as u32
                || pass == FfxFrameInterpolationPass::ReconstructOutgoingGeometry as u32
            {
                "rw_game_motion_vector_field_y"
            } else if pass == FfxFrameInterpolationPass::DisocclusionMask as u32
                || pass == FfxFrameInterpolationPass::DisocclusionWithCameraVisibility as u32
            {
                "rw_disocclusion_mask"
            } else {
                return;
            };
            if observation.after {
                let field = observation
                    .resources
                    .iter()
                    .find(|r| r.binding == binding)
                    .unwrap();
                let readback = match field.object {
                    FfxWgpuObject::Buffer(buffer) => {
                        readback::Readback::buffer(observation.device, observation.encoder, buffer)
                    }
                    FfxWgpuObject::Texture(texture) => readback::Readback::texture(
                        observation.device,
                        observation.encoder,
                        texture,
                        0,
                    ),
                };
                captured.borrow_mut().push((pass, readback));
            }
        })));
    let flags =
        FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE;
    let size = FfxDimensions2D {
        width: WIDTH,
        height: HEIGHT,
    };
    let mut context = FfxFrameInterpolationContext::default();
    ffx_frame_interpolation_context_create(
        &mut context,
        &FfxFrameInterpolationContextDescription {
            flags,
            max_render_size: size,
            display_size: size,
            back_buffer_format: FfxSurfaceFormat::R16G16B16A16Float,
            previous_interpolation_source_format: FfxSurfaceFormat::R16G16B16A16Float,
            backend_interface: backend.clone(),
        },
    )
    .unwrap();
    let depth = texture(device, wgpu::TextureFormat::R32Float, WIDTH, HEIGHT);
    let motion = texture(device, wgpu::TextureFormat::Rg16Float, WIDTH, HEIGHT);
    let dilated_depth = texture(device, wgpu::TextureFormat::R32Float, WIDTH, HEIGHT);
    let dilated_motion = texture(device, wgpu::TextureFormat::Rg16Float, WIDTH, HEIGHT);
    let reconstructed = texture(device, wgpu::TextureFormat::R32Uint, WIDTH, HEIGHT);
    let color = texture(device, wgpu::TextureFormat::Rgba16Float, WIDTH, HEIGHT);
    let output = texture(device, wgpu::TextureFormat::Rgba16Float, WIDTH, HEIGHT);
    let optical = texture(device, wgpu::TextureFormat::Rg16Sint, WIDTH / 8, HEIGHT / 8);
    let scd = texture(device, wgpu::TextureFormat::R32Uint, 3, 1);
    let distortion = texture(device, wgpu::TextureFormat::Rg16Float, 1, 1);
    let mut frames = Vec::new();
    // Repeat the same physical camera sequence after reset: no retained depth
    // or older pose may leak into the new sequence's first two frames.
    let continuous = matches!(
        scene,
        Scene::BrightnessContinuity | Scene::DistortionTransition
    );
    let count = if matches!(scene, Scene::BrightnessContinuity) {
        14
    } else {
        6
    };
    for frame in 0..count {
        let step = if continuous { frame } else { frame % 3 };
        let camera_step = if expansion { 7.0 } else { 2.0 };
        let world_plane_z = if expansion { 16.0 } else { 8.0 };
        let camera_z = if matches!(scene, Scene::BrightnessContinuity) {
            0.0
        } else if matches!(scene, Scene::DistortionTransition) {
            frame as f32 * 0.25
        } else {
            step as f32 * camera_step
        };
        let camera_y = if matches!(scene, Scene::BrightnessContinuity) {
            frame as f32 * 6.4
        } else {
            0.0
        };
        let plane_z = world_plane_z - camera_z;
        let mut depths = Vec::new();
        let mut motions = Vec::new();
        let mut colors = Vec::new();
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let uv = [
                    (x as f32 + 0.5) / WIDTH as f32,
                    (y as f32 + 0.5) / HEIGHT as f32,
                ];
                let foreground = (dynamic && y >= 40)
                    || (matches!(scene, Scene::MovingOccluder)
                        && step < 2
                        && (32..64).contains(&x)
                        && y >= 32);
                // A nearer static half-plane ends at world Y=-1.8375. Its
                // projected boundary moves with the camera, independently of
                // the mesh implementation. After the SDK's nearest dilation,
                // the previous foreground starts at source y=38.5.
                let static_front_z = 15.4 - camera_z;
                let depth_step =
                    matches!(scene, Scene::DepthStep) && uv[1] >= 0.5 + 0.91875 / static_front_z;
                let surface_z = if foreground {
                    3.0
                } else if depth_step {
                    static_front_z
                } else {
                    plane_z
                };
                depths.extend((1.0 / surface_z).to_le_bytes());
                for (axis, v) in uv.into_iter().enumerate() {
                    let mv = if foreground || step == 0 {
                        0.0
                    } else if matches!(scene, Scene::BrightnessContinuity) {
                        if axis == 1 { -0.4 } else { 0.0 }
                    } else if matches!(scene, Scene::DistortionTransition) {
                        -(v - 0.5) * 0.25 / (surface_z + 0.25)
                    } else {
                        -(v - 0.5) * camera_step / (surface_z + camera_step)
                    };
                    motions.extend(
                        (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(mv) as u16).to_le_bytes(),
                    );
                }
                // A world-anchored linear color ramp on the plane. No image-based
                // assertion: this is input to the real interpolation pipeline.
                let color = if matches!(scene, Scene::BrightnessContinuity) {
                    let value = 0.1 + uv[1] * if frame % 2 == 0 { 0.2 } else { 0.8 };
                    [value, value, value, 1.0]
                } else if matches!(scene, Scene::MovingOccluder) {
                    if foreground {
                        [0.9, 0.1, 0.1, 1.0]
                    } else {
                        [0.1, 0.3, 0.8, 1.0]
                    }
                } else {
                    [
                        0.25,
                        0.5 + (uv[1] - 0.5) * plane_z / world_plane_z,
                        0.75,
                        1.0,
                    ]
                };
                for v in color {
                    colors.extend(
                        (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(v) as u16).to_le_bytes(),
                    );
                }
            }
        }
        upload(queue, &depth, &depths);
        upload(queue, &motion, &motions);
        upload(queue, &color, &colors);
        let command_list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        let resource = |texture: &wgpu::Texture| {
            backend.borrow_mut().ffx_get_resource_wgpu(
                texture,
                "analytic scene",
                FFX_RESOURCE_STATE_COMPUTE_READ,
            )
        };
        let prepared = FfxFrameInterpolationPrepareDescription {
            command_list,
            render_size: size,
            frame_id: frame,
            frame_time_delta: 16.0,
            motion_vector_scale: FfxFloatCoords2D {
                x: WIDTH as f32,
                y: HEIGHT as f32,
            },
            // SDK reverse-infinite convention used by SGL, not near < far.
            camera_near: f32::MAX,
            camera_far: 1.0,
            camera_fov_angle_vertical: std::f32::consts::FRAC_PI_2,
            view_space_to_meters_factor: 1.0,
            depth: resource(&depth),
            motion_vectors: resource(&motion),
            dilated_depth: resource(&dilated_depth),
            dilated_motion_vectors: resource(&dilated_motion),
            reconstructed_prev_depth: resource(&reconstructed),
            camera_position: [0.0, camera_y, camera_z],
            camera_right: if camera { [1.0, 0.0, 0.0] } else { [0.0; 3] },
            camera_up: if camera { [0.0, 1.0, 0.0] } else { [0.0; 3] },
            camera_forward: if camera { [0.0, 0.0, 1.0] } else { [0.0; 3] },
            ..Default::default()
        };
        ffx_frame_interpolation_prepare(&mut context, &prepared).unwrap();
        ffx_frame_interpolation_dispatch(
            &mut context,
            &FfxFrameInterpolationDispatchDescription {
                command_list,
                render_size: size,
                display_size: size,
                frame_id: frame,
                reset: step == 0,
                current_back_buffer: resource(&color),
                output: resource(&output),
                interpolation_rect: FfxRect2D {
                    left: 0,
                    top: 0,
                    width: WIDTH as i32,
                    height: HEIGHT as i32,
                },
                optical_flow_vector: resource(&optical),
                optical_flow_scene_change_detection: resource(&scd),
                optical_flow_buffer_size: FfxDimensions2D {
                    width: WIDTH / 8,
                    height: HEIGHT / 8,
                },
                optical_flow_scale: FfxFloatCoords2D {
                    x: 1.0 / WIDTH as f32,
                    y: 1.0 / HEIGHT as f32,
                },
                optical_flow_block_size: 8,
                camera_near: f32::MAX,
                camera_far: 1.0,
                camera_fov_angle_vertical: std::f32::consts::FRAC_PI_2,
                view_space_to_meters_factor: 1.0,
                frame_time_delta: 16.0,
                min_max_luminance: [0.0, 1000.0],
                dilated_depth: resource(&dilated_depth),
                dilated_motion_vectors: resource(&dilated_motion),
                reconstructed_prev_depth: resource(&reconstructed),
                distortion_field: if matches!(scene, Scene::DistortionTransition) && frame == 2 {
                    resource(&distortion)
                } else {
                    Default::default()
                },
                ..Default::default()
            },
        )
        .unwrap();
        assert!(
            backend.borrow_mut().take_job_error().is_none(),
            "GPU job validation"
        );
        let mut encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(command_list)
            .unwrap();
        let color_readback = readback::Readback::texture(device, &mut encoder, &output, 0);
        queue.submit([encoder.finish()]);
        let items = captures.borrow_mut().drain(..).collect::<Vec<_>>();
        let (passes, readbacks): (Vec<_>, Vec<_>) = items.into_iter().unzip();
        let bytes = readback::Readback::read_all(device, readbacks);
        let color_bytes = readback::Readback::read_all(device, vec![color_readback])
            .pop()
            .unwrap();
        let mut result = Frame {
            game: Vec::new(),
            edge: None,
            visibility: Vec::new(),
            color: color_bytes
                .chunks_exact(2)
                .map(|w| u16::from_le_bytes(w.try_into().unwrap()))
                .collect(),
        };
        for (pass, data) in passes.into_iter().zip(bytes) {
            if pass == FfxFrameInterpolationPass::DisocclusionMask as u32
                || pass == FfxFrameInterpolationPass::DisocclusionWithCameraVisibility as u32
            {
                result.visibility = data;
                continue;
            }
            let values = data
                .chunks_exact(4)
                .map(|w| u32::from_le_bytes(w.try_into().unwrap()))
                .collect();
            if pass == FfxFrameInterpolationPass::GameMotionVectorField as u32 {
                result.game = values;
            } else {
                result.edge = Some(values);
            }
        }
        frames.push(result);
    }
    ffx_frame_interpolation_context_destroy(&mut context).unwrap();
    frames
}

#[test]
fn outgoing_geometry_reconstructs_a_translated_plane_and_resets_history() {
    // Defect: extrapolating a boundary vector instead of projecting outgoing
    // geometry. Independently solve the plane's UV scale: old z=9, new z=2,
    // current UV = .5 + 4.5*(previous UV-.5), midpoint scale=2.75.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let original = sequence(&device, &queue, false, Scene::ExpandedPlane);
    let reconstructed = sequence(&device, &queue, true, Scene::ExpandedPlane);
    // This 2.75x source-cell expansion exceeds the old fixed 2x2 splat.
    // Every destination center in this band lies on the same analytic plane.
    let field = reconstructed[2].edge.as_ref().unwrap();
    for y in 54..HEIGHT {
        for x in 8..WIDTH - 8 {
            assert_eq!(
                field[(y * WIDTH + x) as usize] >> 31,
                1,
                "outgoing plane coverage hole at {x},{y}"
            );
        }
    }
    let pixel = (62 * WIDTH + WIDTH / 2) as usize;
    let old = original[2].game[pixel];
    let new = reconstructed[2].game[pixel];
    assert_eq!(
        old >> 31,
        0,
        "AMD field has no primary coverage at the outgoing edge"
    );
    assert_eq!(
        new >> 31,
        1,
        "retained geometry must supply primary coverage"
    );
    let midpoint_y = (62.5 / HEIGHT as f32 - 0.5) / 2.75 + 0.5;
    let expected = midpoint_y - 62.5 / HEIGHT as f32;
    let actual = unpack_half(new as u16);
    let baseline = unpack_half(old as u16);
    assert!(
        (actual - expected).abs() < 0.6 / HEIGHT as f32,
        "analytic midpoint expected {expected}, got {actual}"
    );
    assert!(
        (baseline - expected).abs() > 0.6 / HEIGHT as f32,
        "baseline must expose the extrapolation error: {baseline} versus {expected}"
    );
    // The existing interpolation/disocclusion/inpainting passes must actually
    // consume this new vector. The plane ramp is world anchored: G=.5+(uv-.5)*z/16.
    let expected_green = 0.5 + (midpoint_y - 0.5) * 9.0 / 16.0;
    let actual_green = unpack_half(reconstructed[2].color[pixel * 4 + 1]);
    let baseline_green = unpack_half(original[2].color[pixel * 4 + 1]);
    let tolerance = 0.6 / HEIGHT as f32 * 9.0 / 16.0 + 0.0005;
    assert!(
        (actual_green - expected_green).abs() < tolerance,
        "plane color expected {expected_green}, got {actual_green}"
    );
    assert!(
        (baseline_green - expected_green).abs() > tolerance,
        "original edge color should expose the incorrect warp: {baseline_green} vs {expected_green}"
    );
    for (index, frame) in reconstructed.iter().enumerate() {
        assert_eq!(
            frame.edge.is_some(),
            index % 3 == 2,
            "history activation/reset at frame {index}"
        );
    }
}

#[test]
fn outgoing_geometry_rejects_camera_attached_dynamic_foreground() {
    // Camera translation predicts substantial screen motion for the foreground
    // depth, but its actual game MV is zero. Reprojecting it as static would
    // inject a false primary vector at the outgoing bottom edge.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let frames = sequence(&device, &queue, true, Scene::AttachedForeground);
    for index in [2, 5] {
        let pixel = (62 * WIDTH + WIDTH / 2) as usize;
        assert_eq!(
            frames[index].edge.as_ref().unwrap()[pixel],
            0,
            "dynamic surface leaked into the outgoing geometry pass"
        );
        assert_eq!(
            unpack_half(frames[index].game[pixel] as u16),
            0.0,
            "the actual camera-attached foreground must retain zero motion"
        );
    }
}

#[test]
fn outgoing_geometry_does_not_connect_separate_static_surfaces() {
    // Camera Z advances 0,7,14. Background world Z=16 gives midpoint scale
    // (1+9/2)/2=2.75; foreground world Z=15.4 gives (1+8.4/1.4)/2=3.5.
    // After depth dilation, background ends at source y=37.5 -> midpoint
    // y=47.125, while foreground begins at y=38.5 -> midpoint y=54.75.
    // Rows 51..53 are therefore a genuine unsupported gap, not a surface
    // to create by joining vertices on opposite sides of the depth step.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let frames = sequence(&device, &queue, true, Scene::DepthStep);
    for frame in [2, 5] {
        let field = frames[frame].edge.as_ref().unwrap();
        for y in 51..54 {
            assert_eq!(
                field[(y * WIDTH + WIDTH / 2) as usize],
                0,
                "invented a surface across a depth discontinuity at row {y}"
            );
        }
        assert_ne!(
            field[(60 * WIDTH + WIDTH / 2) as usize] >> 31,
            0,
            "the visible foreground must still reconstruct beyond the gap"
        );
    }
}

#[test]
fn actual_previous_depth_rejects_a_moving_occluder_over_newly_visible_plane() {
    // The old camera-attached red object is at view Z=3; the blue static
    // plane moves from previous-view Z=6 to current-view Z=4 as the camera
    // advances. The object leaves the view. Reconstructing previous depth
    // from the current plane falsely declares both colors visible.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let original = sequence(&device, &queue, false, Scene::MovingOccluder);
    let corrected = sequence(&device, &queue, true, Scene::MovingOccluder);
    for frame in [2, 5] {
        let pixel = (40 * WIDTH + WIDTH / 2) as usize;
        assert_eq!(
            &original[frame].visibility[pixel * 2..pixel * 2 + 2],
            &[255, 255]
        );
        assert_eq!(
            &corrected[frame].visibility[pixel * 2..pixel * 2 + 2],
            &[0, 255],
            "the old object occludes only the previous source"
        );
        let red = unpack_half(corrected[frame].color[pixel * 4]);
        let old_red = unpack_half(original[frame].color[pixel * 4]);
        assert!(
            (red - 0.1).abs() < 0.002,
            "newly visible blue plane contains old red object: {red}"
        );
        assert!(
            old_red > red + 0.2,
            "fixture must expose the original occlusion error"
        );
        let outgoing = (62 * WIDTH + WIDTH / 2) as usize;
        assert_eq!(
            corrected[frame].game[outgoing] >> 31,
            0,
            "the outgoing gap has no current or retained static primary geometry"
        );
        assert_eq!(
            corrected[frame].visibility[outgoing * 2],
            0,
            "an extrapolated secondary vector must not drag the old moving object into the gap"
        );
    }
}

#[test]
fn aligned_source_brightness_stays_continuous_when_one_source_leaves_view() {
    // Constant vertical translation on a plane, but the two source images
    // have different smooth brightness ramps. Zero optical flow yields a
    // different candidate from the geometry warp. Run past SDK warmup so the
    // game/OF bias participates: feathering only color t still leaves a jump.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let original = sequence(&device, &queue, false, Scene::BrightnessContinuity);
    let feathered = sequence(&device, &queue, true, Scene::BrightnessContinuity);
    let peak_jump = |frame: &Frame| {
        (49..54)
            .map(|y| {
                let a = unpack_half(frame.color[((y * WIDTH + WIDTH / 2) * 4) as usize]);
                let b = unpack_half(frame.color[(((y + 1) * WIDTH + WIDTH / 2) * 4) as usize]);
                (b - a).abs()
            })
            .fold(0.0f32, f32::max)
    };
    let old_jump = peak_jump(original.last().unwrap());
    let new_jump = peak_jump(feathered.last().unwrap());
    assert!(
        old_jump > 0.05,
        "fixture must expose the visible original step: {old_jump}"
    );
    assert!(
        new_jump < 0.03,
        "smooth source ramps acquire a discontinuity at the boundary: {new_jump}"
    );
}

#[test]
fn a_distorted_source_invalidates_camera_history_until_clean_frames_arrive() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let frames = sequence(&device, &queue, true, Scene::DistortionTransition);
    // Frame 2 supplies a distortion field; 3 and 4 rebuild the two clean
    // prior frames. Reusing the warped frame as camera history would make
    // the extra pass appear prematurely at frame 3.
    for (index, frame) in frames.iter().enumerate() {
        assert_eq!(
            frame.edge.is_some(),
            index == 5,
            "camera history crossed a distorted source at frame {index}"
        );
    }
}
