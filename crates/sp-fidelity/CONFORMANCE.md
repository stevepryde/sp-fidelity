# SDK conformance record

Frame generation is experimental and unsupported because visual artifacts remain.
It is disabled by default behind `frame-generation`.
[C++ reproductions](https://github.com/stevepryde/sp-fidelity/tree/main/crates/sp-fidelity-oracle/repro/frameinterpolation_edges) are retained and fixes are welcome;
no further frame-generation development is planned.

Authority: FidelityFX SDK 1.1.4, revision
`c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`, retained unedited in
`vendor/sdk-1.1.4`. Evidence comes from the two oracles in
[`sp-fidelity-oracle`](../sp-fidelity-oracle/README.md): AMD's unchanged C++ host
behind a recording `FfxInterface`, and the DXC-compiled unchanged pass HLSL on
Metal replaying each pass from the inputs the port's WGSL received.

FSR2 and FSR3.1.4 (upscaler, optical flow, frame interpolation and the
composite FSR3 host) are ported from that same revision. The original FSR2
results below are retained. The host core, `ffx_core.wgsl` and `spd/ffx_spd.wgsl` are verified here through FSR2.
Results are from Apple M5, Metal, wgpu 30.0.1 (MSL 4.0), DXC 1.9.0.5399
(HLSL 2021, the SDK's bundled compiler default), SPIRV-Cross 1.4.357,
2026-10-06.

## FidelityFX Reflections Denoiser 1.3

The reflection component comes from the same SDK revision as the upscalers.
`denoiser_host_event_stream` runs the vendored C++ and Rust across five frames
per configuration, with FP32, FP16 and FP16 with wave64 advertised. All 561
events matched, including constants, first-frame and reset clears, resource
bindings, indirect dispatches, output and history copies, and teardown.
The C++ passes its pass ID to the permutation helper in the flags position.
All three reflections pass IDs have the depth-inverted bit set. The Rust
host preserves this behavior. Wave64 selection in this comparison exercises
the host.

The C++ trace binds the previous frame's tile averages to prefilter and
temporal resolve. Resolve also reads the previous sample counts. Reprojection
writes the opposite average and sample-count surfaces for the next frame.
This ordering matters for narrow HDR highlights. In the independent FP16 HLSL
sequence, the three-pixel highlight's red channel at (2, 6) went from 4.0 to
0 on the first frame. At (4, 6) on the next frame it went from 4.0 to
0.2722168. These are measurements of AMD's denoiser on the fixture.

`denoiser_passes` runs the three original HLSL entries compiled with DXC and
SPIRV-Cross against the production WGSL. The 29×19 five-frame fixture moves a
highlight across a depth and normal discontinuity, translates the camera,
changes the active tile count and exercises reset and empty dispatch. Each
comparison covers the three passes' UAVs and all four SDK copy destinations.
With fast math and contraction disabled in both Metal pipelines, all 300
resource dumps matched byte-for-byte. Each precision (FP32 and FP16)
contributed 75 from identical pass inputs and 75 from the independently
carried sequence. Under wgpu's normal Metal fast math (SDK-P22), identical
inputs gave 8 differing dumps in FP32 and 9 in FP16. Independently carried
history gave 23 in each precision. The largest absolute difference at the
application output on these frames was 0.000244 in FP32 and 0.061035 in FP16.
The normal-run check rejects nonfinite texture channels and limits both the
largest channel error and the number of changed texels per dump. The ceilings
below were measured against the original HLSL on the Apple M5, using this
fixture. Each cell gives the maximum absolute channel error and maximum
differing texels in one dump.

| Precision and inputs | Radiance | Variance | Packed tile average |
| --- | --- | --- | --- |
| FP32, identical inputs | 0.000244140625 / 5 | 0.000244140625 / 72 | exact |
| FP32, carried history | 0.00048828125 / 9 | 0.000244140625 / 70 | exact |
| FP16, identical inputs | 0.06103515625 / 87 | 0.080078125 / 160 | exact |
| FP16, carried history | 0.072021484375 / 207 | 0.080078125 / 301 | 0.0078125 / 2 |

Resolved application radiance has a tighter carried-history ceiling of
0.000244140625 in FP32 and 0.06103515625 in FP16. All other outputs require
raw-byte equality. Strict controls require finite channels and raw-byte
equality in every dump, including signed zeros.

On Metal, a core-WebGPU device using widened storage and four-tap depth
filtering produced bit-exact application RGBA16F outputs relative to native
storage in all five frames (2,755 texels).

## FSR2 host

`crates/sp-fidelity-oracle/tests/fsr2_host_event_stream.rs`: AMD's unchanged
`ffx_fsr2.cpp` (driven by `oracle/fsr2_host.cpp`) and the port consume the
same call stream in nine cases, and all **16,866 events** match: resource
recipes and initialization data (the Lanczos and maximum-bias LUTs byte for
byte), pipeline permutations, binding tables, samplers, constant buffers,
clears, copies, dispatches, execution, messages and destruction. Cases:
helpers; wgpu HDR with auto exposure at Quality (120 frames); dynamic
resolution (110); RDNA LUT, wave64 and FP16 tables with TCR autogeneration
and generate-reactive (100); debug checking with every message, rejected
dispatches, NaN and negative frame time and NaN far plane (104); wave64 FP32
with every flag at native resolution (100); Ultra Performance through 72-phase
jitter wraps (130); odd sizes at Balanced (105); tiny sizes with rejected calls
(100). Nineteen deliberate mutations (a permutation bit, pass order, LUT
constants, blob key bits and slots, resource flags, jitter smoothing, the
exposure clear value, a dropped TCR dispatch, NaN handling and others) each
fail the comparison.

## FSR2 GPU, per pass

Pass-level replay (`crates/sp-fidelity-oracle/tests/fsr2_passes.rs`): identical
inputs and constant buffers through the WGSL on wgpu and the DXC-compiled
unchanged HLSL on Metal; every output compared. RCAS and accumulate run their
WGSL directly; the other passes run through the wgpu backend. Accumulate and
the backend passes take the constant buffers and dimensions AMD's unchanged
C++ host computes for each permutation's context. The backend passes cover
every key-bit combination with both the FP32 and FP16 tables, at sizes from
1×1 and partial 8×8 tiles to 1920×1080 at Quality, with dynamic resolution,
three frames per size and edge frames (black, flat, constant 65504, sky).
Counts are output dumps.

| Pass | Permutations | Result |
| --- | --- | --- |
| RCAS | all 64 option combinations (FP32; the SDK accessor never selects FP16 for RCAS); 1×1, 16×16, 37×23, 130×67 and 1920×1080; sharpness 0–1, exposure and pre-exposure 0→1, flat and black inputs | bit-exact (1,285 RGBA16F outputs; also bit-exact with an RGBA32F diagnostic output) |
| Accumulate and accumulate + sharpen | all 64 option combinations × FP32 and FP16; upscale 1.0–3.0 with odd sizes, partial tiles and a maximum render size above the render size, plus 1920×1080-class low-resolution motion; application, default and auto exposure; resets | against the HLSL with SDK-P35, SDK-P36 and SDK-P37 corrected; strict (both compiled without fast math or contraction, DXC's six constant folds applied to the WGSL): bit-exact, 11,570 dumps. With wgpu's fast math on both sides (SDK-P22), 4,327 differ with identical inputs and 4,407 when each side carries its own history; recorded, not bounded |
| Reconstruct and dilate | every permutation | bit-exact, 9,240 dumps |
| Lock | every permutation | bit-exact, 4,620 dumps |
| Generate reactive | every permutation | bit-exact, 12,320 dumps |
| Depth clip | every permutation | 3,718 exact; 386 within FSR2-F1 (`PreparedInputColor`, at most 16 on at most 0.47% of a dump's texels) and 516 within FSR2-F2 (`DilatedReactiveMasks`, up to 1.0 on at most 11.7%, in black neighbourhoods) |
| TCR autogenerate | every permutation | 8,530 exact; 196 within FSR2-F1 (`AutoReactive`, at most 0.2) and 514 within FSR2-F2 (up to 1.0) |
| Compute luminance pyramid | every permutation | 12,722 exact; 519 within FSR2-F1/F2 (`AutoExposure`, at most 1.5e-8; 7 of them in repeated jobs where SPD's epilogue runs, see SDK-P14); 343 SDK-P14 (`AutoExposure`, up to 0.53, only when the epilogue runs and mip 5 was written) |

FSR2-F1 and FSR2-F2 admit a difference only up to the maxima measured over
every case (`MEASURED` in the test), per pass, output, table and frame class;
integer outputs must match exactly.

- FSR2-F1: float evaluation in regular frames. Both programs are compiled with
  Metal fast math from differently shaped code (DXC's optimized SPIR-V through
  SPIRV-Cross; naga's direct translation), so FMA contraction, reassociation
  and fast-math approximations differ. Outputs that cancel large terms (YCoCg
  chroma: one binary16 ulp of a bright texel's luma; TCR's edge difference) or
  compare against thresholds carry the difference further.
- FSR2-F2: degenerate evaluation in edge frames. 0/0, x/0, sqrt(0) and
  infinite view depths are undefined under fast math on both sides (for
  example the 0/0 similarity of a black neighbourhood,
  `ffx_fsr2_depth_clip.h:192`), and HLSL `max` is IEEE maxNum (SPIRV-Cross
  `precise::max`), which WGSL `max` does not guarantee.

Unlike accumulate, these passes have no strict comparison yet, so their
admitted differences rest on measured maxima rather than an exact match
without fast math.

In the backend crate, `indirect_grid_visits_every_original_invocation_once`
(SDK-P10: 0, 1, 65,535, 65,536, 79,136 and 131,071 groups at both indirect
offsets, with the unadapted dispatch as failing control) and
`clear_float_job_writes_its_color_to_each_cleared_sdk_format` hold for any
effect.

## FSR3.1.4 host

Added source files are retained unmodified at the existing SDK revision.
The four host oracles compare every backend event and resource initialization
byte against the original C++. Debug and release builds exercise the same
API streams; the comparison does not substitute a Rust model for the SDK.

| Component | Evidence | Matching events |
| --- | --- | ---: |
| FSR3 upscaler | Helpers, Native AA, runtime tuning and clamp/default behavior, HDR, exposure, dynamic resolution, shared resources, reset, reactive generation, debug/error messages, FP16 and wave64 table selection | 18,426 |
| Optical flow | Three context sequences, changing frame/reset state and resolutions, FP32/FP16/wave64 table selection, rejected calls | 7,352 |
| Frame interpolation | 69 context attempts, all 64 flag combinations, preparation and interpolation, asynchronous frame IDs, resets and format conversion | 38,665 |
| Composite FSR3 | Five scenarios in one application stream: synchronous and asynchronous resource rings, delayed callbacks, enable/disable, destruction, upscaling-only and HDR routing | 5,517 |

Files: `tests/fsr3upscaler_host_event_stream.rs`,
`tests/opticalflow_host_event_stream.rs`,
`tests/frameinterpolation_host_event_stream.rs`, and
`tests/fsr3_host_event_stream.rs` in the oracle crate.

Optical flow's C++ local `OpticalFlowSpdConstants` leaves the last three
padding words uninitialized (`ffx_opticalflow.cpp`, structure at lines 92–103,
staging at 636–642). The oracle ignores only these three unused words; all
initialized words compare bit for bit. The Rust structure initializes its
padding to zero. DXC removes this constant buffer from the fixed-six-mip
shader entirely.

The oracle's 16-bit `wchar_t` compatibility layer supplies Windows `%s%d`
wide formatting and a locally instantiated string traits type. This avoids
calling macOS's 32-bit wide-string ABI when the unchanged SDK builds resource
names or optical-flow labels. These labels remain part of the comparisons.

### FSR3 GPU evidence

GPU evidence was collected on Apple M5 using the pinned DXC/SPIRV-Cross
translation and the actual wgpu Metal backend. All 1,408 upscaler and 204
frame-generation shader exports compile as Metal pipelines. Naga validates
1,280 upscaler, 176 frame-interpolation, and 28 optical-flow pass/permutation
combinations. Wave64 reflection coverage is host-only.

The upscaler's 64 meaningful GPU contexts capture 10,368 UAV/mip outputs.
The final sweep produced 9,658 exact outputs and 710 differences, all in accumulation,
accumulation with sharpening, or luminance frame information. Every captured
prepare-input, prepare-reactivity, luma-instability, shading-change, debug,
reactive-generation, and RCAS output matched exactly in that sweep. Separate
auto-exposure sequences exercise the shading-pyramid threshold boundary.

Strict controls distinguish compiler behavior from port arithmetic. DXC folds
the two rectification divisions by 20 into multiplication by the rounded f32
reciprocal, while SPIRV-Cross emits `fast::normalize` and Naga emits regular
`metal::normalize`, even with Metal fast math disabled. With the reciprocal
folds applied, raw strict replay has 820 exact accumulation outputs and 12
one-texel differences. A separately labelled builtin-aligned control compares
all 832 outputs exactly. Six temporal scenarios add 932 ordinary outputs
(818 exact, 114 compiler/race diagnostics), 78 raw strict accumulation outputs
(75 exact, 3 different), and 78/78 exact builtin-aligned outputs. FP16 history
sampling was also independently bitexact before rectification. These controls
do not edit the vendored HLSL, exported oracle shaders, or runtime WGSL.

A one-workgroup shading-pyramid control compares all 35 mip snapshots exactly
in each precision with strict compilation. Normal Metal fast math can change
which side of the original minimum-luma-difference threshold a value falls
on; the sign reduction amplifies that into sparse 0.25 differences. This is
reported as SDK-P22 compiler behavior, without a general numeric tolerance.
The one-workgroup luminance control compares all 45 snapshots exactly in
each precision after applying DXC's evidenced exposure folds only in its
strict diagnostic copy: `(Lavg * 100) / 12.5` becomes `Lavg * 8`, and the
reciprocal of `78 / (0.65 * 100)` becomes the rounded f32 value
`0.833333313465118408203125` ahead of the final division.

FSR3's multi-workgroup luminance epilogue also inherits SDK-P14: captured
frame-info luma can read the prior mip-5 publication while the final mip-5
snapshots themselves agree. Single-workgroup controls isolate this boundary.

Frame interpolation exercises all eight meaningful shader keys over sixteen
prepared/interpolated frames each, plus 8×8, 32×32, and 64×64 controls.
These retain the original parallel Metal replay and its narrowly identified
SDK-P14 comparison limitation; they do not establish full-resolution fidelity.

A separate 1200×750 sequence captures every mip and compares against original
HLSL with serialized tile scheduling: each original SPD tile runs once through
AMD's existing workgroup offset, with the original counter and workgroup count.
The native oracle completes each tile before the next; only the final tile
executes the unchanged upper-mip reduction. All other jobs, application inputs,
and temporal histories follow the original C++ trace. This avoids importing
port intermediates or duplicating AMD's reduction arithmetic. Before SDK-P33,
the 568 output dumps matched unchanged HLSL exactly. With that bounds correction,
the test uses a private copy of the original shader with only the same input-domain
guard; both synchronous and asynchronous host modes match all 568 dumps exactly.
The unmodified original remains the negative control in the isolated SDK-P33
regression and ground-plane reproduction. No numeric tolerance is added for the
corrected edge or its downstream effects. This validates the tested boundaries,
not AMD's complete supported DX12/Vulkan pipeline.

Optical flow exercises two 24-frame sequences, including odd dimensions,
Texture1D allocation, all three transfer functions, resets, and nonzero
motion. Same-input replay produced 1,639 exact snapshots and 41 SDK-P32
scene-detection snapshots, with the completed-workgroup counter exact.
Independent histories produced 1,469 exact snapshots and 211 race-tainted
differences, reported as diagnostics rather than equality.

The runnable `sp-fidelity-wgpu/examples/fsr3.rs` executes four complete
composite frames with configuration and weak generation callbacks, upscaling,
optical flow, interpolation, an RGBA8 output, and GPU readback.

The final workspace validation includes `cargo fmt --check`,
`cargo clippy --workspace --all-targets -- -D warnings`,
`SP_FIDELITY_REQUIRE_GPU=1 cargo test --workspace`,
`cargo doc --no-deps --workspace`, and compilation of both runtime crates and
all their targets for `wasm32-unknown-unknown`. GPU oracle suites are selected
explicitly as described in the oracle README; ordinary workspace tests leave
them ignored. The FSR2 host comparisons and backend GPU regressions still pass.

### FSR3 host adaptations and retained upstream behavior

- The composite SDK's global raw context pointer becomes an explicit context
  argument and a weak callback returned by
  `ffx_fsr3_get_frame_generation_callback`. The callback returns
  `INVALID_POINTER` after destruction; overlapping mutable access returns
  `INVALID_ARGUMENT`. Contexts, callbacks, and shared backend interfaces are
  confined to their creating thread. Multiple contexts do not share a global
  active pointer in the Rust API.
- The three composite wgpu interfaces are clones of one backend, since its
  resource and command-list handles belong to that instance. Presentation
  configuration is forwarded to the native wgpu presentation adapter (or an
  application hook). See the native presentation adaptation below.
- The original composite create function never assigns its private
  `upscalingOnly` and `interpolationOnly` fields. Their zero state is
  preserved. Interpolation-only composite creation consequently reaches an
  absent upscaler context; Rust returns `INVALID_POINTER` instead of
  dereferencing it. Use the standalone frame-interpolation API for this
  mode. The composite source also never forwards `upscaleSize`; Rust retains
  the upstream zero-size fallback. The original `ffxFsr3SkipPresent`
  declaration has no definition in the pinned SDK and is not exported.
- The frame-interpolation debug-color counter is process-global as upstream;
  Rust uses an atomic counter instead of an unsynchronized mutable static.

### FSR3 GPU and backend adaptations

- SDK discard jobs require no operation for separately allocated wgpu
  resources. Explicit transition barriers are represented by wgpu's resource
  tracking between compute passes. The original jobs remain in host traces.
- SPD's FSR3 `R16G16_FLOAT` mip chain is physically RGBA16F because Metal
  cannot bind RG16F for read/write. Only `.xy` are used, retaining half-float
  rounding. Descriptions and oracle files keep the SDK's two-channel layout.
- Return-valued texture atomics use coherent packed buffers: FI game-vector
  X/Y fields and the shared optical-flow SCD output, histogram, and temporary
  reduction counters. Metal can optimize away Naga's atomic-texture visibility
  workaround when coordinates are provably bounded; coherent buffer atomics
  avoid that compiler hazard without adding an algorithmic synchronization. Optical-flow search
  packs two signed 16-bit vectors into one word because Metal cannot bind
  RG16Sint for read/write. Texture-to-buffer and buffer-to-texture passes
  retain the original texture handles and contents at effect/application
  boundaries. Other passes retain the original typed texture formats.
- Frame-interpolation output storage formats are specialized from the actual
  bound output texture, with cached pipeline variants. Its SDK compute
  pipeline descriptions correctly retain `Unknown` backbuffer format; the
  unused raster-pipeline lambda is not used as a source of configuration.
- Optical flow's optional 1D resources are allocated as one-row 2D textures
  because its original HLSL still declares Texture2D bindings
  (`ffx_opticalflow_callbacks_hlsl.h:209,250–265`). SDK descriptions retain
  Texture1D; only the backend allocation changes.
- wgpu frame-generation resources require storage-capable typed color formats.
  BGRA8 storage requires the caller's device to enable `BGRA8UNORM_STORAGE`.
  Typeless and sRGB storage formats have no WGSL equivalent; callers use
  linear-format storage and the SDK transfer-function parameters. Host format
  validation is still ported exactly, including its original precision groups.
- Native-only texture atomics require `STORAGE_ATOMIC` usage on caller-created
  R32Uint textures. SDK-created resources get it automatically.
- WGSL pass assembly retains SDK permutation defines, including FP32 SPD
  overrides. Unreachable resource loads that DXC eliminates are omitted where
  Naga retains them; this preserves the original reflection tables rather
  than adding bindings. MSL packed vec3 structure members use local copy-in/out
  variables for inout calls. Explicit load bounds preserve HLSL zero-outside
  semantics instead of Metal's coordinate-clamping robustness behavior.
- Portable optical-flow wave operations use workgroup reductions with the
  original integer tree/order; SCD wave-lockstep float reductions have explicit
  workgroup synchronization. Forced wave64 remains unsupported under SDK-P6.

- FI SPD declares twelve mip UAVs even for smaller textures. Missing mips
  bind distinct inert 1×1 storage views: clamping every missing view to the
  last real mip creates mixed storage-access aliases rejected by wgpu.
  The original SPD mip-count guards prevent access to these views
  (`ffx_spd.h:496–511,538`). Existing real mip views remain unchanged.

### SDK-P32 — optical-flow scene-detection race

The original `ffx_opticalflow_compute_scd_divergence.h` reads the current
histogram at line 41 and previous histogram at line 102. The y=1 workgroups
replace the previous histogram and clear the current histogram at lines
153–155 while y=0/y=2 workgroups may still read them. There is no dispatch-wide
synchronization. Repeating the unchanged HLSL with identical captured inputs
changed scene-detection results in 17 of 24 frames on Apple M5. One frame
changed from approximately 0.773105/history 1 to 0.110342/history 0.

The port retains this upstream algorithm. Same-input replay compares every
vector and histogram output exactly; only scene-change scalar/history words
0 and 1 of the SCD output are classified as nondeterministic. Completed-counter
word 2 must remain exact. Independent histories can then diverge when scene
change resets motion search; those trajectories are reported as tainted
history diagnostics, not successful exact comparisons or numeric tolerances.

## Differences and platform adaptations

The runtime crates support WASM compilation with the WebGPU backend. FSR2 and FSR3
execution still requires native-only GPU features; no browser GPU conformance
is claimed. This build adaptation changes neither the SDK algorithms nor
the shaders or conformance counts above.

Adaptation IDs are stable and may have gaps.

| ID | Boundary | Disposition |
| --- | --- | --- |
| SDK-P6 | wgpu cannot force a 64-lane subgroup | The backend reports SM6.2, so the SDK never selects `FORCE_WAVE64`; the port's WGSL has one source for both tables. No forced-wave64 coverage is claimed. |
| SDK-P7 | WGSL needs initialized locals and bounded texture access | Written as `// WGSL:` lines citing the SDK line; no other difference. |
| SDK-P8 | Copies from inputs smaller than the context | The backend copies the whole source subresource, as the SDK's backends do. |
| SDK-P10 | wgpu turns indirect dispatches above 65,535 groups into no work | Backend grid adapter: bounded 2D dispatch with the SDK's logical group IDs. SDK arguments, jobs and WGSL unchanged. |
| SDK-P14 | SPD's epilogue reads mip 6 written by other workgroups; SPIRV-Cross's Metal adds per-texture fences, naga's does not | No barrier added; see below. |
| SDK-P18 | FSR2 messages | The port uses the SDK's callback path (`ffxFsr2ContextCreate`'s `fpMessage`); the SDK's non-Windows builds drop messages and its Windows fallback is `OutputDebugStringW`. The C++ oracle records through the same callback. |
| SDK-P19 | Rust types make some SDK error paths unreachable | Quality modes are an enum (the SDK's invalid-enum and `default` paths cannot occur); null-pointer checks hold statically, and a context that was never created returns `INVALID_POINTER`. Resource initialization data carries a lifetime valid for the call. `_GAMING_XBOX` branches are not ported. |
| SDK-P20 | WGSL has no 16-bit integers | `FfxUInt16`/`FfxInt16` and their `FFX_MIN16_*` forms are 32-bit, as `ffx_common_types.h:250–261` allows for min16 types; each use cites it. |
| SDK-P21 | Typed UAV formats are fixed in WGSL | `rw_upscaled_output` is RGBA16F (`ffx_fsr2_callbacks_hlsl.h:452`); HLSL accepts any output format. |
| SDK-P22 | Both oracles compile with Metal fast math (wgpu's default) | Floating-point reassociation of equivalent expressions cannot be told apart on this platform; mutation checks that only reassociate are recorded as undetectable. wgpu discards out-of-range stores, so dropped store guards are also undetectable. |
| SDK-P23 | WGSL texture atomics return no value | `FSR2_SpdAtomicCounter` is a 1×1 `R32_UINT` UAV texture (`ffx_fsr2.cpp:702–711`) whose `InterlockedAdd` returns the previous value (`ffx_fsr2_callbacks_hlsl.h:949`). The WGSL binds it as a storage buffer, and the backend backs the texture with a buffer of its texels, carrying its contents so far. |
| SDK-P24 | Metal has no read-write `Rg32Float` storage texture | The backend allocates an `R32G32_FLOAT` UAV (`FSR2_AutoExposure`) as `Rgba32Float`; its initial data gains zero `.zw`. |
| SDK-P25 | `ffxFsr2ContextGenerateReactiveMask` | SDK 1.1.4 builds the job but its `fpScheduleGpuJob` call is commented out (`ffx_fsr2.cpp:1569`), so it executes nothing; the port keeps that. The generate-reactive pass itself is verified above. |
| SDK-P26 | Naga's Metal output keeps every WGSL loop as a bounded `while (true)` the Metal compiler does not unroll, and branches on `\|\|` | The pass preprocessor performs `FFX_UNROLL` wherever the SDK has it and on five more constant loops; `ffxWgslOutside` uses `\|`. Operations and their order are unchanged. See below. |
| SDK-P27 | wgpu rejects a view of a mip the texture lacks | FSR2 binds the luminance pyramid's `rw_img_mip_shading_change` and `rw_img_mip_5` to mips 4 and 5 of `FSR2_ExposureMips` whatever its size (`ffx_fsr2.cpp:669–678, 998–1004`); below a 64-pixel maximum render size the texture lacks mip 5, and below 32 mip 4 too. The backend binds the texture's last mip, as AMD's Vulkan backend does (`sdk/src/backends/vk/ffx_vk.cpp:3769–3771` at the SDK revision; the DX12 backend, `sdk/src/backends/dx12/ffx_dx12.cpp:3052` at the SDK revision, indexes past the resource's own descriptors). SPD stores to mip 4 or 5 only when its mip count, from the render size, reaches it (`ffx_fsr2_compute_luminance_pyramid.h:70–72`, `ffx_spd.h:68`), so nothing is written through a substituted view (render size within the maximum), and sizes that have the mips bind them unchanged. |
| SDK-P28 | wgpu reports an object it rejects when it is created, but the error of recording it only when the encoder finishes, and then the whole encoder, with the application's own work in it, is invalid | A clear or compute job creates its new views and bind group inside validation and out-of-memory error scopes and, if wgpu rejects any, fails before recording them with `FFX_ERROR_BACKEND_API_ERROR`, the code AMD's DX12 backend returns for a failed job (`sdk/src/backends/dx12/ffx_dx12.cpp:3501–3504` at the SDK revision), and wgpu's message. `fpExecuteGpuJobs` stops at the first failed job and executes none after it, which the valid encoder depends on; AMD's DX12 `ExecuteGpuJobsDX12` instead records every job and keeps overwriting its error code (`ffx_dx12.cpp:3461–3499`). Godot's FSR2 backend stops at the first failed job (`execute_gpu_jobs_rd`, `servers/rendering/renderer_rd/effects/fsr2.cpp:479–482` at Godot b130438), fails a job whose UAV view it could not create before recording it (`execute_gpu_job_compute_rd`, `fsr2.cpp:424`), and its RenderingDevice refuses to bind an invalid uniform set (`servers/rendering/rendering_device.cpp:6884–6885`). `ffxFsr2ContextDispatch` ignores `fpExecuteGpuJobs`'s result (`ffx_fsr2.cpp:1321`), as the port does, so the backend keeps the first failure's code and message for `take_job_error`. A failed job records nothing invalid: what it records before its check, a compute job's SDK-P23 conversion copy, is valid (a job observer's commands are the observer's own). Only new objects are checked: a bind group a pipeline kept was checked when it was made, so a texture destroyed after that is recorded and fails at `queue.submit`; and invalid inputs can still invalidate the encoder while a job records, for example one texture passed as both an input and the output (a usage conflict). On WebGPU the scopes resolve only after the call, so there the error stays deferred to `finish`. |
| SDK-P35 | FSR2 accumulate weights taps outside the render size into its rectification box | A verified upstream bug, corrected in the port's WGSL; see below. |
| SDK-P36 | FSR2 accumulate writes a new sample's upsample unnormalised when its on-screen weights sum to `FSR2_EPSILON` or less | A verified upstream bug, corrected in the port's WGSL; see below. |
| SDK-P37 | FSR2 accumulate's deringing bounds take taps outside the render size | A verified upstream bug, corrected in the port's WGSL; see below. |

### SDK-P33 — padded frame-interpolation game-field invocations

The original C++ rounds the game-field dispatch up to 8×8 groups
(`ffx_frameinterpolation.cpp:1079–1083`), but the HLSL entry point does not
exclude invocation coordinates outside `RenderSize()`. At height 750, a padded
zero-motion source at y=750 projects to pixel 749.99994 in FP32. Its bilinear
splat writes a false primary vector onto valid row 749. Output texture bounds
checks cannot prevent this in-bounds write. The corresponding right-edge case
occurs at width 750.

`frameinterpolation_edges::padded_game_field_threads_do_not_publish_primary_vectors`
isolates the original pass at 32×750 and 750×32, using the unchanged C++ host's
constants and dispatch dimensions. Every valid source translates inward, so
none can publish a primary onto the outgoing last row/column. Unchanged HLSL
does publish zero-motion primaries there; the uncorrected WGSL does too. An
entry-point render-size guard removes them while preserving valid primaries
exactly. The vendor sources remain unmodified. This is a verified original
input-domain bug, distinct from the broader reconstruction limitation below.

The standalone C++/Vulkan fixture in the oracle's
`repro/frameinterpolation_edges/` also executes unchanged SDK 1.1.4 and current
AMD main (`7539ae8b6568ad29ed78a753404351daf3b5cca7`). In a 32×752 allocation
with logical render size 32×750, allocated padded depth/motion causes 96 false
primaries on rows 726–728 without relying on the zero-motion FP32 round-trip.
A render-domain guard eliminates them and preserves interior translation.
An intentionally empty shader is rejected by the fixture's positive control.
The Vulkan run here uses MoltenVK on Apple M5, not native AMD hardware.

### Outgoing ground-plane reproduction

`frameinterpolation_passes::outgoing_ground_reproduces_original_edge_limit`
generates depth, motion and color analytically for an infinite stationary plane
two metres below a level camera, 80-degree vertical FOV, advancing four metres
per real frame at 1200×750. It needs no renderer or application capture. Color
stripes have a 6.2-metre period, avoiding a repeated identical frame pair.

The original sequence and port both bend straight horizontal stripes near the
outgoing edges. Primary vectors match exactly except SDK-P33's invalid edge;
secondary vectors are not deterministic in unchanged native replay. Their loop
uses concurrently published primaries to decide when to stop. These differences
are reported, not accepted as general parity tolerance.

At pixel (600,700), the endpoint-linear midpoint projection requires about
171 pixels of vertical half-motion. Visible current-frame sources supply at
most about 117 pixels. The original secondary path copies those vectors, and
the pyramid computes weighted averages; neither can supply the missing larger
velocity. Replaying the unchanged interpolation pass with the analytic midpoint
field restores straight stripes. Its remaining inputs and shaders stay fixed.
At row 700, changing the frame counter from 3 to 52 and changing optical-flow
vectors leaves the output unchanged, excluding optical-flow warmup as the cause.

This establishes a quality limitation of the original reconstruction on these
valid inputs, not a mistranslated arithmetic operation. The bounds fix does not
resolve it. SDK-P34 below is a separately tested Rust-only correction; the
original reproduction remains unchanged. Native evidence here uses DXC/SPIRV-Cross Metal;
it is not a run of AMD's complete supported DX12/Vulkan implementation.

### SDK-P34 — outgoing stationary geometry

Owner-authorized Rust/WGSL correction for the independently reproduced outgoing
motion deficit ([AMD issue #213](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/issues/213)).
This is an algorithm departure, not a translation claim. No C++/HLSL under
`vendor/` or original oracle shader is changed. The independent source
reproduction and AMD host/GPU comparisons remain in the oracle; the latter
explicitly disable SDK-P34 with `ffx_frame_interpolation_set_outgoing_reconstruction`.
Disabling this correction does not disable the separate SDK-P33 bounds fix.

The standard basis is depth-image warping using previous-view coverage:
[post-rendering 3D warping](https://cs.brown.edu/stc/resea/rendering/research_R9.html),
[depth-mesh reprojection and discontinuity handling](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/10/reinert2016.compressed.pdf),
and [bidirectional frame interpolation](https://sites.cs.ucsb.edu/~lingqi/publications/paper_sig24mobfgsr.pdf).
Only the method is used; no code from these papers is copied. AMD's existing
packed-vector helpers and interpolation remain the port's reference.

`frameinterpolation/outgoing.rs` owns the additional history, resources and
scheduling; the `outgoing_*` and `current_*` WGSL shaders own the new math. Six
port-only pass IDs start at `0x1000`; original SDK IDs and constant layouts stay
unchanged. Prepare captures raw depth and normalized motion into alternating
history slots before nearest-depth dilation. Projection uses retained current,
previous and older camera poses/FOV/jitter. Before the motion pyramid and
visibility pass, current-source cells supply continuous midpoint coverage where
fixed point splats leave gaps. Nearby primaries can be refined only if the
original source's measured motion also agrees with camera projection and the
raw source depths connect. The two-render-pixel difference limit is a conservative
acceptance bound, not a proof of surface identity. Accepted motion and its
source-triangle depth are published together; rejected candidates change neither.
After the original disocclusion
pass, previous-depth cell triangles supply a separate candidate field at
`(previousUV + currentUV)/2`, carrying `(previousUV - currentUV)/2`. The resolve
accepts previous-visible/current-outside candidates only where the original
field is not primary, then marks previous color visible and current color
unavailable with the existing `(1,0)` mask. Packed endpoints are checked again.
A final pass retains the distortion matching the previous color history.

Raw samples avoid dilation's displaced silhouette geometry. Motion consistency
uses binary16 precision plus an FP32 projection allowance, not a blanket pixel
radius. Adjacent depth slopes reject unsupported cell connections; one triangle
has a fixed 4096-candidate raster budget. Unsupported cells are skipped as a
whole. Camera-relative arithmetic avoids adding local geometry to a large world
origin. Distortion checks preserve original behavior at warped lookups. There is
no overscan, border feather, invented velocity scale, or optical-flow tuning.

Limits are deliberate: prior motion cannot prove current staticness; a newly
moving object can pass the historical check. The previous-source pass preserves
primary vectors even where outgoing foreground might be nearer at the midpoint.
Sky, unsupported silhouettes/curvature, extreme cell magnification and missing
camera metadata retain the original fallback. Jitter-included and display-resolution motion are not
supported by the correction. A nearest display-grid motion sample describes a
different ray from the raw render-grid depth; treating that offset as object
motion would reject valid stationary surfaces. Those inputs keep the original
reconstruction until a depth-consistent resampling scheme is validated. The composite SDK wrapper does not supply camera
basis metadata; standalone callers must supply it. Mismatched prepare/dispatch
IDs invalidate correction history. This is not a universal fix for FG artifacts.

Allocation happens before per-frame jobs are queued. Errors still drain queued
work and unregister inputs; history advances only after successful job encoding.
The seven persistent render-sized resources use 28 bytes/pixel before backend
atomic mirrors. Runtime cost requires measurement for the completed correction.

`sp-fidelity-wgpu::outgoing_tests` exercises actual GPU dispatches. The expanded
plane checks continuous coverage beyond fixed-size splats and expected color;
the independent 1200×750 ground fixture checks the missing 171px correspondence,
with an unchanged reconstruction negative control. Further checks reject
previously moving foreground, avoid joining separate depth surfaces, preserve
upstream primaries, and reset history. Finite reverse depth with varying raster
jitter, missing/nonconsecutive camera history, and current/previous distortion
lookups (including a render region smaller than its allocation) are covered.
These tests establish their stated
geometric cases, not visual acceptance of arbitrary game content.

`frameinterpolation_receding` independently reproduces sparse primary coverage
in unchanged HLSL: a 96×64 plane moves from distance 2 to distance 9, so current
source cells expand 2.75× at the midpoint. The original field has 2,368 interior
primary holes and up to 17.5 pixels of secondary-vector error; valid primary
entries match the port exactly. The complete GPU regression checks the analytic
plane color, plus a textured receding ground at two velocities. A camera-attached
coplanar panel catches refinement that would overwrite independently moving
geometry; a distorted expanding footprint catches rejected candidates altering
the reconstructed depth. These do not establish a color-seam fix.

The `frameinterpolation_seam` source fixtures isolate a separate color problem.
An infinite mirror against an environment at infinity has stationary reflected
appearance despite geometric motion. With exact zero optical flow, the original
interpolation still promotes the game hypothesis to perfect similarity when its
endpoint leaves the viewport and warps the reflected image. A moving diffuse
sinusoid with deliberately incorrect optical flow is the negative control:
forcing optical flow at the viewport edge must not break its exact geometric
correspondence. No color correction has been accepted yet.

The standalone C++/Vulkan reproduction's `--color` mode includes unchanged
`ffx_frameinterpolation.h` directly and reproduces the affine/non-affine mirror
and linear-illumination cases against SDK 1.1.4 and AMD main
`7539ae8b6568ad29ed78a753404351daf3b5cca7`. It supplies analytic callback inputs,
not application captures or port-generated intermediates. Its diffuse controls
also cover a repeating texture with a tiny lighting change: hard minimum-error
selection regresses that case, although the original remains accurate. Native
runs here use Vulkan through MoltenVK on Apple M5. No color-algorithm departure
has been adopted on the strength of these diagnostics.

When updating upstream: retain its vendor tree verbatim, rerun original-path
host/shader comparisons, then run the independent correction regressions. If
AMD supplies equivalent outgoing coverage, compare it on these inputs and remove
this correction when it supersedes it; do not fold this patch into the reference.

### SDK-P35 — FSR2 accumulate border taps in the rectification box

A verified bug in AMD's FSR2 HLSL, corrected in the port. `ComputeUpsampledColorAndWeight`
loads its 3×3 taps with `ClampLoad(iSrcSamplePos, FfxInt32x2(0, 0), RenderSize())`
(`ffx_fsr2_upsample.h:326`), and `ClampLoad` clamps only in the direction of a
non-zero offset (`ffx_fsr2_common.h:358–365`), so it clamps nothing: a tap
outside the render size loads zero (HLSL's out-of-range `Load`), or a stale
texel beyond the render size when the maximum render size is larger. The
Lanczos weight excludes such taps (`fOnScreenFactor`, line 428), but the
rectification box takes them at full weight
(`fBoxSampleWeight = exp(fRectificationCurveBias * fSrcSampleOffsetSq)`, line 436).
A corner texel has five such taps; where the jitter puts them close to the
sample they pull the variance box below the history, which is clamped into it.
A uniform frame at rest then darkens a corner on some jitter phases: at native
resolution the bottom-left texel on phase 7 and the top-right on phase 2, by
up to 14 % at a 0.25 grey, decaying over the following frames.

FSR3 corrects exactly this: `ffx_fsr3upscaler_upsample.h:611` multiplies the
box weight by `fOnScreenFactor`, so its off-screen taps reach neither sum. The
Xbox-only paired path of the same FSR2 file loads clamped coordinates
(lines 297–311). The port applies FSR3's weighting
(`shaders/wgsl/fsr2/ffx_fsr2_upsample.wgsl`). Both versions still widen the box's
`aabbMin`/`aabbMax` with every tap (`RectificationBoxAddSample`). That bound is
also the deringing clamp, which SDK-P37 corrects.

Evidence. `sp-fidelity-wgpu`'s
`fsr2_upscales_a_uniform_frame_to_the_same_value_at_every_texel` runs FSR2
through the backend at 37×23 and 64×64 native and 37×23 at Quality, over every
jitter phase: a grey frame must come out grey at every texel within two
binary16 stores. Without the correction it fails at 37×23 on phase 2, texel
(36, 0), 0.2457. In the oracle, `fsr2_passes::accumulate_keeps_a_uniform_frame_uniform`
runs the accumulate pass on jitter phases 7–11 with the uniform history the
pass itself would keep (HDR FP32 and FP16, LDR; native 37×23 and 67×45 from
45×30 with stale texels beyond it): the unchanged HLSL darkens texel (0, 22) of
37×23 to 0.2146 in every permutation, while the port and the corrected HLSL
stay uniform and match exactly. The compile tool builds the corrected
reference with `--correction SDK-P35` (a replacement in its working copy of
the SDK headers; `vendor/` is unchanged), into `shaders/generated/fsr2-sdk-p35`.
The accumulate comparison above is against the reference with SDK-P35, SDK-P36
and SDK-P37 corrected (`shaders/generated/fsr2-sdk-p35-sdk-p36-sdk-p37`).

### SDK-P36 — FSR2 accumulate writes a weightless upsample unnormalised

A verified bug in AMD's FSR2 HLSL, corrected in the port. `ComputeUpsampledColorAndWeight`
gives taps off the render area Lanczos weight 0 (`fOnScreenFactor`,
`ffx_fsr2_upsample.h:428–429`) and normalises and derings the colour only when
the remaining weights sum above `FSR2_EPSILON` (lines 447–455); otherwise it
returns the weighted sum unnormalised, with weight 0. A new sample, one whose
history is off screen or any texel of a reset frame, takes that colour as its
history and output (`ffx_fsr2_accumulate.h:270–271`). Its kernel bias is 1
(lines 338–343), so the weights are Lanczos 2 of the tap offsets. Near the
frame's edge at ratios near 2 and above, the kernel can lose its near taps off
screen and keep only taps in Lanczos 2's negative lobe (1 < d < 2): the sum
falls below `FSR2_EPSILON`, often below zero, and the colour written is
`Σ wᵢcᵢ`, for a uniform frame `c·Σwᵢ`: dark, or negative. The sign comes from
the negative lobe, not from YCoCg or RCAS.

At 99×61 from 33×21 (ratio 3), jitter phase 8 (0.0625, −0.463), texel (4, 0):
the render row −1 taps, among them the nearest (offset (−0.06, −0.21), weight
0.92), are off screen and the six left sum to −0.0511, so a 0.25 grey is
written as −0.012783 by hand and −0.012779 on the GPU; on phase 7, texel (0, 3),
−0.0231 gives −0.0057718 and −0.0057716. At 192×108 from 64×36 (sgl#809) the
lowest sum over the 72 phases is −0.089, at texel (3, 0): −0.0045 for a 0.05
sky, reported there as −0.0042 every eighth frame. At ratio 2 exactly the
lowest at 192×108 is +0.014, but 37×23 from 18×11 (2.06) reaches −0.18.

FSR3 handles the same situation: a pixel whose reprojection leaves the screen
has no accumulation (`ffx_fsr3upscaler_prepare_reactivity.h:203–211`), and such
a sample takes the rectification box's centre as its colour
(`ffx_fsr3upscaler_upsample.h:635–643`); FSR3 also clamps its output at zero
(`ffx_fsr3upscaler_accumulate.h:163`). The port takes the box centre only where
FSR2 leaves the colour unnormalised (`shaders/wgsl/fsr2/ffx_fsr2_upsample.wgsl`),
keeping FSR2's Lanczos upsample for every other new sample and the weight of 0
the SDK returns. The centre is the weighted mean of the on-screen taps
(SDK-P35), so a uniform frame stays uniform. The zero clamp is not taken: the
negative value came from the unnormalised sum, and the prepared colours are
clamped at zero (`ComputePreparedInputColor`).

Evidence. `sp-fidelity-wgpu`'s
`fsr2_upscales_a_uniform_frame_with_off_screen_history_to_the_same_value_at_every_texel`
runs FSR2 through the backend at 37×23 from Ultra Performance's 12×7 and
Performance's 18×11, a grey moving 6 display pixels a frame to the right, over
every jitter phase: every texel must stay grey within two binary16 stores.
Without the correction it fails at 12×7 on phase 7, texel (0, 3), −0.00839,
and at 18×11 on phase 26, texel (4, 0), −0.000185. In the oracle,
`fsr2_passes::accumulate_keeps_a_uniform_frame_uniform_where_history_is_off_screen`
runs the accumulate pass at 99×61 from 33×21 with that motion (HDR FP32 and
FP16, LDR): the unchanged HLSL, and the HLSL with only SDK-P35 corrected, write
−0.012779 at texel (4, 0), while the port and the corrected HLSL stay grey and
match exactly. The compile tool's `--correction SDK-P36` builds the reference.

### SDK-P37 — FSR2 accumulate deringing bounds take off-screen taps

A verified bug in AMD's FSR2 HLSL, corrected in the port. The taps of
`ComputeUpsampledColorAndWeight` load through `ClampLoad` with a zero offset,
which clamps nothing (SDK-P35), so a tap off the render area loads zero, or a
stale texel beyond the render size. `RectificationBoxAddSample` widens
`aabbMin`/`aabbMax` with every tap (`ffx_fsr2_common.h:163–164`), and those
bounds are `Deringing`'s clamp of the Lanczos upsample (`ffx_fsr2_upsample.h:454`)
and the outer limit of the history clamp (`ffx_fsr2_accumulate.h:79–80`). In
the frame, the clamp removes the Lanczos undershoot beside a brighter feature;
at the frame's edges the zero (or the stale texel) lets it through.

Native 37×23, a 0.25 grey with a 1.0 band in render rows 7–14, reset frame,
jitter phase 0 (0, −1/6), texel (0, 6): the band's taps at offsets (0, 1.17)
and (1, 1.17) weigh −0.104 and −0.094, and the normalised upsample is 0.06098
by hand. One column in, the 3×3 bounds are [0.25, 1] and clamp it to 0.25; at
the edge, column −1 loads zeros, the bounds are [0, 1], and 0.06097 is written
on the GPU. In the oracle's case below (a band in render rows 8–13, at rest)
the edge texel beside the band is still up to 10 % low after five frames
(0.2263 at texel (0, 7)). At 67×45 from 45×30 with stale texels beyond the render
size the upper bound widens too: 1.00195 over a 1.0 band at texel (66, 19).
sgl#808 measured 0.0443 at the right-edge texel beside a 0.5 card on a 0.05 sky
at native 192×108; the port reproduces it in that scene, 0.0417–0.0443, and
gives 0.04999 with the correction.

FSR3's upsample has the same load (`ffx_fsr3upscaler_upsample.h:417`) and
bounds, so it is no precedent here. FSR3 nevertheless stays in range in that
scene, in sgl#808 and through this port's FSR3 (0.04999 at rest and at 1.5 and
4 pixels a frame); why its own copy does not show there is not established. The Xbox path of the same FSR2 function
loads clamped coordinates (`__XB_Med3_I32` into `[0, RenderSize() − 1]`,
`ffx_fsr2_upsample.h:275–311`), as does `ClampLoad`'s commented-out body
(`ffx_fsr2_common.h:367`). The port loads clamped coordinates. An off-screen
tap then repeats an on-screen tap of the same 3×3; its Lanczos and box
weights stay 0 (SDK-P35), so only the bounds change, to those of the on-screen
taps.

Evidence. `sp-fidelity-wgpu`'s
`fsr2_keeps_a_band_meeting_the_frame_s_edges_within_the_frame_s_range` runs FSR2
through the backend at 37×23 native and from Quality's render size, a grey
frame with a brighter band across its middle third, at rest, over every jitter
phase: every texel must stay within the grey and the band's grey, widened by
two binary16 stores. Without the correction it fails at native on phase 0,
texel (0, 6), 0.06097. In the oracle,
`fsr2_passes::accumulate_keeps_a_band_within_the_frame_s_range_at_its_edges`
runs the accumulate pass with that band at 37×23 native and 67×45 from 45×30
with stale texels beyond it (HDR FP32 and FP16, LDR): the unchanged HLSL, and
the HLSL with only SDK-P35 corrected, leave the range at the left and right
edges (down to 0.2263 and up to 1.00195), while the port and the corrected HLSL
keep it and match exactly. The compile tool's `--correction SDK-P37` builds
the reference.

### SDK-P14 — SPD hand-off between workgroups

Frame interpolation marks its mip-5 UAV and counter `globallycoherent`
(`ffx_frameinterpolation_callbacks_hlsl.h`). WGSL atomics have relaxed memory
semantics and its barriers are workgroup-scoped; the port's original one-dispatch
handoff therefore did not preserve cross-workgroup texture publication. The
wgpu backend now runs FI's two SPD pyramids as tile and epilogue dispatches,
with a compute-pass boundary between them. It preserves the SDK reduction tree,
FP32 arithmetic, intermediate texture precision, mip count and scratch state.
Small pyramids that need no epilogue retain one dispatch. One timestamp pair
spans each original logical job.

The original HLSL translated by DXC/SPIRV-Cross to Metal also exhibits stale
reads at this boundary. At 1200×750, an original mip-6 texel was zero although
all four completed mip-5 inputs were the same nonzero vector. This is a
limitation of that comparison path, not proof of an AMD supported-backend bug.
Serialized original-HLSL tile execution removes the ambiguity and matches the
split WGSL sequence exactly. The default `spdPhase = 0` retains the original
shader scheduling for other effects and direct shader diagnostics; the wgpu
backend selects phases 1/2 only for FI's FP32 pyramid passes.

Earlier acceptance of stale reads as necessarily "original behaviour" was
not justified. The remaining FSR2/FSR3 upscaler observations below identify
unresolved platform boundaries; they must not be generalized to upstream bugs.

In FSR2 the difference appears only in `FSR2_AutoExposure`, when the
luminance pyramid runs SPD's epilogue (more than six mips) and mip 5 was
written by another workgroup: up to 0.53 in 343 dumps. The hand-off is a
race, so the count can differ between runs (337 on wgpu 29.0.4). The same
hand-off reaches the repeated jobs where the epilogue runs: 7 of the 519
FSR2-F1/F2 dumps (at most 7.5e-9) are there, 1 on wgpu 29.0.4. Permutations
that differ only in the sharpening bit compile identical pyramid shaders and
take identical inputs, yet each of those 7 has an exact twin, so they too
vary between runs rather than with float evaluation.

### SDK-P26 — loops and branches in naga's Metal output

wgpu's safe `create_shader_module` has naga bound every loop with a counter
(`force_loop_bounding`; only the `unsafe` `create_shader_module_trusted` turns
it off) and write a `for` statement's update as a `continuing` block behind a
first-iteration flag. The Metal compiler then leaves FSR2's constant 3×3, 4-
and 9-sample loops rolled, with their arrays (bilinear offsets and weights,
depth and colour samples) in memory, where it unrolls the plain `for` loops of
the DXC→SPIRV-Cross MSL. A WGSL `while` (no `continuing` block) keeps the
counter and did not unroll either.

The SDK marks most of these loops `FFX_UNROLL` (`[unroll]`), which the port
had dropped. The pass preprocessor now performs it (`sp_fidelity::shaders`):
the `for` statement becomes one block per iteration, in order, binding the
loop variable to that iteration's value. The SDK's markers are restored
(reconstruct's depth loops, depth clip's reactive-mask loop, the lock loops,
the deringing and upsample loops); the lock's inner loop, whose `continue` an
unrolled body cannot hold, samples under `if !(x == 0 && y == 0)` and
increments `idx` at the end of its body. Five loops the SDK leaves to the
compiler also carry `FFX_UNROLL` as `// WGSL:` lines with their measured
saving: depth clip's bilinear (0.07 ms), motion-divergence (0.35 ms) and
depth-divergence (0.30 ms) loops, reconstruct's bilinear store (0.03 ms) and
accumulate's luma-history loop (0.05 ms). Depth clip's 9-sample reactive loop
saved nothing measurable and stays a loop.

`ffxWgslOutside` (SDK-P7) combines its two tests with `|`: naga writes `||`
as a branch, which cost up to 0.04 ms of a pass.

GPU time, Apple M5, wgpu 29.0.4 (MSL 3.2), 2026-09-30 (not re-run on wgpu
30), 1920×1080 display, permutations (`0x97`, sharpening `0xb7`, RCAS
`0x17`), median of 5 rounds of 90 back-to-back
repetitions from the same captured inputs (`sp-fidelity-oracle` example
`fsr2_timing`; the SDK's compiled MSL runs in the Metal oracle with textures
allocated as wgpu allocates them), ms:

| Pass | Render | SDK MSL | Port before | Port after |
| --- | --- | --- | --- | --- |
| Reconstruct previous depth | 1920×1080 | 0.44 | 1.06 | 0.45 |
| Depth clip | 1920×1080 | 0.82 | 2.50 | 0.82 |
| Lock | 1920×1080 | 0.21 | 0.59 | 0.18 |
| Accumulate (sharpen) | 1920×1080 | 1.05 | 1.83 | 0.95 |
| RCAS | 1920×1080 | 0.18 | 0.16 | 0.16 |
| Reconstruct previous depth | 1280×720 | 0.16 | 0.47 | 0.18 |
| Depth clip | 1280×720 | 0.37 | 1.08 | 0.37 |
| Lock | 1280×720 | 0.10 | 0.26 | 0.08 |
| Accumulate (sharpen) | 1280×720 | 1.00 | 1.80 | 0.93 |
| RCAS | 1280×720 | 0.18 | 0.16 | 0.16 |

`tests/fsr2_passes.rs` passes unchanged, the accumulate test's strict
comparison (no fast math) included. Over the example's eight frames the
port's outputs are bit-identical before and after except the accumulated
colour: the unrolled upsample loops, which Metal fast math contracts and
reassociates differently (SDK-P22), move 6 (1920×1080) and 40 (1280×720) of
2,073,600 texels by at most 2 binary16 ulp, and RCAS's output after them by
at most 4.

What remains is naga's bounds policy for `textureLoad` of a sampled texture:
it clamps the level to `get_num_mip_levels() - 1` with `metal::min`, which the
Metal compiler does not fold even for level 0, and takes the texture size at
that level. Loading at a constant level measured up to 0.03 ms of accumulate
and 0.01 ms of reconstruct; removing it needs unchecked shader modules
(`unsafe`) or a naga change.


## Native presentation adaptation

`sp-fidelity-wgpu::presentation` ports the retained SDK 1.1.4
`FrameInterpolationSwapchain{DX12,VK}` sources at the same pinned revision as
the compute port. Original sources and licenses are retained under
`vendor/sdk-1.1.4/sdk/src/backends/`; they are references, not build inputs for
the Rust runtime. The implementation preserves generation/real ordering,
interpolation-only presentation, callbacks and frame metadata, UI formulas,
completion-based pacing, enable/reset transitions, draining and bounded reuse.

Required Rust/wgpu adaptations:

- The SDK's Vulkan game-queue composition path keeps all `Rc` SDK callbacks
  and contexts on their owner thread. Two bounded output slots hold prepared
  images; owned wgpu textures cross threads, never transient SDK handles.
  A completion worker waits for the interpolation submission and a separate
  presenter worker acquires/copies/presents. Default real-only output uses
  the SDK non-interpolated game-queue path: acquire, compose once directly
  into the surface in the caller encoder, submit, present. It skips workers
  and intermediate copies. Generated-frame default composition is recorded
  with the caller work in one submission. wgpu queue ordering replaces a CPU
  wait after each surface copy; draining joins workers then waits for a queue
  marker covering their reads before resource destruction. Both UI registration modes
  submit input reads before returning; no additional UI snapshot is necessary.
- wgpu exposes one queue. Async compute/present queue selection, priorities,
  native semaphores, DXGI/Vulkan swapchain interception, exclusive fullscreen,
  OS latency handles, HDR metadata and Anti-Lag integration cannot be ported
  through its portable API. Surface configuration remains caller-owned.
  GPU submission waits replace native fences; completion observation and
  presentation-call timestamps do not establish scanout timing. Bounded FIFO
  delivery replaces native scheduled-entry replacement/dropping.
- Surface output uses raw-format views; BGRA surfaces use RGBA storage
  intermediates. The consumer supplies display-encoded input and transfer
  metadata. Default composition preserves alpha with no UI, and writes alpha
  one with UI, matching the original HLSL. Custom callbacks receive an owned
  composition output rather than an acquired native swapchain image.
- Native standard-library threads and monotonic nanosecond timing replace
  Win32 threads, QPC and events. AMD's ten-sample mean/standard deviation,
  warmup, 100 ms timeout, float promotion, truncation order, variance factor
  and safety margin are retained. Hybrid sleep has no portable OS timer
  resolution control. Reconfiguration drains and resets timing; shutdown
  joins workers. WASM builds the compute APIs and pacing math only.
- Surface acquisition failures retire slots and are reported to the caller;
  transient occlusion/timeouts do not poison later frames. Lost/outdated
  surfaces require explicit reconfiguration. Generation failure presents the
  real image instead of an unwritten interpolation output (upstream error
  handling can retain the scheduled generated image). Custom composition
  errors abort the frame and remain visible to the caller.
- AMD's debug bar colors/cycle are retained, overlaid after composition.
  The pinned DX12/Vulkan paths draw debug before the default full-frame UI
  pass, which can overwrite it. The adapter fixes that ordering and preserves
  scene pixels outside the 32-pixel indicator strip.

Validation on Apple M5 / Metal:

- `presentation_pacing` compiles the unchanged AMD moving-average template
  and interpolation-thread arithmetic into a C++ oracle. 800 timestamp/reset/
  tuning samples, including timeout boundaries, across four counter frequencies match exactly.
- `presentation_composition` compiles unchanged AMD UI HLSL through DXC and
  SPIRV-Cross to Metal. Copy, straight and premultiplied paths match RGBA8
  output byte-for-byte over 256 varied input pixels per path.
- Native GPU boundary tests exercise generated/real ordering, source and UI
  overwrite while presentation is blocked, callback thread/resource scope,
  external interpolation, generation failure, enable/disable, transient
  surface recovery, reconfiguration and joined shutdown.
- `fsr3_present --frames 120` runs actual composite upscaling and interpolation
  into a real window with UI, generation toggles, resize and shutdown.

These establish the tested algorithm and lifecycle boundaries, not complete
DX12/Vulkan conformance, identical OS scheduling or visual correctness.
