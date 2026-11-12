// Fill gaps and refine the same supported surface before visibility tests.
#define FFX_OUTGOING_SOURCE_CURRENT 1
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME 2
#define FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD 3
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_X 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_Y 1
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 0) var r_outgoing_x: texture_2d<u32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 1) var r_outgoing_y: texture_2d<u32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 2) var r_outgoing_distortion: texture_2d<f32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 4) var r_outgoing_depth: texture_2d<f32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 5) var r_outgoing_motion: texture_2d<f32>;
#include "frameinterpolation/ffx_frameinterpolation_outgoing_common.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_depth_connectivity.wgsl"
// Recover the accepted correspondence's current-source triangle. A candidate
// rejected below must not alter visibility through a separate depth write.
fn CurrentTriangleDepth(uv: vec2<f32>) -> f32 {
    let pixel=uv*vec2<f32>(RenderSize())+Jitter()-0.5;
    let base=vec2<i32>(floor(pixel));
    let f=fract(pixel);
    var pa=base; var pb=base+vec2<i32>(1,0); var pc=base+vec2<i32>(0,1);
    var weights=vec3<f32>(1.0-f.x-f.y,f.x,f.y);
    if (f.x+f.y>1.0) {
        pa=base+vec2<i32>(1); pb=base+vec2<i32>(0,1); pc=base+vec2<i32>(1,0);
        weights=vec3<f32>(f.x+f.y-1.0,1.0-f.x,1.0-f.y);
    }
    let a=OutgoingVertexAt(pa); let b=OutgoingVertexAt(pb); let c=OutgoingVertexAt(pc);
    if (!a.valid || !b.valid || !c.valid) {return -1.0;}
    if (!GeometryDepthConnected(pa,pb,a.previousDepth,b.previousDepth) ||
        !GeometryDepthConnected(pb,pc,b.previousDepth,c.previousDepth) ||
        !GeometryDepthConnected(pc,pa,c.previousDepth,a.previousDepth)) {return -1.0;}
    return dot(weights,vec3<f32>(a.currentDepth,b.currentDepth,c.currentDepth));
}
@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    let p = vec2<i32>(id.xy);
    if (!IsOnScreen(p, RenderSize())) { return; }
    let original = vec2<u32>(RWLoadGameMotionVectorFieldX(p),RWLoadGameMotionVectorFieldY(p));
    let packed = vec2<u32>(textureLoad(r_outgoing_x,p,0).x,textureLoad(r_outgoing_y,p,0).x);
    if (!PackedVectorFieldEntryIsPrimary(packed.x) || !PackedVectorFieldEntryIsPrimary(packed.y)) { return; }
    let motion = vec2<f32>(unpack2x16float(packed.x).x,unpack2x16float(packed.y).x);
    let uv = (vec2<f32>(p)+0.5)/vec2<f32>(RenderSize());
    let current = uv-motion;
    let previous = uv+motion;
    let margin = 0.5/vec2<f32>(RenderSize());
    if (any(current<margin) || any(current>vec2<f32>(1.0)-margin)) { return; }
    if (any(SampleDistortionField(uv)!=vec2<f32>(0.0)) || any(SampleDistortionField(current)!=vec2<f32>(0.0))) { return; }
    if (IsUvInside(previous) && any(textureSampleLevel(r_outgoing_distortion,s_LinearClamp,
        previous*vec2<f32>(RenderSize())/vec2<f32>(textureDimensions(r_outgoing_distortion)),0.0).xy!=vec2<f32>(0.0))) { return; }
    if (PackedVectorFieldEntryIsPrimary(original.x)) {
        // Conservatively limit refinement to nearby vectors on connected
        // geometry. Proximity alone cannot distinguish independent coplanar
        // motion: validate the original source's measured motion as well.
        let oldMotion=vec2<f32>(unpack2x16float(original.x).x,unpack2x16float(original.y).x);
        if (any(abs(oldMotion-motion)*vec2<f32>(RenderSize())>vec2<f32>(2.0))) { return; }
        let a=vec2<i32>(floor((uv-oldMotion)*vec2<f32>(RenderSize())+Jitter()));
        let b=vec2<i32>(floor(current*vec2<f32>(RenderSize())+Jitter()));
        if (!IsOnScreen(a,RenderSize()) || !IsOnScreen(b,RenderSize())) {return;}
        if (!OutgoingVertexAt(a).valid) {return;}
        let da=textureLoad(r_outgoing_depth,a,0).x;
        let db=textureLoad(r_outgoing_depth,b,0).x;
        if (!(da>0.0 && da<1.0 && db>0.0 && db<1.0) || !GeometryDepthConnected(a,b,da,db)) {return;}
    }
    let depth=CurrentTriangleDepth(current);
    if (!(depth>0.0 && depth<1.0)) {return;}
    StoreReconstructedDepthInterpolatedFrame(p,depth);
    StoreGameMotionVectorFieldX(p,packed.x);
    StoreGameMotionVectorFieldY(p,packed.y);
}
