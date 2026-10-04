# SDK conformance record

Authority: FidelityFX SDK 1.1.4, revision
`c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`, retained unedited in
`vendor/sdk-1.1.4`. Evidence comes from the two oracles in
[`sp-fidelity-oracle`](../sp-fidelity-oracle/README.md): AMD's unchanged C++ host
behind a recording `FfxInterface`, and the DXC-compiled unchanged pass HLSL on
Metal replaying each pass from the inputs the port's WGSL received.

FSR2 (SDK component 2.x as shipped in 1.1.4) is the ported effect. The host
core, `ffx_core.wgsl` and `spd/ffx_spd.wgsl` were first verified through the
SSSR and denoiser passes (removed in 009b728); they are re-verified here
through FSR2. Results are from Apple M5, Metal, wgpu 29.0.4, DXC 1.9.0.5399
(HLSL 2021, the SDK's bundled compiler default), SPIRV-Cross 1.4.357,
2026-09-30.

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
| Compute luminance pyramid | every permutation | 12,734 exact; 513 within FSR2-F1/F2 (`AutoExposure`, at most 1.5e-8); 337 SDK-P14 (`AutoExposure`, up to 0.53, only when the epilogue runs and mip 5 was written) |

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

## Differences and platform adaptations

IDs are kept from the SSSR record; the removed ones applied only to SSSR and
the denoiser.

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

### SDK-P14 — SPD hand-off between workgroups

`ffx_spd.h:132–144` hands off between workgroups with an atomic and a
group-shared barrier only; the texture is not necessarily `globallycoherent`,
and HLSL `InterlockedAdd` is not a memory fence. Publication between
workgroups is therefore not guaranteed by the SDK itself, and a stale read in
the WGSL is original behaviour.

In FSR2 the difference appears only in `FSR2_AutoExposure`, when the
luminance pyramid runs SPD's epilogue (more than six mips) and mip 5 was
written by another workgroup: up to 0.53 in 337 dumps.

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

GPU time, Apple M5, 1920×1080 display, SGL3D's permutations (`0x97`,
sharpening `0xb7`, RCAS `0x17`), median of 5 rounds of 90 back-to-back
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
