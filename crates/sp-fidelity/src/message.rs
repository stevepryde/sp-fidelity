//! Port of `sdk/include/FidelityFX/host/ffx_message.h` and
//! `sdk/src/shared/ffx_message.cpp` (FidelityFX SDK 1.1.4).
//!
//! `ffxPrintMessage` passes a message to the registered callback, as the
//! SDK's `_WIN32` build does. Without a callback that build formats the
//! message for `OutputDebugStringW`, a Windows debugger API a safe Rust crate
//! cannot call; the message is dropped, as every non-Windows SDK build drops
//! all messages.
use super::types::FfxMessageCallback;
use std::sync::Mutex;

/// `s_messageCallback` and `s_debugLevel`.
static S_MESSAGE: Mutex<(Option<FfxMessageCallback>, u32)> = Mutex::new((None, 0));

/// `ffxSetPrintMessageCallback`.
pub fn ffx_set_print_message_callback(callback: Option<FfxMessageCallback>, debug_level: u32) {
    *S_MESSAGE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner) = (callback, debug_level);
}

/// `ffxPrintMessage`. `FFX_PRINT_MESSAGE(type, msg)` is
/// `ffx_print_message(type as u32, msg)`.
pub fn ffx_print_message(message_type: u32, message: &str) {
    let (callback, _debug_level) = *S_MESSAGE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(callback) = callback {
        callback(message_type, message);
    }
}
