// WGSL: the conversions of the SDK's typed UAV stores, for a backend that
// allocates a narrow storage format as a wider one WebGPU's core set can
// write. A typed store converts in hardware; a wider texture does not, so the
// store converts first and the wider texel then holds exactly what the SDK's
// would return. Not part of the SDK: its HLSL leaves these to the UAV.

// R11G11B10_FLOAT has the binary16 exponent range, 6/6/5 mantissa bits,
// unsigned components and subnormals. Typed stores round toward zero, so later
// hardware-filtered samples see the packed texture's representable RGB values.
fn ffxWgslUnsignedFloat(value: f32, fraction_bits: u32) -> f32 {
    let magnitude = max(value, 0.0);
    let biased_exponent = (bitcast<u32>(magnitude) >> 23u) & 255u;
    if (biased_exponent == 255u) { return magnitude; }
    let exponent = clamp(i32(biased_exponent) - 127, -14, 15);
    let step = bitcast<f32>(u32(exponent + 127 - i32(fraction_bits)) << 23u);
    let maximum = 65536.0 - f32(32768u >> fraction_bits);
    return floor(min(magnitude, maximum) / step) * step;
}

fn ffxWgslR11G11B10Float(value: vec3f) -> vec3f {
    return vec3f(ffxWgslUnsignedFloat(value.x, 6u), ffxWgslUnsignedFloat(value.y, 6u),
                 ffxWgslUnsignedFloat(value.z, 5u));
}

// What an R8_UNORM texel holding `code` (0 to 255) returns: code / 255
// rounded to the nearest float. In binary, code / 255 is code's eight bits
// repeating, so the 24-bit mantissa is that pattern from its leading one and
// the bits cut off, the same pattern again, are always more than half a unit:
// no division, whose rounding WGSL does not fix.
fn ffxWgslUnorm8Value(code: u32) -> f32 {
    if (code == 0u) { return 0.0; }
    if (code >= 255u) { return 1.0; }
    let leading = countLeadingZeros(code) - 24u;
    let pattern = ((code << leading) | (code >> (8u - leading))) & 0xffu;
    return bitcast<f32>(((126u - leading) << 23u) | ((pattern * 0x010101u + 1u) & 0x7fffffu));
}

// What an R8_UNORM texel returns after a store of `value`: the store clamps
// to [0, 1] (a NaN stores 0) and rounds value * 255 to the nearest code. The
// product is taken on the float's integer mantissa, where it is exact: a
// float multiply rounds it first and can carry a value just under a half up
// to the next code.
fn ffxWgslUnorm8(value: f32) -> f32 {
    if (!(value > 0.0)) { return 0.0; }
    if (value >= 1.0) { return 1.0; }
    let bits = bitcast<u32>(value);
    // value = mantissa * 2^-shift, with shift at least 24 below 1.
    let shift = 150u - (bits >> 23u);
    // Under 2^-9 (subnormals among them) the product is under a half.
    if (shift > 32u) { return 0.0; }
    let product = ((bits & 0x7fffffu) | 0x800000u) * 255u;
    if (shift == 32u) { return ffxWgslUnorm8Value(product >> 31u); }
    return ffxWgslUnorm8Value((product >> shift) + ((product >> (shift - 1u)) & 1u));
}
