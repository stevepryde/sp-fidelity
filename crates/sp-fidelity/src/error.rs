//! Port of `sdk/include/FidelityFX/host/ffx_error.h` (FidelityFX SDK 1.1.4).
//!
//! Fallible SDK functions return `Result<T, FfxErrorCode>`: `Ok` is `FFX_OK`
//! and `Err` carries one of the non-zero codes below.

/// `FfxErrorCode`.
pub type FfxErrorCode = i32;

pub const FFX_OK: FfxErrorCode = 0;
pub const FFX_ERROR_INVALID_POINTER: FfxErrorCode = 0x8000_0000_u32 as i32;
pub const FFX_ERROR_INVALID_ALIGNMENT: FfxErrorCode = 0x8000_0001_u32 as i32;
pub const FFX_ERROR_INVALID_SIZE: FfxErrorCode = 0x8000_0002_u32 as i32;
pub const FFX_EOF: FfxErrorCode = 0x8000_0003_u32 as i32;
pub const FFX_ERROR_INVALID_PATH: FfxErrorCode = 0x8000_0004_u32 as i32;
pub const FFX_ERROR_EOF: FfxErrorCode = 0x8000_0005_u32 as i32;
pub const FFX_ERROR_MALFORMED_DATA: FfxErrorCode = 0x8000_0006_u32 as i32;
pub const FFX_ERROR_OUT_OF_MEMORY: FfxErrorCode = 0x8000_0007_u32 as i32;
pub const FFX_ERROR_INCOMPLETE_INTERFACE: FfxErrorCode = 0x8000_0008_u32 as i32;
pub const FFX_ERROR_INVALID_ENUM: FfxErrorCode = 0x8000_0009_u32 as i32;
pub const FFX_ERROR_INVALID_ARGUMENT: FfxErrorCode = 0x8000_000a_u32 as i32;
pub const FFX_ERROR_OUT_OF_RANGE: FfxErrorCode = 0x8000_000b_u32 as i32;
pub const FFX_ERROR_NULL_DEVICE: FfxErrorCode = 0x8000_000c_u32 as i32;
pub const FFX_ERROR_BACKEND_API_ERROR: FfxErrorCode = 0x8000_000d_u32 as i32;
pub const FFX_ERROR_INSUFFICIENT_MEMORY: FfxErrorCode = 0x8000_000e_u32 as i32;
pub const FFX_ERROR_INVALID_VERSION: FfxErrorCode = 0x8000_000f_u32 as i32;
pub const FFX_ERROR_ACCESS_DENIED: FfxErrorCode = 0x8000_0010_u32 as i32;

/// `FFX_RETURN_ON_ERROR(x, y)`: return error code `y` when condition `x` is
/// not met.
macro_rules! ffx_return_on_error {
    ($x:expr, $y:expr) => {
        if !($x) {
            return Err($y);
        }
    };
}
pub(crate) use ffx_return_on_error;

/// `FFX_VALIDATE(x)`: return `x`'s error code when it is not `FFX_OK`.
macro_rules! ffx_validate {
    ($x:expr) => {
        $x?
    };
}
pub(crate) use ffx_validate;
