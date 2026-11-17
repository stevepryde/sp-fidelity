# sp-fidelity

Frame generation is experimental and unsupported because visual artifacts remain.
It is disabled by default behind `frame-generation`.
[C++ reproductions](https://github.com/stevepryde/sp-fidelity/tree/main/crates/sp-fidelity-oracle/repro/frameinterpolation_edges) are retained and fixes are welcome;
no further frame-generation development is planned.

[![sp-fidelity on crates.io](https://img.shields.io/crates/v/sp-fidelity.svg?label=sp-fidelity)](https://crates.io/crates/sp-fidelity)
[![sp-fidelity docs](https://docs.rs/sp-fidelity/badge.svg)](https://docs.rs/sp-fidelity)
[![sp-fidelity-wgpu on crates.io](https://img.shields.io/crates/v/sp-fidelity-wgpu.svg?label=sp-fidelity-wgpu)](https://crates.io/crates/sp-fidelity-wgpu)
[![sp-fidelity-wgpu docs](https://docs.rs/sp-fidelity-wgpu/badge.svg)](https://docs.rs/sp-fidelity-wgpu)

A standalone, unofficial Rust and WGSL port with documented corrections of the FSR2 and FSR3.1.4 C++ and HLSL
source in [AMD FidelityFX SDK 1.1.4](crates/sp-fidelity/vendor/sdk-1.1.4/source-revision.txt),
produced entirely using AI coding agents, with a wgpu backend.
Not affiliated with, endorsed by, or supported by AMD. Vendored C++/HLSL remains
unchanged; the port's corrections of verified SDK bugs (FSR2's accumulate at the
frame's edges, [SDK-P35](crates/sp-fidelity/CONFORMANCE.md#sdk-p35--fsr2-accumulate-border-taps-in-the-rectification-box),
[SDK-P36](crates/sp-fidelity/CONFORMANCE.md#sdk-p36--fsr2-accumulate-writes-a-weightless-upsample-unnormalised)
and [SDK-P37](crates/sp-fidelity/CONFORMANCE.md#sdk-p37--fsr2-accumulate-deringing-bounds-take-off-screen-taps))
and Rust-only frame-interpolation corrections and their limits are described
in the [conformance record](crates/sp-fidelity/CONFORMANCE.md#sdk-p34--outgoing-stationary-geometry).

## Features

| Feature | Status |
| --- | --- |
| FSR2 temporal upscaling: Quality, Balanced, Performance, Ultra Performance | Supported |
| HDR, dynamic resolution, automatic exposure, RCAS sharpening | Supported |
| All FSR2 GPU passes, FP32 and optional FP16 permutations | Supported |
| FSR3.1.4 temporal upscaling | Supported; see conformance record |
| FSR3 frame generation and composite generation API | Unsupported; retained for diagnostics |
| Native frame-generation presentation and pacing | Unsupported; retained for diagnostics |
| Supporting SDK host core, GPU core and SPD | Supported |
| Native wgpu backend | Supported; conformance recorded on Apple Metal |
| WASM compilation (`wasm32-unknown-unknown`) | Supported |
| Other FidelityFX effects | Planned |
| FSR2/FSR3 execution in browser WebGPU, forced wave64 | Not supported |

Recorded FSR2 conformance against the original: **9 host test cases, 16,866
matching host events, and 64,005 bit-exact GPU output comparisons**.
See [CONFORMANCE.md](crates/sp-fidelity/CONFORMANCE.md) for the full results,
known differences and platform limitations. DX12/Vulkan conformance is not
yet established.

## Use

Add the crates.io dependencies:

```toml
[dependencies]
sp-fidelity = "0.3.2"
sp-fidelity-wgpu = "0.3.2"
wgpu = "30.0.1"
```

0.3.2 corrects SDK-P36 and SDK-P37, which change FSR2's output at the frame's
edges where history comes from off screen or the neighbourhood crosses the
edge; the API is unchanged and applications need no code changes.

Use the standalone `fsr2` or `fsr3upscaler` APIs for temporal upscaling.
The `fsr3` and `fsr3_present` examples exercise the unsupported frame-generation
implementation with `--features frame-generation` for development and reproduction;
they are not integration recommendations. Its retained presentation contract is
in [PRESENTATION.md](PRESENTATION.md).

See the [core crate](crates/sp-fidelity/README.md) and
[wgpu integration guide](crates/sp-fidelity-wgpu/README.md).

## License

[MIT](LICENSE). AMD's original copyright and permission notices are retained.
