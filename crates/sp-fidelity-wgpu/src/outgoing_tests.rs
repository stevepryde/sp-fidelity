//! Analytic GPU checks for the Rust/WGSL outgoing reconstruction correction.
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
    depth_before_current: Vec<u32>,
    depth_after_current: Vec<u32>,
}

enum Scene {
    ExpandedPlane,
    ContractingPlane,
    AttachedForeground,
    CoplanarMotion,
    RecedingDistortion,
    DepthStep,
    Ground,
    GroundUpscaled,
    GroundReceding,
    GroundRecedingFast,
    GroundPitched,
    JitteredFinitePlane,
    PreviousDistortion,
    CurrentDistortion,
    HighResolutionMotion,
    HistoryGap,
    MissingCamera,
}
fn sequence(device: &wgpu::Device, queue: &wgpu::Queue, camera: bool, scene: Scene) -> Vec<Frame> {
    let ground = matches!(
        scene,
        Scene::Ground
            | Scene::GroundUpscaled
            | Scene::GroundPitched
            | Scene::GroundReceding
            | Scene::GroundRecedingFast
    );
    let receding = matches!(scene, Scene::GroundReceding | Scene::GroundRecedingFast);
    let upscaled = matches!(scene, Scene::GroundUpscaled | Scene::GroundPitched);
    let pitch = if matches!(scene, Scene::GroundPitched) {
        12f32.to_radians()
    } else {
        0.0
    };
    let (sin_pitch, cos_pitch) = pitch.sin_cos();
    let (width, height) = if ground { (1200, 750) } else { (WIDTH, HEIGHT) };
    let high_motion = matches!(scene, Scene::HighResolutionMotion);
    let (display_width, display_height) = if upscaled {
        (1920, 1200)
    } else if high_motion {
        (width * 2, height * 2)
    } else {
        (width, height)
    };
    let display = FfxDimensions2D {
        width: display_width,
        height: display_height,
    };
    let fov = if ground {
        80f32.to_radians()
    } else {
        std::f32::consts::FRAC_PI_2
    };
    let near = if ground { 0.3 } else { 1.0 };
    let finite = matches!(scene, Scene::JitteredFinitePlane);
    let distortion_test = matches!(
        scene,
        Scene::PreviousDistortion | Scene::CurrentDistortion | Scene::RecedingDistortion
    );
    let (backend, _) = ffx_get_interface_wgpu(device);
    let captured = Rc::new(RefCell::new(Vec::new()));
    let captures = captured.clone();
    backend
        .borrow_mut()
        .set_job_observer(Some(Box::new(move |observation| {
            let Some((FfxEffect::FrameInterpolation, pass)) = observation.pass else {
                return;
            };
            if !observation.after
                || ![
                    FfxFrameInterpolationPass::GameMotionVectorField as u32,
                    FfxFrameInterpolationPass::ReconstructPrevDepth as u32,
                    FfxFrameInterpolationPass::ReconstructOutgoingGeometry as u32,
                    FfxFrameInterpolationPass::ResolveOutgoingGeometry as u32,
                    FfxFrameInterpolationPass::ResolveCurrentGeometry as u32,
                ]
                .contains(&pass)
            {
                return;
            }
            for resource in observation.resources.iter().filter(|r| {
                r.binding == "rw_game_motion_vector_field_y"
                    || (r.binding == "rw_reconstructed_depth_interpolated_frame"
                        && [
                            FfxFrameInterpolationPass::ReconstructPrevDepth as u32,
                            FfxFrameInterpolationPass::ResolveCurrentGeometry as u32,
                        ]
                        .contains(&pass))
            }) {
                let data = match resource.object {
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
                captures.borrow_mut().push((
                    (
                        pass,
                        resource.description.width,
                        resource.binding.to_owned(),
                    ),
                    data,
                ));
            }
        })));
    let size = FfxDimensions2D { width, height };
    let mut context = FfxFrameInterpolationContext::default();
    ffx_frame_interpolation_context_create(
        &mut context,
        &FfxFrameInterpolationContextDescription {
            flags: (if high_motion {
                FFX_FRAMEINTERPOLATION_ENABLE_DISPLAY_RESOLUTION_MOTION_VECTORS
            } else {
                0
            }) | FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INVERTED
                | if finite {
                    0
                } else {
                    FFX_FRAMEINTERPOLATION_ENABLE_DEPTH_INFINITE
                },
            max_render_size: if distortion_test {
                FfxDimensions2D {
                    width: width * 2,
                    height: height * 2,
                }
            } else {
                size
            },
            display_size: display,
            back_buffer_format: FfxSurfaceFormat::R16G16B16A16Float,
            previous_interpolation_source_format: FfxSurfaceFormat::R16G16B16A16Float,
            backend_interface: backend.clone(),
        },
    )
    .unwrap();
    let depth = texture(device, wgpu::TextureFormat::R32Float, width, height);
    let motion = texture(
        device,
        wgpu::TextureFormat::Rg16Float,
        if high_motion { display_width } else { width },
        if high_motion { display_height } else { height },
    );
    let dilated_depth = texture(device, wgpu::TextureFormat::R32Float, width, height);
    let dilated_motion = texture(device, wgpu::TextureFormat::Rg16Float, width, height);
    let reconstructed = texture(device, wgpu::TextureFormat::R32Uint, width, height);
    let color = texture(
        device,
        wgpu::TextureFormat::Rgba16Float,
        display_width,
        display_height,
    );
    let output = texture(
        device,
        wgpu::TextureFormat::Rgba16Float,
        display_width,
        display_height,
    );
    let optical = texture(
        device,
        wgpu::TextureFormat::Rg16Sint,
        display_width / 8,
        display_height / 8,
    );
    let scd = texture(device, wgpu::TextureFormat::R32Uint, 3, 1);
    let distortion = texture(device, wgpu::TextureFormat::Rg16Float, width, height);
    let mut frames = Vec::new();
    for frame in 0..6 {
        let step = frame % 3;
        let frame_id = if matches!(scene, Scene::HistoryGap) && frame >= 2 {
            frame + 1
        } else {
            frame
        };
        let jitter = if finite || upscaled {
            [0.25 - step as f32 * 0.125, -0.375 + step as f32 * 0.25]
        } else {
            [0.0; 2]
        };
        let camera_valid = camera && !(matches!(scene, Scene::MissingCamera) && step == 1);
        let expanding = !matches!(scene, Scene::AttachedForeground);
        let camera_step = if matches!(scene, Scene::CoplanarMotion) {
            0.0
        } else if matches!(scene, Scene::ContractingPlane | Scene::RecedingDistortion) {
            if step == 2 { -7.0 } else { -0.5 }
        } else if matches!(scene, Scene::GroundRecedingFast) {
            -4.0
        } else if receding {
            -1.0
        } else if ground {
            4.0
        } else if expanding {
            7.0
        } else {
            2.0
        };
        let world_plane_z = if expanding { 16.0 } else { 8.0 };
        let camera_z = if matches!(scene, Scene::ContractingPlane | Scene::RecedingDistortion) {
            [14.5, 14.0, 7.0][step as usize]
        } else {
            step as f32 * camera_step
        };
        let plane_z = world_plane_z - camera_z;
        let mut depths = Vec::new();
        let mut motions = Vec::new();
        let mut colors = Vec::new();
        for y in 0..height {
            for x in 0..width {
                let uv = [
                    (x as f32 + 0.5) / width as f32,
                    (y as f32 + 0.5) / height as f32,
                ];
                let geometry_uv = [
                    uv[0] - jitter[0] / width as f32,
                    uv[1] - jitter[1] / height as f32,
                ];
                let dynamic =
                    matches!(scene, Scene::AttachedForeground | Scene::CoplanarMotion) && y >= 40;
                let front_z = 15.4 - camera_z;
                let front = matches!(scene, Scene::DepthStep) && uv[1] >= 0.5 + 0.91875 / front_z;
                let z = if ground {
                    2.0 / (sin_pitch + cos_pitch * (geometry_uv[1] - 0.5) * 2.0 * (fov * 0.5).tan())
                } else if dynamic && !matches!(scene, Scene::CoplanarMotion) {
                    3.0
                } else if front {
                    front_z
                } else {
                    plane_z
                };
                let depth = if ground && z <= near {
                    0.0
                } else {
                    if finite {
                        near * (100.0 / z - 1.0) / 99.0
                    } else {
                        near / z
                    }
                };
                depths.extend(depth.to_le_bytes());
                for (axis, value) in geometry_uv.into_iter().enumerate() {
                    let mv = if dynamic || step == 0 || (ground && z <= near) {
                        0.0
                    } else if matches!(scene, Scene::CoplanarMotion) {
                        if axis == 1 { 2.0 / height as f32 } else { 0.0 }
                    } else {
                        -(cos_pitch * (value - 0.5)
                            + if ground && axis == 1 {
                                sin_pitch / (2.0 * (fov * 0.5).tan())
                            } else {
                                0.0
                            })
                            * camera_step
                            / (z + cos_pitch * camera_step).max(1e-6)
                    };
                    motions.extend(
                        (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(mv.clamp(-2.0, 2.0)) as u16)
                            .to_le_bytes(),
                    );
                }
                for value in [
                    0.25,
                    if ground {
                        (0.02 * (camera_z + z)).clamp(0.0, 1.0)
                    } else {
                        0.5 + (uv[1] - 0.5) * plane_z / world_plane_z
                    },
                    0.75,
                    1.0,
                ] {
                    colors.extend(
                        (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16).to_le_bytes(),
                    );
                }
            }
        }
        if ground {
            colors.clear();
            for y in 0..display_height {
                for _x in 0..display_width {
                    let ky =
                        ((y as f32 + 0.5) / display_height as f32 - 0.5) * 2.0 * (fov * 0.5).tan();
                    let z = 2.0 / (sin_pitch + cos_pitch * ky);
                    let world_z = camera_z + (cos_pitch - sin_pitch * ky) * z;
                    let rgb = if z <= near {
                        [0.2, 0.1, 0.4]
                    } else {
                        [
                            0.5 + 0.3 * (world_z * 3.0).sin(),
                            (0.02 * (world_z + if receding { 10.0 } else { 0.0 })).clamp(0.0, 1.0),
                            0.75,
                        ]
                    };
                    for value in [rgb[0], rgb[1], rgb[2], 1.0] {
                        colors.extend(
                            (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16)
                                .to_le_bytes(),
                        );
                    }
                }
            }
        }
        if high_motion {
            motions.clear();
            colors.clear();
            for y in 0..display_height {
                for x in 0..display_width {
                    let uv = [
                        (x as f32 + 0.5) / display_width as f32,
                        (y as f32 + 0.5) / display_height as f32,
                    ];
                    for value in uv {
                        let mv = if step == 0 {
                            0.0
                        } else {
                            -(value - 0.5) * camera_step / (plane_z + camera_step)
                        };
                        motions.extend(
                            (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(mv.clamp(-2.0, 2.0))
                                as u16)
                                .to_le_bytes(),
                        );
                    }
                    for value in [
                        0.25,
                        0.5 + (uv[1] - 0.5) * plane_z / world_plane_z,
                        0.75,
                        1.0,
                    ] {
                        colors.extend(
                            (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16)
                                .to_le_bytes(),
                        );
                    }
                }
            }
        }
        upload(queue, &depth, &depths);
        upload(queue, &motion, &motions);
        upload(queue, &color, &colors);
        // Cover only the lower-right source quadrant. With a larger allocation,
        // sampling history in allocation UVs incorrectly reads the zero quadrant.
        let distorted = (matches!(scene, Scene::PreviousDistortion | Scene::RecedingDistortion)
            && step == 1)
            || (matches!(scene, Scene::CurrentDistortion) && step == 2);
        let mut offsets = Vec::new();
        for y in 0..height {
            for x in 0..width {
                for value in [
                    if distorted && x >= width / 2 && y >= height / 2 {
                        0.01
                    } else {
                        0.0
                    },
                    0.0,
                ] {
                    offsets.extend(
                        (sp_fidelity::gpu::core_cpu::ffx_f32_to_f16(value) as u16).to_le_bytes(),
                    );
                }
            }
        }
        upload(queue, &distortion, &offsets);
        let list = backend
            .borrow_mut()
            .ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        let resource = |t: &wgpu::Texture| {
            backend.borrow_mut().ffx_get_resource_wgpu(
                t,
                "analytic scene",
                FFX_RESOURCE_STATE_COMPUTE_READ,
            )
        };
        ffx_frame_interpolation_prepare(
            &mut context,
            &FfxFrameInterpolationPrepareDescription {
                command_list: list,
                render_size: size,
                frame_id,
                frame_time_delta: 16.0,
                motion_vector_scale: FfxFloatCoords2D {
                    x: if high_motion { display_width } else { width } as f32,
                    y: if high_motion { display_height } else { height } as f32,
                },
                camera_near: if finite { 100.0 } else { f32::MAX },
                camera_far: near,
                camera_fov_angle_vertical: fov,
                view_space_to_meters_factor: 1.0,
                depth: resource(&depth),
                motion_vectors: resource(&motion),
                dilated_depth: resource(&dilated_depth),
                dilated_motion_vectors: resource(&dilated_motion),
                reconstructed_prev_depth: resource(&reconstructed),
                jitter_offset: FfxFloatCoords2D {
                    x: jitter[0],
                    y: jitter[1],
                },
                camera_position: [
                    0.0,
                    if ground {
                        2.0
                    } else if matches!(scene, Scene::CoplanarMotion) {
                        -(step as f32)
                    } else {
                        0.0
                    },
                    camera_z,
                ],
                camera_right: if camera_valid {
                    [1.0, 0.0, 0.0]
                } else {
                    [0.0; 3]
                },
                camera_up: if camera_valid {
                    [0.0, cos_pitch, sin_pitch]
                } else {
                    [0.0; 3]
                },
                camera_forward: if camera_valid {
                    [0.0, -sin_pitch, cos_pitch]
                } else {
                    [0.0; 3]
                },
                ..Default::default()
            },
        )
        .unwrap();
        ffx_frame_interpolation_dispatch(
            &mut context,
            &FfxFrameInterpolationDispatchDescription {
                command_list: list,
                render_size: size,
                display_size: display,
                frame_id,
                reset: step == 0,
                back_buffer_transfer_function: FfxBackbufferTransferFunction::Srgb,
                current_back_buffer: resource(&color),
                distortion_field: resource(&distortion),
                output: resource(&output),
                interpolation_rect: FfxRect2D {
                    left: 0,
                    top: 0,
                    width: display_width as i32,
                    height: display_height as i32,
                },
                optical_flow_vector: resource(&optical),
                optical_flow_scene_change_detection: resource(&scd),
                optical_flow_buffer_size: FfxDimensions2D {
                    width: display_width / 8,
                    height: display_height / 8,
                },
                optical_flow_scale: FfxFloatCoords2D {
                    x: 1.0 / display_width as f32,
                    y: 1.0 / display_height as f32,
                },
                optical_flow_block_size: 8,
                camera_near: if finite { 100.0 } else { f32::MAX },
                camera_far: near,
                camera_fov_angle_vertical: fov,
                view_space_to_meters_factor: 1.0,
                frame_time_delta: 16.0,
                min_max_luminance: [0.0, 1000.0],
                dilated_depth: resource(&dilated_depth),
                dilated_motion_vectors: resource(&dilated_motion),
                reconstructed_prev_depth: resource(&reconstructed),
                ..Default::default()
            },
        )
        .unwrap();
        assert_eq!(backend.borrow_mut().take_job_error(), None);
        let mut encoder = backend
            .borrow_mut()
            .ffx_take_command_list_wgpu(list)
            .unwrap();
        let color_readback = readback::Readback::texture(device, &mut encoder, &output, 0);
        queue.submit([encoder.finish()]);
        let (passes, readbacks): (Vec<_>, Vec<_>) = captured.borrow_mut().drain(..).unzip();
        let data = readback::Readback::read_all(device, readbacks);
        let color_data = readback::Readback::read_all(device, vec![color_readback])
            .pop()
            .unwrap();
        let mut result = Frame {
            game: Vec::new(),
            edge: None,
            depth_before_current: Vec::new(),
            depth_after_current: Vec::new(),
            color: color_data
                .chunks_exact(2)
                .map(|w| u16::from_le_bytes(w.try_into().unwrap()))
                .collect(),
        };
        for ((pass, stride, binding), bytes) in passes.into_iter().zip(data) {
            let values: Vec<u32> = bytes
                .chunks_exact(stride as usize * 4)
                .take(height as usize)
                .flat_map(|row| row[..width as usize * 4].chunks_exact(4))
                .map(|w| u32::from_le_bytes(w.try_into().unwrap()))
                .collect();
            if binding == "rw_reconstructed_depth_interpolated_frame" {
                if pass == FfxFrameInterpolationPass::ResolveCurrentGeometry as u32 {
                    result.depth_after_current = values;
                } else {
                    result.depth_before_current = values;
                }
            } else if pass == FfxFrameInterpolationPass::ReconstructOutgoingGeometry as u32 {
                result.edge = Some(values);
            } else {
                if pass == FfxFrameInterpolationPass::ResolveOutgoingGeometry as u32 {
                    for (before, after) in result.game.iter().zip(&values) {
                        if before >> 31 != 0 {
                            assert_eq!(before, after, "changed an upstream primary");
                        }
                    }
                }
                result.game = values;
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
    // Raw background ends at source y=38.5 -> midpoint y=49.875,
    // while foreground begins at y=39.5 -> midpoint y=58.25.
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
fn outgoing_ground_matches_the_independent_perspective_reference() {
    // The upstream issue's actual size and camera step: current-only sources
    // supply <=117px, while the endpoint-linear ground projection needs171px.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let baseline = sequence(&device, &queue, false, Scene::Ground);
    let corrected = sequence(&device, &queue, true, Scene::Ground);
    let (width, height) = (1200usize, 750usize);
    for frame in [2, 5] {
        for y in 660..741 {
            let v = (y as f64 + 0.5) / height as f64;
            let a = (v - 0.5) * 40f64.to_radians().tan();
            let z = (1.0 - 4.0 * a + (1.0 + 16.0 * a * a).sqrt()) / (2.0 * a);
            let expected = -(v - 0.5) * 4.0 / (2.0 * z + 4.0);
            for x in (50..width - 50).step_by(31) {
                let pixel = y * width + x;
                let packed = corrected[frame].game[pixel];
                assert_ne!(packed >> 31, 0, "ground coverage hole at {x},{y}");
                let actual = unpack_half(packed as u16) as f64;
                assert!(
                    (actual - expected).abs() * (height as f64) < 0.5,
                    "ground motion at {x},{y}: got {}px, need {}px",
                    actual * height as f64,
                    expected * height as f64
                );
            }
        }
        let pixel = 700 * width + 600;
        let v = 700.5 / 750.0f64;
        let a = (v - 0.5) * 40f64.to_radians().tan();
        let z = (1.0 - 4.0 * a + (1.0 + 16.0 * a * a).sqrt()) / (2.0 * a);
        let expected = -(v - 0.5) * 4.0 / (2.0 * z + 4.0);
        let original = unpack_half(baseline[frame].game[pixel] as u16) as f64;
        assert!(
            (original - expected).abs() * 750.0 > 40.0,
            "baseline must expose missing perspective motion"
        );
        // Surface world Z = current camera8 + current-view z. A world-linear
        // color ramp tests the unchanged interpolation pass consumes the field.
        let expected_green = 0.02 * (8.0 + z);
        let green = unpack_half(corrected[frame].color[pixel * 4 + 1]) as f64;
        assert!(
            (green - expected_green).abs() < 0.001,
            "ground color {green}, expected {expected_green}"
        );
    }
}

#[test]
fn outgoing_geometry_respects_finite_depth_and_raster_jitter() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let frames = sequence(&device, &queue, true, Scene::JitteredFinitePlane);
    // A frontoparallel plane projects with z_previous=9 and z_current=2.
    // Endpoint-linear interpolation has scale (1+9/2)/2=2.75.
    for y in 54..HEIGHT - 1 {
        for x in 52..WIDTH - 8 {
            let p = (y * WIDTH + x) as usize;
            let expected = -((y as f32 + 0.5) / HEIGHT as f32 - 0.5) * (1.0 - 1.0 / 2.75);
            assert_ne!(
                frames[2].game[p] >> 31,
                0,
                "missing finite-depth correspondence"
            );
            assert!(
                (unpack_half(frames[2].game[p] as u16) - expected).abs() * (HEIGHT as f32) < 0.05
            );
        }
    }
}

#[test]
fn outgoing_geometry_keeps_fallback_at_distorted_color_lookups() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    for scene in [Scene::PreviousDistortion, Scene::CurrentDistortion] {
        let frames = sequence(&device, &queue, true, scene);
        let warped = (62 * WIDTH + 70) as usize;
        let clean = (62 * WIDTH + 24) as usize;
        assert_ne!(
            frames[2].edge.as_ref().unwrap()[warped] >> 31,
            0,
            "geometry itself supports this point"
        );
        assert_eq!(
            frames[2].game[warped] >> 31,
            0,
            "warped lookup must retain original fallback"
        );
        assert_ne!(
            frames[2].game[clean] >> 31,
            0,
            "clean region should still receive the correction"
        );
    }
}

#[test]
fn outgoing_geometry_discards_nonconsecutive_or_missing_camera_history() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    for scene in [Scene::HistoryGap, Scene::MissingCamera] {
        let frames = sequence(&device, &queue, true, scene);
        assert!(
            frames[2].edge.is_none(),
            "unsafe camera history reached reconstruction"
        );
    }
}

#[test]
fn outgoing_geometry_retains_original_reconstruction_for_display_grid_motion() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    // The HR vector's pixel center describes a different ray from the LR depth.
    // Without depth at that ray, this correction must keep the original path.
    let frames = sequence(&device, &queue, true, Scene::HighResolutionMotion);
    assert!(frames[2].edge.is_none());
    assert_eq!(frames[2].game[(62 * WIDTH + WIDTH / 2) as usize] >> 31, 0);
}

#[test]
fn outgoing_ground_has_no_color_seam_with_upscaling_jitter_and_camera_pitch() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    for (scene, pitch) in [
        (Scene::GroundUpscaled, 0.0f64),
        (Scene::GroundPitched, 12f64.to_radians()),
    ] {
        let frames = sequence(&device, &queue, true, scene);
        let (w, h) = (1920usize, 1200usize);
        if let Some(root) = std::env::var_os("SP_FIDELITY_REPRO_OUTPUT") {
            let root = std::path::PathBuf::from(root);
            std::fs::create_dir_all(&root).unwrap();
            let bytes: Vec<u8> = frames[2]
                .color
                .iter()
                .flat_map(|v| v.to_le_bytes())
                .collect();
            std::fs::write(
                root.join(format!("ground-pitch-{}.rgba16", pitch.to_degrees())),
                bytes,
            )
            .unwrap();
        }
        // Independently intersect a ground point with both cameras. Find its
        // previous-relative world Z from the endpoint-average vertical UV.
        let (sp, cp) = pitch.sin_cos();
        let tan = 40f64.to_radians().tan();
        let mut worst = 0.0f64;
        let mut location = (0, 0);
        for y in 800..h - 1 {
            let v = (y as f64 + 0.5) / h as f64;
            let project = |z: f64| 0.5 + (2.0 * cp - sp * z) / (2.0 * tan * (2.0 * sp + cp * z));
            let mut lo = 4.0 + (0.3 - 2.0 * sp) / cp;
            let mut hi = 1000.0;
            for _ in 0..64 {
                let m = (lo + hi) * 0.5;
                if (project(m) + project(m - 4.0)) * 0.5 > v {
                    lo = m;
                } else {
                    hi = m;
                }
            }
            let world_z = 4.0 + (lo + hi) * 0.5;
            let expected = (0.02 * world_z).clamp(0.0, 1.0);
            for x in (400..w - 400).step_by(23) {
                let actual = unpack_half(frames[2].color[(y * w + x) * 4 + 1]) as f64;
                let error = (actual - expected).abs();
                if error > worst {
                    worst = error;
                    location = (x, y);
                }
            }
        }
        eprintln!("pitched ground {pitch}: max green error {worst} at {location:?}");
        assert!(
            worst < 0.002,
            "perspective ground color seam: pitch={pitch}, error={worst} at {location:?}"
        );
    }
}

