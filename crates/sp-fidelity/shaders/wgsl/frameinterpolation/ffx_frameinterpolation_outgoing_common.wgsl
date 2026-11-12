// Rust/WGSL outgoing reconstruction correction, MIT. See SDK-P34.
struct OutgoingCamera {
    position: vec4<f32>, right: vec4<f32>, up: vec4<f32>, forward: vec4<f32>,
    projection: vec4<f32>, jitter: vec4<f32>,
}
struct OutgoingConstants { current: OutgoingCamera, previous: OutgoingCamera, older: OutgoingCamera, }
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + 1) var<uniform> cbOutgoing: OutgoingConstants;
fn OutgoingProject(relativeToPrevious: vec3<f32>, camera: OutgoingCamera) -> vec3<f32> {
    // Subtract camera origins before adding the local surface point. This
    // avoids losing local depth precision in a large world-coordinate origin.
    let relative = (cbOutgoing.previous.position.xyz - camera.position.xyz) + relativeToPrevious;
    let z = dot(relative, camera.forward.xyz);
    let xy = vec2<f32>(dot(relative, camera.right.xyz), -dot(relative, camera.up.xyz));
    return vec3<f32>(vec2<f32>(0.5) + xy / (2.0 * z * camera.projection.zw), z);
}

struct OutgoingVertex {
    sourcePixel: vec2<i32>, previousDepth: f32, previousUv: vec2<f32>,
    currentUv: vec2<f32>, currentDepth: f32, valid: bool,
}
fn OutgoingVertexAt(pixel: vec2<i32>) -> OutgoingVertex {
    var vertex: OutgoingVertex;
    if (!IsOnScreen(pixel, RenderSize())) { return vertex; }
    let depth = textureLoad(r_outgoing_depth, pixel, 0).x;
    if (!(depth > 0.0 && depth < 1.0)) { return vertex; }
#if FFX_OUTGOING_SOURCE_CURRENT
    let camera = cbOutgoing.current;
#else
    let camera = cbOutgoing.previous;
#endif
    let z = camera.projection.y / (depth - camera.projection.x);
    if (!(z > 0.0 && z < 3.402823466e+38)) { return vertex; }
    let uv = (vec2<f32>(pixel) + 0.5 - camera.jitter.xy) / vec2<f32>(RenderSize());
    let xy = (uv * 2.0 - 1.0) * camera.projection.zw * z;
    let relative = camera.right.xyz * xy.x - camera.up.xyz * xy.y + camera.forward.xyz * z;
#if FFX_OUTGOING_SOURCE_CURRENT
    let current = vec3<f32>(uv, z);
    let older = OutgoingProject((cbOutgoing.current.position.xyz - cbOutgoing.previous.position.xyz) + relative, cbOutgoing.previous);
#else
    let current = OutgoingProject(relative, cbOutgoing.current);
    let older = OutgoingProject(relative, cbOutgoing.older);
#endif
    if (!(current.z > 0.0 && older.z > 0.0)) { return vertex; }
    let observed = textureLoad(r_outgoing_motion, pixel, 0).xy;
    let expected = older.xy - uv;
    // Historical consistency only: cannot detect motion beginning this interval.
    // One binary16 ULP covers input quantization and the normalized-history
    // round-trip; the FP32 term covers the relative camera projection arithmetic.
    let tolerance = max(vec2<f32>(exp2(-24.0)), abs(expected) * exp2(-10.0))
        + 64.0 * 1.192092896e-7 * (vec2<f32>(1.0) + abs(expected));
    if (any(abs(observed - expected) > tolerance)) { return vertex; }
    let currentDepth = cbOutgoing.current.projection.x + cbOutgoing.current.projection.y / current.z;
    if (!(currentDepth > 0.0 && currentDepth < 1.0)) { return vertex; }
    vertex.sourcePixel = pixel; vertex.previousDepth = depth;
#if FFX_OUTGOING_SOURCE_CURRENT
    vertex.previousUv = older.xy;
#else
    vertex.previousUv = uv;
#endif
    vertex.currentUv = current.xy;
    vertex.currentDepth = currentDepth; vertex.valid = true;
    return vertex;
}
