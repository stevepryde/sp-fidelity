//! Ports of the `FFX_CPU` parts of `sdk/include/FidelityFX/gpu/` headers
//! (FidelityFX SDK 1.1.4): host code the components include from the GPU
//! headers. The GPU parts are WGSL in [`crate::shaders`].
//!
//! | SDK header | Module |
//! |---|---|
//! | `ffx_core_cpu.h` | [`core_cpu`] |
//! | `spd/ffx_spd.h` (`ffxSpdSetup`) | [`spd`] |
//! | `fsr1/ffx_fsr1.h` (`FsrRcasCon`) | [`fsr1`] |
pub mod core_cpu;
pub mod fsr1;
pub mod spd;
