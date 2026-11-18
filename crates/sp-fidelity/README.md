# sp-fidelity

Frame generation is experimental and unsupported because visual artifacts remain.
It is disabled by default behind `frame-generation`.
[C++ reproductions](https://github.com/stevepryde/sp-fidelity/tree/main/crates/sp-fidelity-oracle/repro/frameinterpolation_edges) are retained and fixes are welcome;
no further frame-generation development is planned.

A standalone, unofficial Rust and WGSL port of FSR2, FSR3.1.4 and the
FidelityFX Reflections Denoiser from the C++ and HLSL in
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
- Standalone FidelityFX Reflections Denoiser 1.3.
- Optional experimental frame-generation APIs for contributors.
- Supporting SDK host core, GPU core and SPD; no Rust dependencies.
- Other FidelityFX effects are planned.

The [`sp-fidelity-wgpu`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity-wgpu/README.md)
backend implements `interface::FfxInterface`. Both crates compile for
`wasm32-unknown-unknown`, but FSR2/FSR3 execution in browser WebGPU and forced
wave64 are not supported. The upscaled output uses RGBA16F. The SDK's
standalone generate-reactive host call remains a no-op; its GPU pass is ported.

## Reflections denoiser

AMD's SSSR calls this component after its ray intersection pass. A caller can
use the same denoiser with a screen-space or world-space ray tracer. Create
an `FfxDenoiserContext` with `FFX_DENOISER_REFLECTIONS`, the working size and
the format of the normals that will be copied to history. Keep one context
per independent view and size.

Call `ffx_denoiser_context_dispatch_reflections` once per frame. Supply
scene-linear incident radiance in RGB and world-space ray length in alpha
of `radiance_a`. Supply an estimate for a ray that misses (SSSR evaluates the
environment). A numeric black sample represents black light and contributes
to the filter. Pass the matching depth, world normals, roughness, motion,
camera transforms and list of packed 8×8 tile origins. The dispatch reads
three indirect workgroup counts at byte offset 12. The reference schedules
reprojection, prefiltering and temporal resolve on that same list.

Keep two caller-owned radiance textures and two variance textures. Supply
the previous result in `radiance_b` and its variance in `variance_b`; the
passes reuse those textures for scratch after reading them. The next frame
uses this frame's `radiance_a` and `variance_a` as its B pair. The host also
copies the resolved A texture to `output`. Only RGB is meaningful for
lighting there. AMD's shader stores blue in alpha. The SDK's `reset` clears
its two tile-average textures; callers that need to discard every history
can recreate the context and initialize their own textures.

The original [SSSR call site](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/c6efa6bf7f2027b3ec94f28578bb5965eabb9e55/sdk/src/components/sssr/ffx_sssr.cpp)
and [denoiser host](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/blob/c6efa6bf7f2027b3ec94f28578bb5965eabb9e55/sdk/src/components/denoiser/ffx_denoiser.cpp)
show the caller and component sides of this interface.

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
FSR2's accumulate pass corrects verified SDK bugs at the frame's edges, where
the render-resolution neighbourhood extends past the render size: taps there
darkened corners through the rectification box
([SDK-P35](CONFORMANCE.md#sdk-p35--fsr2-accumulate-border-taps-in-the-rectification-box))
and let ringing past the deringing bounds
([SDK-P37](CONFORMANCE.md#sdk-p37--fsr2-accumulate-deringing-bounds-take-off-screen-taps)),
and a new sample whose filter weights vanished there was written unnormalised,
dark or negative
([SDK-P36](CONFORMANCE.md#sdk-p36--fsr2-accumulate-writes-a-weightless-upsample-unnormalised)).
It is compared with the original HLSL with those corrections applied.
They change FSR2's output only near the frame's edges; the API is unchanged
and applications need no code changes.

Frame-generation diagnostics, limitations, and the documented Rust/WGSL
corrections remain in [CONFORMANCE.md](CONFORMANCE.md#sdk-p34--outgoing-stationary-geometry).
Vendored C++ and HLSL are unchanged.

## License

MIT. See `LICENSE.txt`; AMD's original copyright and permission notices are retained.
