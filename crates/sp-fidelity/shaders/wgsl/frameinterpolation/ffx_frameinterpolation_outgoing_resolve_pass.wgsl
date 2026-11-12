// Insert supported previous-only correspondence; preserve upstream primaries.
// SDK-P34: this does not solve visibility against current-source primaries.
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#define FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD 3
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_X 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_Y 1
#define FFX_FRAMEINTERPOLATION_BIND_UAV_DISOCCLUSION_MASK 2
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 0) var r_outgoing_x: texture_2d<u32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 1) var r_outgoing_y: texture_2d<u32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 2) var r_outgoing_distortion: texture_2d<f32>;
@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    let p = vec2<i32>(id.xy);
    if (!IsOnScreen(p, RenderSize())) { return; }
    if (PackedVectorFieldEntryIsPrimary(RWLoadGameMotionVectorFieldX(p))) { return; }
    let packed = vec2<u32>(textureLoad(r_outgoing_x, p, 0).x, textureLoad(r_outgoing_y, p, 0).x);
    if (!PackedVectorFieldEntryIsPrimary(packed.x) || !PackedVectorFieldEntryIsPrimary(packed.y)) { return; }
    let motion = vec2<f32>(unpack2x16float(packed.x).x, unpack2x16float(packed.y).x);
    let uv = (vec2<f32>(p) + 0.5) / vec2<f32>(RenderSize());
    let previous = uv + motion;
    let margin = 0.5 / vec2<f32>(RenderSize());
    // Validate the packed vector, including previous bilinear sample support.
    if (any(previous < margin) || any(previous > vec2<f32>(1.0) - margin) || IsUvInside(uv - motion)) { return; }
    // The camera model describes unwarped geometry. Keep AMD's reconstruction
    // where either the destination or the previous color lookup is distorted.
    if (any(SampleDistortionField(uv) != vec2<f32>(0.0)) ||
        any(textureSampleLevel(r_outgoing_distortion, s_LinearClamp,
            previous * vec2<f32>(RenderSize()) / vec2<f32>(textureDimensions(r_outgoing_distortion)), 0.0).xy != vec2<f32>(0.0))) { return; }
    StoreGameMotionVectorFieldX(p, packed.x);
    StoreGameMotionVectorFieldY(p, packed.y);
    StoreDisocclusionMask(p, vec2<f32>(1.0, 0.0));
}
