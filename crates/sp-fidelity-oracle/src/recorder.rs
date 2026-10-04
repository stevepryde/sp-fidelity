//! The recording `FfxInterface` of `oracle/host.cpp`, for the port: both print
//! the same event for every backend call, so an effect's host port is compared
//! with AMD's unchanged C++ host event by event. The C++ side binds from the
//! DXC reflection of the vendored HLSL; this side from the port's blob
//! accessors.
use serde_json::{Value, json};
use sp_fidelity::blob_accessors::ffx_get_permutation_blob_by_index;
use sp_fidelity::error::*;
use sp_fidelity::interface::*;
use sp_fidelity::types::*;
use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::{Rc, Weak};

thread_local! {
    /// The recorder `record_message` writes to on this thread.
    static MESSAGE_SINK: RefCell<Weak<RefCell<Recorder>>> = const { RefCell::new(Weak::new()) };
}

/// `recordMessage()`: an `FfxMessageCallback` that records
/// `["message",type,"<text>"]` in this thread's recorder (see
/// [`Recorder::record_messages`]).
pub fn record_message(message_type: u32, message: &str) {
    MESSAGE_SINK.with(|sink| {
        if let Some(recorder) = sink.borrow().upgrade() {
            recorder
                .borrow_mut()
                .events
                .push(json!(["message", message_type, message]));
        }
    });
}

/// Mirrors the recording backend and the driver helpers of `oracle/host.cpp`.
pub struct Recorder {
    /// Events in call order, one per line of the C++ host's output.
    pub events: Vec<Value>,
    /// `FFX_RESOURCE_INIT_DATA_TYPE_BUFFER` data by resource name, as the C++
    /// host exports it.
    pub init_data: HashMap<String, Vec<u8>>,
    resources: HashMap<i32, (FfxResourceDescription, String)>,
    next_resource: i32,
    next_context: u32,
    capabilities: FfxDeviceCapabilities,
}

impl Recorder {
    pub fn new(capabilities: FfxDeviceCapabilities) -> Self {
        Self {
            events: Vec::new(),
            init_data: HashMap::new(),
            resources: HashMap::new(),
            next_resource: 1,
            next_context: 0,
            capabilities,
        }
    }

    fn name(&self, r: FfxResourceInternal) -> String {
        if r.internal_index == 0 {
            "NULL".into()
        } else {
            self.resources[&r.internal_index].1.clone()
        }
    }

    /// `external()`: an application resource, registered by its oracle name.
    pub fn external(&mut self, label: &str, width: u32, height: u32) -> FfxResource {
        let index = self.next_resource;
        self.next_resource += 1;
        let description = FfxResourceDescription {
            r#type: FfxResourceType::Texture2D,
            width,
            height,
            mip_count: 1,
            ..Default::default()
        };
        self.resources.insert(index, (description, label.into()));
        FfxResource {
            resource: usize::try_from(index).unwrap(),
            description,
            ..Default::default()
        }
    }

    /// `result()`: `["<kind>",status]` for an SDK call's result.
    pub fn result(&mut self, kind: &str, result: Result<(), FfxErrorCode>) {
        self.events
            .push(json!([kind, result.err().unwrap_or(FFX_OK)]));
    }

    /// `frame()`.
    pub fn frame(&mut self, index: usize) {
        self.events.push(json!(["frame", index]));
    }

    /// Makes `recorder` the one [`record_message`] writes to on this thread.
    pub fn record_messages(recorder: &Rc<RefCell<Recorder>>) {
        MESSAGE_SINK.with(|sink| *sink.borrow_mut() = Rc::downgrade(recorder));
    }
}

impl FfxInterface for Recorder {
    fn device(&self) -> FfxDevice {
        1
    }

    fn get_sdk_version(&mut self) -> FfxVersionNumber {
        ffx_sdk_make_version(1, 1, 4)
    }

    fn get_effect_gpu_memory_usage(
        &mut self,
        id: u32,
    ) -> Result<FfxEffectMemoryUsage, FfxErrorCode> {
        self.events.push(json!(["memory-usage", id]));
        Ok(FfxEffectMemoryUsage::default())
    }

