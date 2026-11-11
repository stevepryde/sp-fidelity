# SDK conformance record

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
| Accumulate and accumulate + sharpen | all 64 option combinations × FP32 and FP16; upscale 1.0–3.0 with odd sizes, partial tiles and a maximum render size above the render size, plus 1920×1080-class low-resolution motion; application, default and auto exposure; resets | strict (both compiled without fast math or contraction, DXC's six constant folds applied to the WGSL): bit-exact, 11,570 dumps. With wgpu's fast math on both sides (SDK-P22), 4,335 differ with identical inputs and 4,410 when each side carries its own history; recorded, not bounded |
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
The controls compare every captured output exactly in both identical-input
replay and independent history. Across all eleven cases, identical-input
replay produced 4,934 exact dumps and 194 SDK-P14 mip-6 differences;
independent history produced 4,917 exact dumps, 195 direct SDK-P14 differences,
and 16 unchanged mip-6 values inherited from a prior racy dispatch.

These exceptions are restricted to the single mip-6 texel of the two FI SPD
pyramids. The original trace must establish a multi-workgroup epilogue and
mip 5 must compare exactly. An inherited value must match that side's last
actual writer, with the port's pre/post-job bytes unchanged. No general
floating-point tolerance is used. The original SPD publication issue is
retained rather than changing the algorithm; see SDK-P14 below.

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
  configuration is forwarded to an application adapter; wgpu does not
  implement the SDK's DXGI/Vulkan proxy swapchains, OS presentation threads,
  UI composition or frame pacing. The compute algorithms and SDK dispatch
  sequencing are independent of that presentation adapter.
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

### SDK-P14 — SPD hand-off between workgroups

`ffx_spd.h:132–144` hands off between workgroups with an atomic and a
group-shared barrier only; the texture is not necessarily `globallycoherent`,
and HLSL `InterlockedAdd` is not a memory fence. Publication between
workgroups is therefore not guaranteed by the SDK itself, and a stale read in
the WGSL is original behaviour.

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
