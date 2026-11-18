// R11G11B10_FLOAT has the binary16 exponent range, 6/6/5 mantissa bits,
// unsigned components and subnormals. Typed stores round toward zero, so later
// hardware-filtered samples see the packed texture's representable RGB values.
fn sdk_unsigned_float(value: f32, fraction_bits: u32) -> f32 {
    let magnitude = max(value, 0.0);
    let biased_exponent = (bitcast<u32>(magnitude) >> 23u) & 255u;
    if (biased_exponent == 255u) { return magnitude; }
    let exponent = clamp(i32(biased_exponent) - 127, -14, 15);
    let step = bitcast<f32>(u32(exponent + 127 - i32(fraction_bits)) << 23u);
    let maximum = 65536.0 - f32(32768u >> fraction_bits);
    return floor(min(magnitude, maximum) / step) * step;
}

fn sdk_store_average(pixel: vec2i, value: vec4f) {
    let packed = vec3f(sdk_unsigned_float(value.x, 6u), sdk_unsigned_float(value.y, 6u),
                       sdk_unsigned_float(value.z, 5u));
    textureStore(rw_average_radiance, pixel, vec4f(packed, 1.0));
}
