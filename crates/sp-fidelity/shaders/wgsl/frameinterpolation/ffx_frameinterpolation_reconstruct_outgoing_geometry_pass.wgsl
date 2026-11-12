// sp-fidelity optional camera-supported edge reconstruction, MIT.
// Owner-approved algorithm departure, 2026-11-12; see CONFORMANCE.md SDK-P29.
// Uses the SDK's unchanged packed-vector and atomic-depth helpers.
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_X 0
#define FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_Y 1
#define FFX_FRAMEINTERPOLATION_BIND_UAV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME 2
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"

#include "frameinterpolation/ffx_frameinterpolation_edge_common.wgsl"

@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 0) var r_edge_previous_depth: texture_2d<f32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 1) var r_edge_previous_motion: texture_2d<f32>;

struct EdgeVertex {
    sourcePixel: vec2<i32>,
    previousDepth: f32,
    previousUv: vec2<f32>,
    currentUv: vec2<f32>,
    currentDepth: f32,
    valid: bool,
}

fn EdgeLoadVertex(pixel: vec2<i32>) -> EdgeVertex {
    var vertex: EdgeVertex;
    if (!IsOnScreen(pixel, RenderSize())) { return vertex; }
    let depth = textureLoad(r_edge_previous_depth, pixel, 0).x;
    // Sky/clear depth has no finite surface to reconstruct.
    if (!(depth > 0.0 && depth < 1.0)) { return vertex; }
    let camera = cbEdge.previous;
    let z = camera.projection.y / (depth - camera.projection.x);
    if (!(z > 0.0 && z < 3.402823466e+38)) { return vertex; }
    let size = vec2<f32>(RenderSize());
    // The depth is raster-jittered; the supplied game MV and upscaled color are not.
    let previousUv = (vec2<f32>(pixel) + 0.5 - camera.jitter.xy) / size;
    let xy = (previousUv * 2.0 - 1.0) * camera.projection.zw * z;
    let world = camera.position.xyz + camera.right.xyz * xy.x - camera.up.xyz * xy.y + camera.forward.xyz * z;
    let current = EdgeProject(world, cbEdge.current);
    if (!(current.z > 0.0)) { return vertex; }
    let older = EdgeProject(world, cbEdge.older);
    if (!(older.z > 0.0)) { return vertex; }
    let observedMotion = textureLoad(r_edge_previous_motion, pixel, 0).xy;
    let predictedMotion = older.xy - previousUv;
    // One pixel for the SDK's 3x3 nearest-depth dilation and one for the
    // bilinear reconstruction footprint, per axis. This is a pixel support
    // bound, independent of frame rate, scene colors, velocity or screenshots.
    if (any(abs((observedMotion - predictedMotion) * size) > vec2<f32>(2.0))) { return vertex; }
    let currentDepth = cbEdge.current.projection.x + cbEdge.current.projection.y / current.z;
    if (!(currentDepth > 0.0 && currentDepth < 1.0)) { return vertex; }
    vertex.sourcePixel = pixel;
    vertex.previousDepth = depth;
    vertex.previousUv = previousUv;
    vertex.currentUv = current.xy;
    vertex.currentDepth = currentDepth;
    vertex.valid = true;
    return vertex;
}

fn EdgeFunction(a: vec2<f32>, b: vec2<f32>, point: vec2<f32>) -> f32 {
    return (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x);
}

// Device depth is affine in inverse view depth, hence linear on a plane in
// image space. A step between surfaces has a large central difference and
// small side differences. Require both available one-pixel neighborhoods to
// support the edge over the same two-pixel reconstruction footprint.
fn EdgeConnected(a: EdgeVertex, b: EdgeVertex) -> bool {
    let jump = abs(a.previousDepth - b.previousDepth);
    let roundoff = 4.0 * 1.192092896e-7 * max(abs(a.previousDepth), abs(b.previousDepth));
    if (jump <= roundoff) { return true; }
    let step = b.sourcePixel - a.sourcePixel;
    var supported = false;
    let before = a.sourcePixel - step;
    if (IsOnScreen(before, RenderSize())) {
        let depth = textureLoad(r_edge_previous_depth, before, 0).x;
        if (!(depth > 0.0 && depth < 1.0) || jump > 2.0 * abs(depth - a.previousDepth) + roundoff) { return false; }
        supported = true;
    }
    let after = b.sourcePixel + step;
    if (IsOnScreen(after, RenderSize())) {
        let depth = textureLoad(r_edge_previous_depth, after, 0).x;
        if (!(depth > 0.0 && depth < 1.0) || jump > 2.0 * abs(depth - b.previousDepth) + roundoff) { return false; }
        supported = true;
    }
    return supported;
}

