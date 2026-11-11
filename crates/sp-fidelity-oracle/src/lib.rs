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

/// Composite FSR3; build its oracle with all three constituent reflection tables.
pub const FSR3: Effect = Effect {
    name: "fsr3",
    stages: &[],
    driver: "fsr3_host.cpp",
    sources: &[
        "src/components/fsr3/ffx_fsr3.cpp",
        "src/components/fsr3upscaler/ffx_fsr3upscaler.cpp",
        "src/components/opticalflow/ffx_opticalflow.cpp",
        "src/components/frameinterpolation/ffx_frameinterpolation.cpp",
    ],
    includes: &[],
};

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

/// Original SDK fsr3upscaler host and GPU passes.
pub const FSR3UPSCALER: Effect = Effect {
    name: "fsr3upscaler",
    stages: &[
        "fsr3upscaler_prepare_inputs",
        "fsr3upscaler_luma_pyramid",
        "fsr3upscaler_shading_change_pyramid",
        "fsr3upscaler_shading_change",
        "fsr3upscaler_prepare_reactivity",
        "fsr3upscaler_luma_instability",
        "fsr3upscaler_accumulate",
        "fsr3upscaler_accumulate_sharpen",
        "fsr3upscaler_rcas",
        "fsr3upscaler_debug_view",
        "fsr3upscaler_generate_reactive",
        "fsr3upscaler_tcr_autogenerate",
    ],
    driver: "fsr3upscaler_host.cpp",
    sources: &["src/components/fsr3upscaler/ffx_fsr3upscaler.cpp"],
    includes: &[],
};

/// Original SDK opticalflow host and GPU passes.
pub const OPTICALFLOW: Effect = Effect {
    name: "opticalflow",
    stages: &[
        "opticalflow_prepare_luma",
        "opticalflow_generate_optical_flow_input_pyramid",
        "opticalflow_generate_scd_histogram",
        "opticalflow_compute_scd_divergence",
        "opticalflow_compute_optical_flow_advanced_v5",
        "opticalflow_filter_optical_flow_v5",
        "opticalflow_scale_optical_flow_advanced_v5",
    ],
    driver: "opticalflow_host.cpp",
    sources: &["src/components/opticalflow/ffx_opticalflow.cpp"],
    includes: &[],
};

/// Original SDK frameinterpolation host and GPU passes.
pub const FRAMEINTERPOLATION: Effect = Effect {
    name: "frameinterpolation",
    stages: &[
        "frameinterpolation_reconstruct_and_dilate",
        "frameinterpolation_setup",
        "frameinterpolation_reconstruct_prev_depth",
        "frameinterpolation_game_motion_vector_field",
        "frameinterpolation_optical_flow_vector_field",
        "frameinterpolation_disocclusion_mask",
        "frameinterpolation_interpolation",
        "frameinterpolation_inpainting_pyramid",
        "frameinterpolation_inpainting",
        "frameinterpolation_game_vector_field_inpainting_pyramid",
        "frameinterpolation_debug_view",
    ],
    driver: "frameinterpolation_host.cpp",
    sources: &["src/components/frameinterpolation/ffx_frameinterpolation.cpp"],
    includes: &[],
};
