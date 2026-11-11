# sp-fidelity

A standalone, unofficial 1:1 Rust and WGSL port of the FSR2 and FSR3.1.4 C++ and HLSL
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
- FSR3.1.4 upscaling, including Native AA and runtime tuning; optical flow,
  frame interpolation, and the composite FSR3 host API.
- Supporting SDK host core, GPU core and SPD; no Rust dependencies.
- Other FidelityFX effects are planned.

The [`sp-fidelity-wgpu`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity-wgpu/README.md)
backend implements `interface::FfxInterface`. Both crates compile for
`wasm32-unknown-unknown`, but FSR2/FSR3 execution in browser WebGPU and forced
wave64 are not supported. The upscaled output uses RGBA16F. The SDK's
standalone generate-reactive host call remains a no-op; its GPU pass is ported.

## FSR3.1.4

The modules mirror the SDK components: `fsr3upscaler`, `opticalflow`,
`frameinterpolation`, and their `fsr3` orchestrator. FSR2 remains available
through its existing API. The upscaler's standalone dispatch requires the
three caller-owned shared textures returned by
`ffx_fsr3_upscaler_get_shared_resource_descriptions`; the composite FSR3
context allocates these and the optical-flow resources itself.

With wgpu, use clones of one backend interface for all three composite
interfaces. `ffx_fsr3_get_frame_generation_callback` creates a callback with
weak ownership of the context; invoke it on the context's thread. Configuration
forwards to the application's presentation scheduler through the backend's
`set_frame_generation_configurator` hook. The application owns presentation,
UI composition, and frame pacing; no DXGI/Vulkan proxy swapchain is provided.
See the backend's [combined example](../sp-fidelity-wgpu/examples/fsr3.rs).

The pinned composite C++ leaves its private mode flags zero and omits
`upscaleSize` forwarding. Those behaviors are preserved: composite
interpolation-only creation is unsupported, and composite upscaling uses the
upscaler's zero-size fallback. The standalone interpolation component supports
prepare and interpolation without the upscaler. The declared upstream
`ffxFsr3SkipPresent` has no implementation in this SDK revision and is not
exported by the Rust port.

## Conformance

FSR2 recorded against the original: **9 host test cases, 16,866 matching host
events, and 64,005 bit-exact GPU output comparisons**.
[CONFORMANCE.md](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md)
records the full results, adaptations and known differences. GPU results
are from Apple Metal; DX12/Vulkan conformance is not yet established.

## License

MIT. See `LICENSE.txt`; AMD's original copyright and permission notices are retained.
