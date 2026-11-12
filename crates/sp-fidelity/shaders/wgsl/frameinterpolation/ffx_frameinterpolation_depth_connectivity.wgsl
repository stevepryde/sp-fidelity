// Depth-image mesh connectivity, MIT. No edges across unsupported depth jumps.
fn GeometryDepthConnected(aPixel: vec2<i32>, bPixel: vec2<i32>, aDepth: f32, bDepth: f32) -> bool {
    let jump = abs(aDepth - bDepth);
    let roundoff = 4.0 * 1.192092896e-7 * max(abs(aDepth), abs(bDepth));
    if (jump <= roundoff) { return true; }
    let step = bPixel - aPixel;
    var supported = false;
    let before = aPixel - step;
    if (IsOnScreen(before, RenderSize())) {
        let depth = textureLoad(r_outgoing_depth, before, 0).x;
        if (!(depth > 0.0 && depth < 1.0) || jump > 2.0 * abs(depth - aDepth) + roundoff) { return false; }
        supported = true;
    }
    let after = bPixel + step;
    if (IsOnScreen(after, RenderSize())) {
        let depth = textureLoad(r_outgoing_depth, after, 0).x;
        if (!(depth > 0.0 && depth < 1.0) || jump > 2.0 * abs(depth - bDepth) + roundoff) { return false; }
        supported = true;
    }
    return supported;
}
