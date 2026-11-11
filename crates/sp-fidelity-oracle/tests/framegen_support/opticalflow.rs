use crate::framegen_support::*;
use serde_json::json;
use sp_fidelity::opticalflow::*;
use sp_fidelity::types::*;
use sp_fidelity_oracle::recorder::Recorder;
use std::cell::RefCell;
use std::rc::Rc;

pub fn run_rust(caps: FfxDeviceCapabilities, words: &[u32]) -> Recorded {
    let recorder = Rc::new(RefCell::new(Recorder::new(caps)));
    let mut w = Words { words, at: 0 };
    let description = FfxOpticalflowContextDescription {
        backend_interface: recorder.clone(),
        flags: w.word(),
        resolution: w.size(),
    };
    let size = description.resolution;
    let color = recorder
        .borrow_mut()
        .external("color", size.width, size.height);
    let vector = recorder.borrow_mut().external(
        "optical-flow",
        size.width.div_ceil(8),
        size.height.div_ceil(8),
    );
    let scd = recorder.borrow_mut().external("scene-change", 3, 1);
    let mut context = FfxOpticalflowContext::default();
    let created = ffx_opticalflow_context_create(&mut context, &description);
    recorder.borrow_mut().result("create-result", created);
    if created.is_err() {
        return take(&recorder);
    }
    recorder
        .borrow_mut()
        .events
        .push(json!(["version", ffx_opticalflow_get_effect_version()]));
    let queried = ffx_opticalflow_context_get_gpu_memory_usage(&context);
    let usage = queried.unwrap_or_default();
    recorder.borrow_mut().events.push(json!([
        "memory-usage-result",
        status(&queried),
        usage.total_usage_in_bytes,
        usage.aliasable_usage_in_bytes
    ]));
    let resources = ffx_opticalflow_get_shared_resource_descriptions(&context);
    recorder
        .borrow_mut()
        .events
        .push(json!(["shared-result", status(&resources)]));
    let resources = resources.unwrap();
    shared(&recorder, &resources.optical_flow_vector);
    shared(&recorder, &resources.optical_flow_scd);
    for index in 0..w.word() as usize {
        recorder.borrow_mut().frame(index);
        let present = w.word();
        let optional = |mask, r: &FfxResource| {
            if present & mask != 0 {
                r.clone()
            } else {
                FfxResource::default()
            }
        };
        let mut dispatch = FfxOpticalflowDispatchDescription {
            command_list: usize::from(present & 1 != 0),
            color: optional(2, &color),
            optical_flow_vector: optional(4, &vector),
            optical_flow_scd: optional(8, &scd),
            ..Default::default()
        };
        dispatch.color.description.width = w.word();
        dispatch.color.description.height = w.word();
        dispatch.reset = w.word() != 0;
        dispatch.backbuffer_transfer_function = w.word() as i32;
        dispatch.min_max_luminance = w.coords();
        let result = ffx_opticalflow_context_dispatch(&mut context, &dispatch);
        recorder.borrow_mut().result("dispatch-result", result);
    }
    let destroyed = ffx_opticalflow_context_destroy(&mut context);
    recorder.borrow_mut().result("destroy-result", destroyed);
    take(&recorder)
}
