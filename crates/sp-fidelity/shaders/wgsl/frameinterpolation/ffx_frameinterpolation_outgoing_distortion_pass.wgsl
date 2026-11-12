// Keep the distortion corresponding to the retained previous color. SDK-P34.
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#define FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD 0
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + 0) var rw_outgoing_distortion: texture_storage_2d<rg16float, write>;
@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    let p = vec2<i32>(id.xy);
    if (!IsOnScreen(p, RenderSize())) { return; }
    let uv = (vec2<f32>(p) + 0.5) / vec2<f32>(RenderSize());
    textureStore(rw_outgoing_distortion, p, vec4<f32>(SampleDistortionField(uv), 0.0, 0.0));
}
