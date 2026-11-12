// sp-fidelity true prior visibility, MIT; SDK-P29.
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 7) var r_edge_previous_depth: texture_2d<f32>;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + 8) var r_edge_previous_motion: texture_2d<f32>;

fn EdgeUnproject(uv: vec2<f32>, z: f32, camera: EdgeCamera) -> vec3<f32> {
    let xy = (uv * 2.0 - 1.0) * camera.projection.zw * z;
    return camera.position.xyz + camera.right.xyz * xy.x - camera.up.xyz * xy.y + camera.forward.xyz * z;
}

fn EdgePreviousVisibility(midpoint: vec2<f32>, game: VectorFieldEntry, currentDepth: f32) -> f32 {
    let size = vec2<f32>(RenderSize());
    let currentUv = midpoint - game.fMotionVector;
    let previousUv = midpoint + game.fMotionVector;
    if (!IsUvInside(previousUv)) { return 1.0; }
    let priorRasterUv = previousUv + cbEdge.previous.jitter.xy / size;

    // A secondary vector extrapolates current geometry; it cannot turn a
    // moving prior object into a static outgoing surface. Reject that source
    // only when the current source is outside and prior actual motion proves
    // the old object does not follow the camera's static-scene reprojection.
    if (game.bSecondary && !IsUvInside(currentUv)) {
        let pixel = vec2<i32>(floor(priorRasterUv * size));
        if (!IsOnScreen(pixel, RenderSize())) { return 1.0; }
        let depth = textureLoad(r_edge_previous_depth, pixel, 0).x;
        if (!(depth > 0.0 && depth < 1.0)) { return 1.0; }
        let uv = (vec2<f32>(pixel) + 0.5 - cbEdge.previous.jitter.xy) / size;
        let z = cbEdge.previous.projection.y / (depth - cbEdge.previous.projection.x);
        let world = EdgeUnproject(uv, z, cbEdge.previous);
        let older = EdgeProject(world, cbEdge.older);
        if (!(older.z > 0.0)) { return 1.0; }
        let observed = textureLoad(r_edge_previous_motion, pixel, 0).xy;
        return select(1.0, 0.0, any(abs((older.xy - uv - observed) * size) > vec2<f32>(2.0)));
    }
    if (!game.bPrimary || game.bInPainted || !(currentDepth > 0.0 && currentDepth < 1.0)) { return 1.0; }
    let z = cbEdge.current.projection.y / (currentDepth - cbEdge.current.projection.x);
    let world = EdgeUnproject(currentUv, z, cbEdge.current);
    let previous = EdgeProject(world, cbEdge.previous);
    if (!(previous.z > 0.0)) { return 1.0; }
    // Camera-only reprojection applies only where the actual game vector
    // agrees. Moving current primaries retain the SDK's existing visibility.
    if (any(abs((previous.xy - previousUv) * size) > vec2<f32>(2.0))) { return 1.0; }

    // Bilinear 2x2 support expanded by the one-pixel nearest-depth dilation
    // radius: 4x4. Reject only when EVERY supported actual prior sample is
    // nearer; this tolerates slopes and subpixel jitter without inventing an
    // occluder from the nearest sample alone.
    let base = vec2<i32>(floor((previous.xy + cbEdge.previous.jitter.xy / size) * size - 0.5));
#if FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
    var farDepth = 1.0;
#else
    var farDepth = 0.0;
#endif
    var samples = 0u;
    for (var y = -1; y <= 2; y++) {
        for (var x = -1; x <= 2; x++) {
            let pixel = base + vec2<i32>(x, y);
            if (!IsOnScreen(pixel, RenderSize())) { continue; }
            let depth = textureLoad(r_edge_previous_depth, pixel, 0).x;
#if FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
            farDepth = min(farDepth, depth);
#else
            farDepth = max(farDepth, depth);
#endif
            samples++;
        }
    }
    if (samples == 0u || !(farDepth > 0.0 && farDepth < 1.0)) { return 1.0; }
    let farZ = cbEdge.previous.projection.y / (farDepth - cbEdge.previous.projection.x);
    // The SDK's ComputeDepthClip separation allowance, evaluated entirely in
    // PREVIOUS camera units and FOV rather than mixing two depth conventions.
    let kFov = length(vec3<f32>(cbEdge.previous.projection.zw, 1.0));
    let separation = 1.37e-05 * kFov * length(size) * min(previous.z, farZ);
    return select(1.0, 0.0, previous.z - farZ > separation);
}