#[test]
fn receding_ground_retains_continuous_texture_when_source_samples_expand() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let mut results = Vec::new();
    for (scene, step) in [
        (Scene::GroundReceding, 1.0f64),
        (Scene::GroundRecedingFast, 4.0),
    ] {
        let frames = sequence(&device, &queue, true, scene);
        let (w, h) = (1200usize, 750usize);
        let tan = 40f64.to_radians().tan();
        let project = |z: f64| 0.5 + 1.0 / (tan * z);
        let mut worst = [0.0f64; 2];
        let mut location = [(0, 0); 2];
        let mut worst_motion = [(0.0, 0.0, 0); 2];
        for y in 500..h - 1 {
            let v = (y as f64 + 0.5) / h as f64;
            let (mut lo, mut hi) = (0.3, 1000.0);
            for _ in 0..64 {
                let z = (lo + hi) * 0.5;
                if (project(z) + project(z + step)) * 0.5 > v {
                    lo = z;
                } else {
                    hi = z;
                }
            }
            let world_z = -step + (lo + hi) * 0.5;
            let expected = [0.5 + 0.3 * (world_z * 3.0).sin(), 0.02 * (world_z + 10.0)];
            for x in (300..900).step_by(11) {
                for c in 0..2 {
                    let error = (unpack_half(frames[2].color[(y * w + x) * 4 + c]) as f64
                        - expected[c])
                        .abs();
                    if error > worst[c] {
                        worst[c] = error;
                        location[c] = (x, y);
                        let packed = frames[2].game[y * w + x];
                        worst_motion[c] = (
                            unpack_half(packed as u16) as f64 * h as f64,
                            (project((lo + hi) * 0.5) - v) * h as f64,
                            packed >> 31,
                        );
                    }
                }
            }
        }
        if let Some(root) = std::env::var_os("SP_FIDELITY_REPRO_OUTPUT") {
            std::fs::write(
                std::path::PathBuf::from(root).join(format!("receding-ground-{step}.rgba16")),
                frames[2]
                    .color
                    .iter()
                    .flat_map(|v| v.to_le_bytes())
                    .collect::<Vec<_>>(),
            )
            .unwrap();
        }
        eprintln!(
            "receding ground errors {worst:?} at {location:?}, actual/expected half-motion/primary {worst_motion:?}"
        );
        results.push((step, worst));
    }
    assert!(
        results
            .iter()
            .all(|(_, worst)| worst[0] < 0.035 && worst[1] < 0.002),
        "receding ground seams: {results:?}"
    );
}

