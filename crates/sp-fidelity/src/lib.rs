//! Rust and WGSL port of the AMD FidelityFX SDK 1.1.4 (revision
//! `c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`, vendored at `vendor/sdk-1.1.4`):
//! the host, and the GPU passes as hand-written WGSL.
//!
//! A graphics API backend implements [`interface::FfxInterface`], as AMD's DX12
//! and Vulkan backends implement `FfxInterface`; `sp-fidelity-wgpu` is the
//! wgpu one. The crate contains nothing that is not in the SDK.
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
//! | `src/shared/ffx_object_management.{h,cpp}` | [`object_management`] |
//! | `src/backends/shared/ffx_shader_blobs.cpp`, `blob_accessors/` | [`blob_accessors`] |
//! | `include/FidelityFX/gpu/` (`FFX_CPU` parts) | [`gpu`] |
//! | `include/FidelityFX/gpu/`, `src/backends/dx12/shaders/` (as WGSL) | [`shaders`] |
pub(crate) mod assert;
pub mod blob_accessors;
pub mod error;
pub mod fsr2;
pub mod gpu;
pub mod interface;
pub mod message;
pub mod object_management;
pub mod shaders;
pub mod types;
pub mod util;
