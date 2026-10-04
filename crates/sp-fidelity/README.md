# sp-fidelity

A standalone, unofficial 1:1 Rust and WGSL port of the FSR2 C++ and HLSL
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
- Supporting SDK host core, GPU core and SPD; no Rust dependencies.
- Other FidelityFX effects are planned.

The [`sp-fidelity-wgpu`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity-wgpu/README.md)
backend implements `interface::FfxInterface`. Both crates compile for
`wasm32-unknown-unknown`, but FSR2 execution in browser WebGPU and forced
wave64 are not supported. The upscaled output uses RGBA16F. The SDK's
standalone generate-reactive host call remains a no-op; its GPU pass is ported.

## Conformance

Recorded against the original: **9 host test cases, 16,866 matching host
events, and 64,017 bit-exact GPU output comparisons**.
[CONFORMANCE.md](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md)
records the full results, adaptations and known differences. GPU results
are from Apple Metal; DX12/Vulkan conformance is not yet established.

## License

MIT. See `LICENSE.txt`; AMD's original copyright and permission notices are retained.
