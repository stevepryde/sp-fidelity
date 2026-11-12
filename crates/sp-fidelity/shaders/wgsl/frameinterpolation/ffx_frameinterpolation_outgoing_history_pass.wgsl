// Retain raw depth and normalized motion before nearest-depth dilation. SDK-P34.
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#define FFX_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH 0
#define FFX_FRAMEINTERPOLATION_BIND_SRV_INPUT_MOTION_VECTORS 1
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + 0) var rw_outgoing_depth: texture_storage_2d<r32float, write>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + 1) var rw_outgoing_motion: texture_storage_2d<rg16float, write>;
@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    let p = vec2<i32>(id.xy);
    if (!IsOnScreen(p, RenderSize())) { return; }
#if FFX_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS
    let motionPixel = p;
#else
    let motionPixel = ComputeHrPosFromLrPos(p);
#endif
    textureStore(rw_outgoing_depth, p, vec4<f32>(LoadInputDepth(p), 0.0, 0.0, 0.0));
    textureStore(rw_outgoing_motion, p, vec4<f32>(LoadInputMotionVector(motionPixel), 0.0, 0.0));
}
