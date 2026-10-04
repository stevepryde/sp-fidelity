//! Port of `FFX_ASSERT`, `FFX_ASSERT_MESSAGE` and `FFX_ASSERT_FAIL` from `sdk/include/FidelityFX/host/ffx_assert.h`
//! (FidelityFX SDK 1.1.4). The condition is always evaluated, as in both SDK
//! build variants; only debug builds check it.

/// `FFX_ASSERT(condition)`.
macro_rules! ffx_assert {
    ($condition:expr) => {{
        let condition: bool = $condition;
        debug_assert!(condition, stringify!($condition));
    }};
}
pub(crate) use ffx_assert;

/// `FFX_ASSERT_MESSAGE(condition, message)`.
macro_rules! ffx_assert_message {
    ($condition:expr, $message:expr) => {{
        let condition: bool = $condition;
        debug_assert!(condition, "{}", $message);
    }};
}
pub(crate) use ffx_assert_message;

/// `FFX_ASSERT_FAIL(message)`.
macro_rules! ffx_assert_fail {
    ($message:expr) => {
        debug_assert!(false, "{}", $message)
    };
}
pub(crate) use ffx_assert_fail;
