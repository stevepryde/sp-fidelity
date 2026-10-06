# sp-fidelity

[![sp-fidelity on crates.io](https://img.shields.io/crates/v/sp-fidelity.svg?label=sp-fidelity)](https://crates.io/crates/sp-fidelity)
[![sp-fidelity docs](https://docs.rs/sp-fidelity/badge.svg)](https://docs.rs/sp-fidelity)
[![sp-fidelity-wgpu on crates.io](https://img.shields.io/crates/v/sp-fidelity-wgpu.svg?label=sp-fidelity-wgpu)](https://crates.io/crates/sp-fidelity-wgpu)
[![sp-fidelity-wgpu docs](https://docs.rs/sp-fidelity-wgpu/badge.svg)](https://docs.rs/sp-fidelity-wgpu)

A standalone, unofficial 1:1 Rust and WGSL port of the FSR2 C++ and HLSL
source in [AMD FidelityFX SDK 1.1.4](crates/sp-fidelity/vendor/sdk-1.1.4/source-revision.txt),
produced entirely using AI coding agents, with a wgpu backend.
Not affiliated with, endorsed by, or supported by AMD.

## Features

| Feature | Status |
| --- | --- |
| FSR2 temporal upscaling: Quality, Balanced, Performance, Ultra Performance | Supported |
| HDR, dynamic resolution, automatic exposure, RCAS sharpening | Supported |
| All FSR2 GPU passes, FP32 and optional FP16 permutations | Supported |
| Supporting SDK host core, GPU core and SPD | Supported |
| Native wgpu backend | Supported; conformance recorded on Apple Metal |
| WASM compilation (`wasm32-unknown-unknown`) | Supported |
| Other FidelityFX effects | Planned |
| FSR2 execution in browser WebGPU, forced wave64 | Not supported |

Recorded conformance against the original: **9 host test cases, 16,866
matching host events, and 64,005 bit-exact GPU output comparisons**.
See [CONFORMANCE.md](crates/sp-fidelity/CONFORMANCE.md) for the full results,
known differences and platform limitations. DX12/Vulkan conformance is not
yet established.

## Use

Add the crates.io dependencies:

```toml
[dependencies]
sp-fidelity = "0.2.0"
sp-fidelity-wgpu = "0.2.0"
wgpu = "30.0.1"
```

See the [core crate](crates/sp-fidelity/README.md) and
[wgpu integration guide](crates/sp-fidelity-wgpu/README.md).

## License

[MIT](LICENSE). AMD's original copyright and permission notices are retained.