const EDGE_MAX_RASTER_CANDIDATES: i32 = 8 * 8;

fn EdgeRasterize(a: EdgeVertex, b: EdgeVertex, c: EdgeVertex) {
    if (!(a.valid && b.valid && c.valid)) { return; }
    if (IsUvInside(a.currentUv) && IsUvInside(b.currentUv) && IsUvInside(c.currentUv)) { return; }
    if (!(EdgeConnected(a, b) && EdgeConnected(b, c) && EdgeConnected(c, a))) { return; }
    let size = vec2<f32>(RenderSize());
    let p0 = (a.previousUv + a.currentUv) * 0.5 * size;
    let p1 = (b.previousUv + b.currentUv) * 0.5 * size;
    let p2 = (c.previousUv + c.currentUv) * 0.5 * size;
    let area = EdgeFunction(p0, p1, p2);
    // Folded/back-facing triangles cannot establish a visible source footprint.
    if (!(area > 0.0)) { return; }
    let lo = max(vec2<i32>(0), vec2<i32>(floor(min(p0, min(p1, p2)) - 0.5)));
    let hi = min(RenderSize() - 1, vec2<i32>(ceil(max(p0, max(p1, p2)) - 0.5)));
    if (any(hi < lo)) { return; }
    let extent = hi - lo + 1;
    // Bound near-plane magnification to one 8x8 tile of candidate work per
    // triangle. Oversized cells retain the original SDK fallback; never clamp
    // a huge triangle to an arbitrary smaller footprint or stretch its color.
    if (extent.x > EDGE_MAX_RASTER_CANDIDATES || extent.y > EDGE_MAX_RASTER_CANDIDATES || extent.x * extent.y > EDGE_MAX_RASTER_CANDIDATES) { return; }
    // Conservative pixel-square coverage. Half a destination pixel is exactly
    // the raster footprint, not an expansion radius tuned to motion magnitude.
    let e0 = abs(p2 - p1);
    let e1 = abs(p0 - p2);
    let e2 = abs(p1 - p0);
    let coverage = 0.5 * vec3<f32>(e0.x + e0.y, e1.x + e1.y, e2.x + e2.y);
    for (var y = lo.y; y <= hi.y; y++) {
        for (var x = lo.x; x <= hi.x; x++) {
            let pixel = vec2<i32>(x, y);
            let center = vec2<f32>(pixel) + 0.5;
            let edge = vec3<f32>(EdgeFunction(p1, p2, center), EdgeFunction(p2, p0, center), EdgeFunction(p0, p1, center));
            if (any(edge < -coverage)) { continue; }
            // Clamp conservative coverage to the source triangle's support.
            let positive = max(edge, vec3<f32>(0.0));
            let weights = positive / (positive.x + positive.y + positive.z);
            let previousUv = a.previousUv * weights.x + b.previousUv * weights.y + c.previousUv * weights.z;
            let midpoint = center / size;
            let currentUv = 2.0 * midpoint - previousUv;
            if (IsUvInside(currentUv)) { continue; }
            let motion = previousUv - midpoint;
            let currentDepth = dot(vec3<f32>(a.currentDepth, b.currentDepth, c.currentDepth), weights);
            let viewDepthMeters = ConvertFromDeviceDepthToViewSpace(currentDepth);
            let depthPower = pow(viewDepthMeters, 0.33);
            let priority = max(1u, u32((1.0 - depthPower / (1.0 + depthPower)) * f32(PRIORITY_HIGH_MAX)));
            UpdateGameMotionVectorField(pixel, PackVectorFieldEntries(true, priority, 0u, motion));
            UpdateReconstructedDepthInterpolatedFrame(pixel, currentDepth);
        }
    }
}

@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    let pixel = vec2<i32>(id.xy);
    if (!IsOnScreen(pixel + vec2<i32>(1), RenderSize())) { return; }
    // A depth-image cell is a pair of triangles, rather than four isolated
    // fixed-size splats. Reprojection includes the actual surface depth slope,
    // so magnification cannot open regular holes between neighboring samples.
    let a = EdgeLoadVertex(pixel);
    let b = EdgeLoadVertex(pixel + vec2<i32>(1, 0));
    let c = EdgeLoadVertex(pixel + vec2<i32>(0, 1));
    let d = EdgeLoadVertex(pixel + vec2<i32>(1, 1));
    EdgeRasterize(a, b, c);
    EdgeRasterize(b, d, c);
}
