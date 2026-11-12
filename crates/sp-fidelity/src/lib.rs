//! Rust and WGSL ports of FSR2 and FSR3.1.4 temporal upscaling from AMD
//! FidelityFX SDK 1.1.4 (`c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`).
//! The original source and notices are retained in `vendor/sdk-1.1.4`.
//! This unofficial port was produced using AI coding agents and is not
//! affiliated with, endorsed by, or supported by AMD.
//!
//! Frame generation has remaining visual artifacts and is unsupported. Its
//! modules and shaders require the opt-in `frame-generation` feature.
//!
//! A graphics API backend implements [`interface::FfxInterface`], as AMD's DX12
//! and Vulkan backends implement `FfxInterface`; `sp-fidelity-wgpu` is the
//! wgpu one. SDK departures are documented in the conformance record.
//!
//! | SDK source | Module |
//! |---|---|
//! | `include/FidelityFX/host/ffx_types.h` | [`types`] |
//! | `include/FidelityFX/host/ffx_error.h` | [`error`] |
//! | `include/FidelityFX/host/ffx_assert.h` (`FFX_ASSERT`) | `assert` |
//! | `include/FidelityFX/host/ffx_interface.h` | [`interface`] |
//! | `include/FidelityFX/host/ffx_message.h`, `src/shared/ffx_message.cpp` | [`message`] |
//! | `include/FidelityFX/host/ffx_util.h` | [`util`] |
//! | `include/FidelityFX/host/ffx_fsr2.h`, `src/components/fsr2/` | [`fsr2`] |
//! | `include/FidelityFX/host/ffx_fsr3upscaler.h`, `src/components/fsr3upscaler/` | [`fsr3upscaler`] |
//! | `include/FidelityFX/host/ffx_opticalflow.h`, `src/components/opticalflow/` | `opticalflow` (feature `frame-generation`) |
//! | `include/FidelityFX/host/ffx_frameinterpolation.h`, `src/components/frameinterpolation/` | `frameinterpolation` (feature `frame-generation`) |
//! | `include/FidelityFX/host/ffx_fsr3.h`, `src/components/fsr3/` | `fsr3` (feature `frame-generation`) |
//! | `src/shared/ffx_object_management.{h,cpp}` | [`object_management`] |
//! | `src/backends/shared/ffx_shader_blobs.cpp`, `blob_accessors/` | [`blob_accessors`] |
//! | `include/FidelityFX/gpu/` (`FFX_CPU` parts) | [`gpu`] |
//! | `include/FidelityFX/gpu/`, `src/backends/dx12/shaders/` (as WGSL) | [`shaders`] |
pub(crate) mod assert;
pub mod blob_accessors;
pub mod error;
#[cfg(feature = "frame-generation")]
pub mod frameinterpolation;
pub mod fsr2;
#[cfg(feature = "frame-generation")]
pub mod fsr3;
pub mod fsr3upscaler;
pub mod gpu;
pub mod interface;
pub mod message;
pub mod object_management;
#[cfg(feature = "frame-generation")]
pub mod opticalflow;
pub mod shaders;
pub mod types;
pub mod util;
