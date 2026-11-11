//! AMD swapchain UI composition, using wgpu render attachments.
//! Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see LICENSE.txt.
use std::collections::HashMap;
use wgpu::util::DeviceExt;

pub(super) struct Composition {
    layout: wgpu::BindGroupLayout,
    shader: wgpu::ShaderModule,
    pipelines: HashMap<wgpu::TextureFormat, wgpu::RenderPipeline>,
}

impl Composition {
    pub fn new(device: &wgpu::Device) -> Self {
        let texture = wgpu::BindingType::Texture {
            sample_type: wgpu::TextureSampleType::Float { filterable: false },
            view_dimension: wgpu::TextureViewDimension::D2,
            multisampled: false,
        };
        let layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("FSR presentation"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: texture,
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: texture,
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 2,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });
        Self {
            layout,
            shader: device.create_shader_module(wgpu::ShaderModuleDescriptor {
                label: Some("AMD FSR presentation"),
                source: wgpu::ShaderSource::Wgsl(include_str!("composition.wgsl").into()),
            }),
            pipelines: HashMap::new(),
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn encode(
        &mut self,
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        source: &wgpu::Texture,
        ui: Option<&wgpu::Texture>,
        target: &wgpu::Texture,
        premul: bool,
        debug: Option<u32>,
    ) {
        if ui.is_none()
            && debug.is_none()
            && source.format() == target.format()
            && source.usage().contains(wgpu::TextureUsages::COPY_SRC)
            && target.usage().contains(wgpu::TextureUsages::COPY_DST)
        {
            encoder.copy_texture_to_texture(
                source.as_image_copy(),
                target.as_image_copy(),
                source.size(),
            );
            return;
        }
        // Surface configuration enables the linear alias. AMD composes raw
        // backbuffer values; an sRGB target must not encode them a second time.
        let format = target.format().remove_srgb_suffix();
        let pipeline = self.pipelines.entry(format).or_insert_with(|| {
            let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("FSR presentation"),
                bind_group_layouts: &[Some(&self.layout)],
                immediate_size: 0,
            });
            device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                label: Some("FSR presentation"),
                layout: Some(&layout),
                vertex: wgpu::VertexState {
                    module: &self.shader,
                    entry_point: Some("vs"),
                    compilation_options: Default::default(),
                    buffers: &[],
                },
                fragment: Some(wgpu::FragmentState {
                    module: &self.shader,
                    entry_point: Some("fs"),
                    compilation_options: Default::default(),
                    targets: &[Some(wgpu::ColorTargetState {
                        format,
                        blend: None,
                        write_mask: wgpu::ColorWrites::ALL,
                    })],
                }),
                primitive: Default::default(),
                depth_stencil: None,
                multisample: Default::default(),
                multiview_mask: None,
                cache: None,
            })
        });
        let source_view = source.create_view(&Default::default());
        let ui_view = ui.unwrap_or(source).create_view(&Default::default());
        let options = [
            if ui.is_none() {
                0u32
            } else if premul {
                2
            } else {
                1
            },
            debug.unwrap_or(0),
            u32::from(debug.is_some()),
            0,
        ];
        let uniform = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("FSR presentation options"),
            contents: bytemuck::cast_slice(&options),
            usage: wgpu::BufferUsages::UNIFORM,
        });
        let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("FSR presentation"),
            layout: &self.layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(&source_view),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::TextureView(&ui_view),
                },
                wgpu::BindGroupEntry {
                    binding: 2,
                    resource: uniform.as_entire_binding(),
                },
            ],
        });
        let view = target.create_view(&wgpu::TextureViewDescriptor {
            format: Some(format),
            ..Default::default()
        });
        let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("FSR UI composition"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view: &view,
                depth_slice: None,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),
                    store: wgpu::StoreOp::Store,
                },
            })],
            ..Default::default()
        });
        pass.set_pipeline(pipeline);
        pass.set_bind_group(0, &group, &[]);
        pass.draw(0..3, 0..1);
    }
}
