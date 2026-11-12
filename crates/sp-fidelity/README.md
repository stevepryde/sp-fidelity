# sp-fidelity

A standalone, unofficial Rust and WGSL port of the FSR2 and FSR3.1.4 C++ and HLSL
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

The original algorithms are retained, with documented platform adaptations and
an optional camera-supported frame-interpolation edge extension described in
[CONFORMANCE.md](CONFORMANCE.md#sdk-p29--camera-supported-outgoing-edge-reconstruction).

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
forwards through the backend's `set_frame_generation_configurator` hook.
The native backend's `presentation::FrameInterpolationSwapchain` installs this
hook and ports AMD's pacing, UI composition and presentation scheduling to a
caller-owned wgpu surface. A custom scheduler can install the hook instead.
See the [windowed example](../sp-fidelity-wgpu/examples/fsr3_present.rs) and
[backend integration guide](../sp-fidelity-wgpu/README.md#native-presentation).

The pinned composite C++ leaves its private mode flags zero and omits
`upscaleSize` forwarding. Those behaviors are preserved: composite
interpolation-only creation is unsupported, and composite upscaling uses the
upscaler's zero-size fallback. The standalone interpolation component supports
prepare and interpolation without the upscaler. The declared upstream
`ffxFsr3SkipPresent` has no implementation in this SDK revision and is not
exported by the Rust port.

### Optional camera-supported outgoing edges

For a symmetric perspective camera, populate prepare's existing
`camera_position`, `camera_right`, `camera_up`, and `camera_forward` fields.
The axes must be finite orthonormal unit vectors, with forward pointing into
view. Position, near/far distances and scene depth use the same world units.
Supply the matching near/far, vertical FOV, render dimensions and frame ID on
prepare and dispatch; the SDK's reversed-depth near/far ordering is accepted.
The jitter is the raster UV offset in render pixels: raster UV equals stable
UV plus jitter divided by render size. Motion vectors must be unjittered,
using the existing SDK scale/sign convention.

The port retains actual previous depth and motion. With two earlier camera
poses it reprojects static geometry that has left the current viewport into
the intermediate frame. Finite depth-cell triangles cover magnified
surfaces; depth discontinuities split the mesh. It checks camera-predicted
motion against the previous game motion to reject moving objects. Actual
previous depth rejects old occluders when current geometry alone would wrongly
reuse their colors. Aligned source contributions fade smoothly at the image
boundary, preserving the existing color-inpainting fallback. The original
current-frame reconstruction, optical flow and inpainting remain in use;
the camera-enabled disocclusion variant adds prior-visibility rejection.
The extension adds two render-size textures (8 bytes per maximum render pixel),
two copies and one compute pass. Textures and pipeline are allocated lazily.

Leave the basis zero to use the original AMD path. Invalid camera metadata,
jittered motion-vector mode or a nonzero distortion-field resource disables
reconstruction. Reset after camera cuts or world-origin changes. Explicit
reset, nonconsecutive IDs, missing prepare metadata, render/display/viewport
changes, attached distortion fields and GPU job execution failures discard
geometry history; two new history frames are needed. Outgoing dynamic objects,
sky and cells that exceed the bounded rasterization work budget continue to
use the original fallback. Camera-motion agreement is a conservative static
surface estimate, not object identity or a prediction of future object motion.

## Conformance

FSR2 recorded against the original: **9 host test cases, 16,866 matching host
events, and 64,005 bit-exact GPU output comparisons**.
[CONFORMANCE.md](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md)
records the full results, adaptations and known differences. GPU results
are from Apple Metal; DX12/Vulkan conformance is not yet established.

## License

MIT. See `LICENSE.txt`; AMD's original copyright and permission notices are retained.
