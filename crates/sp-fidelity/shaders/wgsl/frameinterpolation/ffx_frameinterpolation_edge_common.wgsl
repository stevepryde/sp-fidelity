// sp-fidelity camera-supported edge reconstruction, MIT. SDK-P29.
struct EdgeCamera {
    position: vec4<f32>,
    right: vec4<f32>,
    up: vec4<f32>,
    forward: vec4<f32>,
    projection: vec4<f32>,
    jitter: vec4<f32>,
}
struct EdgeConstants {
    current: EdgeCamera,
    previous: EdgeCamera,
    older: EdgeCamera,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + 1) var<uniform> cbEdge: EdgeConstants;

// UV is unjittered; positive camera-forward distance is returned in z.
fn EdgeProject(world: vec3<f32>, camera: EdgeCamera) -> vec3<f32> {
    let relative = world - camera.position.xyz;
    let z = dot(relative, camera.forward.xyz);
    let xy = vec2<f32>(dot(relative, camera.right.xyz), -dot(relative, camera.up.xyz));
    return vec3<f32>(vec2<f32>(0.5) + xy / (2.0 * z * camera.projection.zw), z);
}

