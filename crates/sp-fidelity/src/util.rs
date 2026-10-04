//! Port of the `sdk/include/FidelityFX/host/ffx_util.h` helpers used by the
//! ported effects (FidelityFX SDK 1.1.4).

/// `FFX_PI`: the value of Pi.
#[expect(
    clippy::approx_constant,
    clippy::excessive_precision,
    reason = "the SDK's literal, which is `f32::consts::PI`"
)]
pub const FFX_PI: f32 = 3.141_592_653_589_793;

/// `FFX_EPSILON`: an epsilon value for floating point numbers.
pub const FFX_EPSILON: f32 = 1e-06;

/// `FFX_MAKE_VERSION(major, minor, patch)`.
pub const fn ffx_make_version(major: u32, minor: u32, patch: u32) -> u32 {
    (major << 22) | (minor << 12) | patch
}

/// `FFX_DIVIDE_ROUNDING_UP(x, y)`.
pub const fn ffx_divide_rounding_up(x: u32, y: u32) -> u32 {
    // C unsigned arithmetic wraps.
    x.wrapping_add(y).wrapping_sub(1) / y
}

/// `FFX_CONTAINS_FLAG(options, key)`.
pub const fn ffx_contains_flag(options: u32, key: u32) -> bool {
    (options & key) == key
}