    fn create_backend_context(
        &mut self,
        _: FfxEffect,
        _: Option<&FfxEffectBindlessConfig>,
    ) -> Result<u32, FfxErrorCode> {
        self.next_context += 1;
        Ok(self.next_context - 1)
    }

    fn get_device_capabilities(&mut self) -> Result<FfxDeviceCapabilities, FfxErrorCode> {
        Ok(self.capabilities)
    }

    fn destroy_backend_context(&mut self, effect_context_id: u32) -> Result<(), FfxErrorCode> {
        self.events
            .push(json!(["destroy-context", effect_context_id]));
        Ok(())
    }

    fn create_resource(
        &mut self,
        d: &FfxCreateResourceDescription<'_>,
        _: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode> {
        let index = self.next_resource;
        self.next_resource += 1;
        self.resources
            .insert(index, (d.resource_description, d.name.into()));
        if matches!(
            d.init_data.r#type,
            FfxResourceInitDataType::Buffer | FfxResourceInitDataType::Value
        ) {
            self.resources.insert(
                self.next_resource,
                (d.resource_description, format!("{} upload", d.name)),
            );
            self.next_resource += 1;
        }
        if d.init_data.r#type == FfxResourceInitDataType::Buffer {
            self.init_data.insert(
                d.name.into(),
                d.init_data.buffer[..d.init_data.size].to_vec(),
            );
        }
        let r = d.resource_description;
        let value = if d.init_data.r#type == FfxResourceInitDataType::Value {
            d.init_data.value
        } else {
            0
        };
        self.events.push(json!([
            "resource",
            d.name,
            r.r#type as u32,
            r.format as u32,
            r.width,
            r.height,
            r.mip_count,
            r.usage,
            d.init_data.r#type as u32,
            d.init_data.size,
            value,
            d.heap_type as u32,
            d.initial_state,
            d.id,
            r.depth,
            r.flags
        ]));
        Ok(FfxResourceInternal {
            internal_index: index,
        })
    }

    fn register_resource(
        &mut self,
        r: &FfxResource,
        _: u32,
    ) -> Result<FfxResourceInternal, FfxErrorCode> {
        let resource = FfxResourceInternal {
            internal_index: i32::try_from(r.resource).unwrap(),
        };
        self.events.push(json!(["register", self.name(resource)]));
        Ok(resource)
    }

    fn get_resource(&mut self, r: FfxResourceInternal) -> FfxResource {
        FfxResource {
            resource: usize::try_from(r.internal_index).unwrap(),
            description: self.resources[&r.internal_index].0,
            ..Default::default()
        }
    }

    fn unregister_resources(&mut self, _: FfxCommandList, id: u32) -> Result<(), FfxErrorCode> {
        self.events.push(json!(["unregister", id]));
        Ok(())
    }

    fn get_resource_description(&mut self, r: FfxResourceInternal) -> FfxResourceDescription {
        self.resources[&r.internal_index].0
    }

    fn destroy_resource(&mut self, r: FfxResourceInternal, _: u32) -> Result<(), FfxErrorCode> {
        self.events.push(json!(["destroy-resource", self.name(r)]));
        Ok(())
    }

    fn stage_constant_buffer_data_func(
        &mut self,
        data: &[u32],
        cb: &mut FfxConstantBuffer,
    ) -> Result<(), FfxErrorCode> {
        cb.data = data.to_vec();
        cb.num_32bit_entries = u32::try_from(data.len()).unwrap();
        self.events.push(json!(["constants", data]));
        Ok(())
    }

    fn create_pipeline(
        &mut self,
        effect: FfxEffect,
        pass: FfxPass,
        flags: u32,
        desc: &FfxPipelineDescription<'_>,
        _: u32,
    ) -> Result<FfxPipelineState, FfxErrorCode> {
        let blob = self.get_permutation_blob_by_index(effect, pass, desc.stage, flags)?;
        let expand = |table: &[FfxShaderBlobBinding]| {
            table
                .iter()
                .flat_map(|b| {
                    (0..b.count).map(|array_index| FfxResourceBinding {
                        slot_index: b.binding,
                        array_index,
                        resource_identifier: 0,
                        name: b.name.into(),
                    })
                })
                .collect::<Vec<_>>()
        };
        let state = FfxPipelineState {
            pass_id: pass,
            pipeline: usize::try_from(pass).unwrap() + 1,
            cmd_signature: usize::from(desc.indirect_workload != 0),
            srv_texture_bindings: expand(blob.bound_srv_textures),
            uav_texture_bindings: expand(blob.bound_uav_textures),
            uav_buffer_bindings: expand(blob.bound_uav_buffers),
            constant_buffer_bindings: expand(blob.bound_constant_buffers),
            name: desc.name.clone(),
            ..Default::default()
        };
        let root_constants: Vec<_> = desc.root_constants.iter().map(|c| c.size).collect();
        let root_constant_stages: Vec<_> = desc.root_constants.iter().map(|c| c.stage).collect();
        let samplers: Vec<_> = desc
            .samplers
            .iter()
            .map(|s| {
                json!([
                    s.filter as u32,
                    s.address_mode_u as u32,
                    s.address_mode_v as u32,
                    s.address_mode_w as u32,
                    s.stage
                ])
            })
            .collect();
        self.events.push(json!([
            "pipeline",
            pass,
            flags,
            desc.indirect_workload,
            root_constants,
            samplers,
            desc.name,
            desc.context_flags,
            desc.stage,
            desc.backbuffer_format as u32,
            root_constant_stages
        ]));
        Ok(state)
    }

    fn get_permutation_blob_by_index(
        &self,
        effect: FfxEffect,
        pass: FfxPass,
        stage: FfxBindStage,
        options: u32,
    ) -> Result<FfxShaderBlob, FfxErrorCode> {
        ffx_get_permutation_blob_by_index(effect, pass, stage, options)
    }

    fn destroy_pipeline(&mut self, p: &mut FfxPipelineState, _: u32) -> Result<(), FfxErrorCode> {
        self.events.push(json!(["destroy-pipeline", p.pass_id]));
        Ok(())
    }

    fn schedule_gpu_job(&mut self, job: &FfxGpuJobDescription) -> Result<(), FfxErrorCode> {
        let event = match &job.descriptor {
            FfxGpuJobDescriptor::ClearFloat(c) => {
                json!([
                    "clear",
                    self.name(c.target),
                    c.color.map(f32::to_bits),
                    job.job_label
                ])
            }
            FfxGpuJobDescriptor::Copy(c) => json!([
                "copy",
                self.name(c.src),
                self.name(c.dst),
                c.src_offset,
                c.dst_offset,
                c.size,
                job.job_label
            ]),
            FfxGpuJobDescriptor::Compute(c) => {
                let p = &c.pipeline;
                let mut bound = Vec::new();
                let binding = |kind: &str, b: &FfxResourceBinding, r, mip: u32| {
                    json!([kind, b.name, self.name(r), mip, b.slot_index, b.array_index])
                };
                for (b, r) in p.srv_texture_bindings.iter().zip(&c.srv_textures) {
                    bound.push(binding("srv", b, r.resource, 0));
                }
                for (b, r) in p.uav_texture_bindings.iter().zip(&c.uav_textures) {
                    bound.push(binding("uav", b, r.resource, r.mip));
                }
                for (b, r) in p.uav_buffer_bindings.iter().zip(&c.uav_buffers) {
                    bound.push(binding("buffer", b, r.resource, 0));
                }
                let constants: Vec<_> = p
                    .constant_buffer_bindings
                    .iter()
                    .zip(&c.cbs)
                    .map(|(b, cb)| {
                        json!([
                            b.name,
                            cb.data[..cb.num_32bit_entries as usize],
                            b.slot_index
                        ])
                    })
                    .collect();
                json!([
                    "compute",
                    p.pass_id,
                    c.dimensions,
                    self.name(c.cmd_argument),
                    c.cmd_argument_offset,
                    bound,
                    constants,
                    job.job_label
                ])
            }
        };
        self.events.push(event);
        Ok(())
    }

    fn execute_gpu_jobs(&mut self, _: FfxCommandList, id: u32) -> Result<(), FfxErrorCode> {
        self.events.push(json!(["execute", id]));
        Ok(())
    }
}
