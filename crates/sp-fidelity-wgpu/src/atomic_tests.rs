use super::*;

#[test]
fn buffer_backed_atomic_texture_preserves_every_add_across_registrations() {
    // Native atomic-texture writes followed by a blit lose partial sums on
    // Apple M5. The selected backend adaptation dispatches atomic buffer
    // operations and restores the original texture. Independently count 64
    // invocations per texel, then inspect the original texture over 32 frames.
    // The odd row width also exposes a padded-row or packed-index mistake.
    let Some((device, queue)) = crate::tests::device() else {
        return;
    };
    let mut backend = FfxWgpuBackend::new(&device);
    let context = backend
        .create_backend_context(FfxEffect::OpticalFlow, None)
        .unwrap();
    let texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("shared atomic texture"),
        size: wgpu::Extent3d {
            width: 257,
            height: 9,
            depth_or_array_layers: 1,
        },
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::R32Uint,
        usage: wgpu::TextureUsages::TEXTURE_BINDING
            | wgpu::TextureUsages::STORAGE_BINDING
            | wgpu::TextureUsages::STORAGE_ATOMIC
            | wgpu::TextureUsages::COPY_SRC
            | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    let source = "@group(0) @binding(64) var<storage, read_write> bins: array<atomic<u32>>;
@compute @workgroup_size(64) fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    atomicAdd(&bins[id.x % arrayLength(&bins)], 1u);
}";
    let reflection = Reflection::new(source).unwrap();
    let entry = wgpu::BindGroupLayoutEntry {
        binding: 64,
        visibility: wgpu::ShaderStages::COMPUTE,
        ty: reflection.binding(64).unwrap().0,
        count: None,
    };
    let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        label: None,
        entries: &[entry],
    });
    let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: None,
        bind_group_layouts: &[Some(&layout)],
        immediate_size: 0,
    });
    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: None,
        source: wgpu::ShaderSource::Wgsl(source.into()),
    });
    let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: None,
        layout: Some(&pipeline_layout),
        module: &shader,
        entry_point: Some(FFX_WGSL_ENTRY_POINT),
        compilation_options: Default::default(),
        cache: None,
    });
    backend.pipelines.push(Some(Pipeline {
        effect: FfxEffect::OpticalFlow,
        pass: 0,
        pipeline,
        output_source: None,
        spd_epilogue: None,
        layout,
        entries: HashMap::from([(64, entry)]),
        constant_sizes: HashMap::new(),
        constants: Vec::new(),
        samplers: Vec::new(),
        grid_group: None,
        groups: RefCell::new(Vec::new()),
    }));
    let state = FfxPipelineState {
        pipeline: 1,
        name: "atomic histogram".into(),
        uav_texture_bindings: vec![FfxResourceBinding {
            slot_index: 0,
            array_index: 0,
            resource_identifier: 0,
            name: "bins".into(),
        }],
        ..Default::default()
    };
    for frame in 0..32 {
        let command_list =
            backend.ffx_get_command_list_wgpu(device.create_command_encoder(&Default::default()));
        let external = backend.ffx_get_resource_wgpu(
            &texture,
            "shared atomic texture",
            FFX_RESOURCE_STATE_UNORDERED_ACCESS,
        );
        let registered = backend.register_resource(&external, context).unwrap();
        backend
            .schedule_gpu_job(&FfxGpuJobDescription {
                job_label: "atomic histogram".into(),
                descriptor: FfxGpuJobDescriptor::Compute(Box::new(FfxComputeJobDescription {
                    pipeline: state.clone(),
                    dimensions: [2313, 1, 1],
                    uav_textures: vec![FfxTextureUAV {
                        resource: registered,
                        mip: 0,
                    }],
                    ..Default::default()
                })),
            })
            .unwrap();
        backend.execute_gpu_jobs(command_list, context).unwrap();
        backend.unregister_resources(command_list, context).unwrap();
        let mut encoder = backend.ffx_take_command_list_wgpu(command_list).unwrap();
        let readback = readback::Readback::texture(&device, &mut encoder, &texture, 0);
        queue.submit([encoder.finish()]);
        let bytes = readback::Readback::read_all(&device, vec![readback])
            .pop()
            .unwrap();
        let counts: Vec<_> = bytes
            .chunks_exact(4)
            .map(|word| u32::from_le_bytes(word.try_into().unwrap()))
            .collect();
        let expected = (frame + 1) * 64;
        assert_eq!(counts.len(), 2313);
        assert!(
            counts.iter().all(|&count| count == expected),
            "frame {frame}: expected {expected} additions per texel, observed {}..{}",
            counts.iter().min().unwrap(),
            counts.iter().max().unwrap()
        );
    }
}