#[test]
fn receding_plane_retains_continuous_color_across_primary_splat_gaps() {
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let frames = sequence(&device, &queue, true, Scene::ContractingPlane);
    // The stationary plane is z=2 in the previous camera and z=9 in the
    // current camera. Current pixels expand 2.75x when mapped to the midpoint.
    // All projected endpoints have positive depth; neither is behind a camera.
    let mut worst = 0.0f32;
    let mut location = (0, 0);
    for y in 4..HEIGHT - 4 {
        let expected = 0.5 + ((y as f32 + 0.5) / HEIGHT as f32 - 0.5) * 9.0 / (16.0 * 2.75);
        for x in 4..WIDTH - 4 {
            let error =
                (unpack_half(frames[2].color[((y * WIDTH + x) * 4 + 1) as usize]) - expected).abs();
            if error > worst {
                worst = error;
                location = (x, y);
            }
        }
    }
    eprintln!("contracting plane color error {worst} at {location:?}");
    assert!(
        worst < 0.002,
        "contracting plane seam: {worst} at {location:?}"
    );
}

#[test]
fn current_geometry_preserves_a_camera_attached_coplanar_panel() {
    // Same depth on either side: a static wall moves down two pixels between
    // source frames while a flush panel is camera-attached (zero image motion).
    // A static mesh triangle crosses the panel boundary in the midpoint; depth
    // continuity and a two-pixel vector difference cannot establish staticness.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let baseline = sequence(&device, &queue, false, Scene::CoplanarMotion);
    let corrected = sequence(&device, &queue, true, Scene::CoplanarMotion);
    for index in [2, 5] {
        let pixel = (40 * WIDTH + WIDTH / 2) as usize;
        assert_eq!(
            unpack_half(baseline[index].game[pixel] as u16),
            0.0,
            "control must retain the panel's measured zero motion"
        );
        assert_eq!(
            unpack_half(corrected[index].game[pixel] as u16),
            0.0,
            "static-wall reconstruction must not overwrite independently moving coplanar geometry"
        );
    }
}

#[test]
fn rejected_current_geometry_does_not_change_visibility_depth() {
    // On this expanding midpoint footprint the original point splats leave
    // depth holes. Previous-frame distortion excludes the lower-right region
    // from our mesh correction; rejected cells must not fill those depth holes.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let frames = sequence(&device, &queue, true, Scene::RecedingDistortion);
    for index in [2, 5] {
        let frame = &frames[index];
        let mut original_holes = 0;
        for y in 35..48 {
            for x in 52..70 {
                let p = (y * WIDTH + x) as usize;
                if frame.depth_before_current[p] == 0 {
                    original_holes += 1;
                }
                assert_eq!(
                    frame.depth_after_current[p], frame.depth_before_current[p],
                    "rejected mesh changed visibility at {x},{y}"
                );
            }
        }
        assert!(
            original_holes > 0,
            "fixture must contain visibility holes that an incorrectly accepted mesh can fill"
        );
    }
}
