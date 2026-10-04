//! Development-only oracles for the `sp-fidelity` port: AMD's unchanged C++
//! host (`oracle/host.cpp` with an effect driver) and the DXC-compiled
//! unchanged HLSL executed on Metal (`oracle/metal.mm`). An effect plugs in
//! through an [`Effect`]. See the README.
pub mod compare;
pub mod gpu;
pub mod host;
pub mod pass;
pub mod recorder;

pub use host::Effect;

/// FSR2: `sdk/src/components/fsr2/ffx_fsr2.cpp` driven by `oracle/fsr2_host.cpp`.
pub const FSR2: Effect = Effect {
    name: "fsr2",
    stages: &[
        "fsr2_depth_clip",
        "fsr2_reconstruct_previous_depth",
        "fsr2_lock",
        "fsr2_accumulate",
        "fsr2_accumulate_sharpen",
        "fsr2_rcas",
        "fsr2_compute_luminance_pyramid",
        "fsr2_generate_reactive",
        "fsr2_tcr_autogenerate",
    ],
    driver: "fsr2_host.cpp",
    sources: &["src/components/fsr2/ffx_fsr2.cpp"],
    includes: &[],
};
