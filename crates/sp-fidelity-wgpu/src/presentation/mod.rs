//! AMD FSR3 frame-interpolation presentation, adapted to safe wgpu.
//!
//! The native adapter records SDK callbacks on their owner thread (AMD's
//! game-queue composition mode), observes GPU completion on a pacing thread,
//! and presents on a second thread. See the package README and CONFORMANCE.md
//! for the single-queue and native-swapchain adaptations.
//!
//! Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see LICENSE.txt.
#[cfg(not(target_arch = "wasm32"))]
mod composition;
#[cfg(not(target_arch = "wasm32"))]
mod native;
pub mod pacing;
#[cfg(not(target_arch = "wasm32"))]
pub use native::*;

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests;
