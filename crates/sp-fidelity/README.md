# sp-fidelity

Frame generation is experimental and unsupported because visual artifacts remain.
It is disabled by default behind `frame-generation`.
[C++ reproductions](https://github.com/stevepryde/sp-fidelity/tree/main/crates/sp-fidelity-oracle/repro/frameinterpolation_edges) are retained and fixes are welcome;
no further frame-generation development is planned.

A standalone, unofficial Rust and WGSL port with documented corrections of the FSR2 and FSR3.1.4 C++ and HLSL
source in
[AMD FidelityFX SDK 1.1.4](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/tree/c6efa6bf7f2027b3ec94f28578bb5965eabb9e55),
produced entirely using AI coding agents. Not affiliated with, endorsed by,
or supported by AMD. The original sources and notices are retained unedited
in `vendor/sdk-1.1.4/`.

## Features

- FSR2 temporal upscaling with Quality, Balanced, Performance and Ultra
  Performance modes.
- HDR, dynamic resolution, automatic exposure and RCAS sharpening.
- Every FSR2 GPU pass in WGSL, with FP32 and optional FP16 permutations.
- FSR3.1.4 upscaling, including Native AA and runtime tuning.
- Optional experimental frame-generation APIs for contributors.
- Supporting SDK host core, GPU core and SPD; no Rust dependencies.
- Other FidelityFX effects are planned.

The [`sp-fidelity-wgpu`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity-wgpu/README.md)
backend implements `interface::FfxInterface`. Both crates compile for
`wasm32-unknown-unknown`, but FSR2/FSR3 execution in browser WebGPU and forced
wave64 are not supported. The upscaled output uses RGBA16F. The SDK's
standalone generate-reactive host call remains a no-op; its GPU pass is ported.

## FSR3.1.4

`fsr3upscaler` is the standalone temporal upscaler and is available by default,
alongside `fsr2`. Its dispatch requires the three caller-owned shared textures
returned by `ffx_fsr3_upscaler_get_shared_resource_descriptions`.

The optional `frame-generation` feature exposes `opticalflow`,
`frameinterpolation`, and the composite `fsr3` host API, plus their WGSL sources
and binding tables. It is intended for contributors investigating the remaining
artifacts. Enable it on this crate for a custom backend, or on
`sp-fidelity-wgpu`, which forwards it here. The retained composite API's known
SDK limitations and Rust-only corrections are recorded in
[CONFORMANCE.md](CONFORMANCE.md).

## Conformance

FSR2 recorded against the original: **9 host test cases, 16,866 matching host
events, and 64,005 bit-exact GPU output comparisons**.
[CONFORMANCE.md](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md)
records the full results, adaptations and known differences. GPU results
are from Apple Metal; DX12/Vulkan conformance is not yet established.
FSR2's accumulate pass corrects a verified SDK bug that darkened frame corners
([SDK-P35](CONFORMANCE.md#sdk-p35--fsr2-accumulate-border-taps-in-the-rectification-box));
it is compared with the original HLSL with that correction applied.

Frame-generation diagnostics, limitations, and the documented Rust/WGSL
corrections remain in [CONFORMANCE.md](CONFORMANCE.md#sdk-p34--outgoing-stationary-geometry).
Vendored C++ and HLSL are unchanged.

## License

MIT. See `LICENSE.txt`; AMD's original copyright and permission notices are retained.
