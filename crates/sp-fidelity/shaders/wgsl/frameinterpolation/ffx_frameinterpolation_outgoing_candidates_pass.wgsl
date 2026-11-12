// Previous-depth image mesh warped to AMD's endpoint-linear midpoint. MIT.
// SDK-P34. No vendor source is changed; unsupported geometry keeps AMD fallback.
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_X 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_Y 1
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_outgoing_common.wgsl"
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 0) var r_outgoing_depth: texture_2d<f32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 1) var r_outgoing_motion: texture_2d<f32>;
// Piecewise depth-image meshes must not connect unrelated surfaces. A planar
// device-depth slope is affine. Reject an edge unsupported by its neighboring
// one-pixel slopes; curvature/sharp silhouettes conservatively keep fallback.
#include "frameinterpolation/ffx_frameinterpolation_depth_connectivity.wgsl"
fn OutgoingConnected(a: OutgoingVertex, b: OutgoingVertex) -> bool {
    return GeometryDepthConnected(a.sourcePixel,b.sourcePixel,a.previousDepth,b.previousDepth);
}
fn OutgoingEdge(a: vec2<f32>, b: vec2<f32>, p: vec2<f32>) -> f32 {
    return (b.x-a.x)*(p.y-a.y) - (b.y-a.y)*(p.x-a.x);
}
// Bound work for singular/extreme projections. 4096 destination candidates
// covers a 64x64 footprint of a single source-cell triangle. Larger footprints
// retain the SDK fallback instead of clipping/stretching a reconstructed cell.
const OUTGOING_MAX_RASTER_CANDIDATES: i32 = 4096;
fn OutgoingRasterize(a: OutgoingVertex, b: OutgoingVertex, c: OutgoingVertex) {
    if (!a.valid || !b.valid || !c.valid) { return; }
    if (!OutgoingConnected(a,b) || !OutgoingConnected(b,c) || !OutgoingConnected(c,a)) { return; }
#if !FFX_OUTGOING_SOURCE_CURRENT
    if (IsUvInside(a.currentUv) && IsUvInside(b.currentUv) && IsUvInside(c.currentUv)) { return; }
#endif
    let size = vec2<f32>(RenderSize());
    let p0 = (a.previousUv + a.currentUv) * 0.5 * size;
    let p1 = (b.previousUv + b.currentUv) * 0.5 * size;
    let p2 = (c.previousUv + c.currentUv) * 0.5 * size;
    let area = OutgoingEdge(p0,p1,p2);
    if (!(area > 0.0 && area < 3.402823466e+38)) { return; }
    let lo = vec2<i32>(clamp(ceil(min(p0,min(p1,p2))-0.5), vec2<f32>(0.0), size));
    let hi = vec2<i32>(clamp(floor(max(p0,max(p1,p2))-0.5), vec2<f32>(-1.0), size-1.0));
    let extent = hi-lo+1;
    if (any(extent <= vec2<i32>(0)) || any(extent > vec2<i32>(OUTGOING_MAX_RASTER_CANDIDATES))) { return; }
    let count = extent.x*extent.y;
    if (count > OUTGOING_MAX_RASTER_CANDIDATES) { return; }
    for (var i = 0; i < OUTGOING_MAX_RASTER_CANDIDATES; i++) {
        if (i >= count) { break; }
        let pixel = lo + vec2<i32>(i % extent.x, i / extent.x);
        let center = vec2<f32>(pixel)+0.5;
        let edge = vec3<f32>(OutgoingEdge(p1,p2,center), OutgoingEdge(p2,p0,center), OutgoingEdge(p0,p1,center));
        if (any(edge < vec3<f32>(0.0))) { continue; }
        let weights = edge/area;
        let previous = a.previousUv*weights.x + b.previousUv*weights.y + c.previousUv*weights.z;
        let midpoint = center/size;
#if !FFX_OUTGOING_SOURCE_CURRENT
        if (IsUvInside(2.0*midpoint - previous)) { continue; }
#endif
        let depth = dot(vec3<f32>(a.currentDepth,b.currentDepth,c.currentDepth), weights);
#if FFX_OUTGOING_SOURCE_CURRENT
        if (any(SampleDistortionField(midpoint)!=vec2<f32>(0.0)) ||
            any(SampleDistortionField(2.0*midpoint-previous)!=vec2<f32>(0.0))) { continue; }
#endif
        let viewDepth = ConvertFromDeviceDepthToViewSpace(depth);
        let depthPower = pow(viewDepth,0.33);
        let priority = max(1u,u32((1.0-depthPower/(1.0+depthPower))*f32(PRIORITY_HIGH_MAX)));
        UpdateGameMotionVectorField(pixel, PackVectorFieldEntries(true,priority,0u,previous-midpoint));
    }
}
@compute @workgroup_size(8,8,1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    let p = vec2<i32>(id.xy);
    if (!IsOnScreen(p+vec2<i32>(1), RenderSize())) { return; }
    let a = OutgoingVertexAt(p); let b = OutgoingVertexAt(p+vec2<i32>(1,0));
    let c = OutgoingVertexAt(p+vec2<i32>(0,1)); let d = OutgoingVertexAt(p+vec2<i32>(1));
    OutgoingRasterize(a,b,c); OutgoingRasterize(b,d,c);
}
