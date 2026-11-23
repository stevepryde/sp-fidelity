# sp-fidelity-wgpu

Frame generation is experimental and unsupported because visual artifacts remain.
It is disabled by default behind `frame-generation`.
[C++ reproductions](https://github.com/stevepryde/sp-fidelity/tree/main/crates/sp-fidelity-oracle/repro/frameinterpolation_edges) are retained and fixes are welcome;
no further frame-generation development is planned.

The wgpu backend of the [`sp-fidelity`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/README.md) port: an
implementation of the SDK's `FfxInterface`, as AMD's DX12 and Vulkan backends
are. The port was produced entirely using AI coding agents as a 1:1 port
of the original SDK source. This project is unofficial and not affiliated
with, endorsed by, or supported by AMD.

Resources and pipelines come from the SDK's descriptions and shader blobs:
layouts from each blob's binding tables, binding types reflected from the
port's WGSL for that blob. Compute (direct and indirect), copy and clear jobs
are recorded into the caller's `wgpu::CommandEncoder`.

## Use

For FSR upscaling, request `features_for(adapter.features())` when creating
the device: `required_features()` where the adapter has them, as native
adapters do, and `core_required_features()` otherwise, which a browser's
WebGPU can grant ([Resource sets](#resource-sets)). The device also needs
`storage_textures_per_stage(effect)` storage textures a shader stage.
The standalone reflections denoiser uses core WebGPU features. Both effects
can use FP16 permutations when the device enables `SHADER_F16`. Get the
backend interface and hand it to the SDK effect context:

```rust
let (backend, interface) = sp_fidelity_wgpu::ffx_get_interface_wgpu(&device);
// Each frame, before the effect's dispatch:
let command_list = backend.borrow_mut().ffx_get_command_list_wgpu(encoder);
let color = backend.borrow_mut().ffx_get_resource_wgpu(&texture, "Color", FFX_RESOURCE_STATE_COMPUTE_READ);
// … dispatch with command_list and the resources, then:
let encoder = backend.borrow_mut().ffx_take_command_list_wgpu(command_list).unwrap();
if let Some(error) = backend.borrow_mut().take_job_error() {
    // A job failed (error.code, and wgpu's reason in error.message): the
    // effect's output is undefined this frame; the encoder is still valid.
}
queue.submit([encoder.finish()]);
```

`FfxCommandList` is the SDK's `void*`. `ffx_get_command_list_wgpu` (the analogue
of `ffxGetCommandListDX12`) moves the caller's encoder into the backend and
returns its handle; `ffx_take_command_list_wgpu` hands it back with the jobs
recorded. A caller that records into a shared frame encoder can swap in a new
encoder (`std::mem::replace`) and submit the command buffers in order.

A failed job records nothing invalid and the jobs after it are not executed,
so the encoder stays valid. A job whose new views or bind group wgpu rejects
(for example a destroyed texture) fails with `FFX_ERROR_BACKEND_API_ERROR`
before recording them (SDK-P28). The SDK's dispatch ignores the backend's
result, so `take_job_error` reports the first failure since it was last called,
with wgpu's message where wgpu rejected an object. Only new objects are
checked: a bind group a pipeline kept was checked when it was made, so a
texture destroyed after that is recorded and fails at `queue.submit`. Invalid
inputs can still invalidate the encoder while a job records, for example one
texture passed as both an input and the output (a usage conflict).

`ffx_get_resource_wgpu` (the analogue of `ffxGetResourceDX12`) describes a
texture with `ffx_get_resource_description_wgpu`; the handle stays valid until
the next `ffx_take_command_list_wgpu`. Each pass views a texture as its binding
declares. A UAV of a mip the texture lacks views its last mip, as AMD's Vulkan
backend binds it: FSR2's luminance pyramid binds mips 4 and 5 of a texture that
has them only from a 64-pixel maximum render size. FI SPD instead binds
distinct inert views for absent mips, avoiding incompatible access aliases;
its mip-count guards leave these views unused. A copy destination needs
`COPY_DST` and a copy source `COPY_SRC`. FSR3's shared, upscaling and frame
interpolation interfaces must be clones of the same interface: resource and
command-list handles belong to one backend instance. Shared optical-flow
textures need `TEXTURE_BINDING | STORAGE_BINDING`; buffer-backed passes
synchronize their original textures so subsequent effects and caller reads
see their writes. Frame interpolation specializes output pipelines from the
actual bound output texture format and caches each format variant.

FI's inpainting pyramids complete their tile writes before their upper-mip
reduction in a second compute pass. WGSL cannot express the SDK's globally
coherent cross-workgroup handoff. This scheduling adaptation preserves AMD's
reduction arithmetic and intermediate precision; no application changes are
needed. Timestamp pairs span both passes. See SDK-P14 in
[CONFORMANCE.md](../sp-fidelity/CONFORMANCE.md) for the exact original-HLSL
comparison and its platform limits.

Dispatch jobs belong to their effect context. Unregistering a failed frame
discards its unexecuted jobs before registration slots are reused. Pending
resource initialization uploads survive a failed dispatch and are recorded
before the next valid workload, including uploads for shared effect contexts.
Timestamp pools measure SDK compute jobs; clear and copy jobs consume no slots.
A job's pair spans both of a split SPD's dispatches; the transfers of a
texture a pass binds as a buffer are not timed.

Each pipeline keeps the bind groups of the last two resource sets its jobs
bound (FSR2 alternates two by frame) and its own uniform buffers, into which
each job's constants are copied from one upload buffer per
`execute_gpu_jobs`. A kept group holds the textures it binds, so a caller's
texture stays allocated until its pipelines bind two other sets or the context
is destroyed.
`set_fp16_supported(false)` reports a device without FP16 so contexts created
afterwards use the FP32 permutations.

## Reflections denoiser

The SDK denoises a caller's traced reflections in three indirect compute passes.
The caller owns the tracer, both radiance and variance ping-pongs, the active
8×8 tile list, the indirect arguments and the output. Create the context at
the render size and swap each ping-pong pair once per frame. Supply noisy
RGB and reflected ray length in radiance A's alpha. The resolve writes RGB
and duplicates blue into alpha, as in AMD's shader.

| Dispatch resource | wgpu allocation |
| --- | --- |
| Radiance A and B | `Rgba16Float`, sampled and storage. Radiance A also needs `COPY_SRC`. |
| Variance A and B | `backend.borrow().reflections_variance_format()`, sampled and storage. |
| Depth hierarchy | `R32Float` device depth, sampled and `COPY_SRC`. The history copy takes mip 0. |
| Normal | Filterable texture matching `normals_history_buffer_format`, sampled and `COPY_SRC`. |
| Motion | Sampled texture with XY motion, scaled by `motion_vector_scale`. |
| Extracted roughness | `R8Unorm`, sampled and `COPY_SRC`. |
| Tile list | `STORAGE` buffer of packed uint pixel origins, X in the low 16 bits, Y in the high 16. |
| Arguments | `STORAGE` and `INDIRECT` buffer. Write `[tile_count, 1, 1]` starting at byte offset 12. |
| Output | A separate `Rgba16Float` texture with `COPY_DST`. |

Register the texture inputs with `ffx_get_resource_wgpu`. Register buffers with
`backend.borrow_mut().ffx_get_buffer_resource_wgpu(&buffer, 4, name, state)?`.
Both registrations expire when the encoder is returned.

The device-only constructor uses `Rgba16Float` storage for the SDK's scalar
samples and variance, and truncates average radiance to unsigned 11/11/10-bit
precision at each store, matching the Direct3D conversion rule and Metal
typed stores. Native Vulkan hardware chooses its own rounding mode. With access to the device's original
adapter, `ffx_get_interface_wgpu_with_adapter(&device, &adapter)` selects
native narrow storage where enabled and writable. R32F depth history uses
hardware linear sampling when `FLOAT32_FILTERABLE` is enabled and four
clamped texel loads otherwise.

## Experimental frame generation

The `frame-generation` feature enables the core generation APIs and this
backend's `presentation` module and configuration callback. It forwards
`sp-fidelity/frame-generation`; upscaling needs neither feature.

```toml
sp-fidelity-wgpu = { version = "0.3.3", features = ["frame-generation"] }
```

Contributor examples:

```sh
cargo run -p sp-fidelity-wgpu --features frame-generation --example fsr3
cargo run -p sp-fidelity-wgpu --features frame-generation --example fsr3_present -- --frames 120
```

The retained [presentation contract](https://github.com/stevepryde/sp-fidelity/blob/main/PRESENTATION.md)
and [conformance record](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md)
describe resource ownership, pacing, platform adaptations and known limitations.

## Features

`required_features()` covers the features with which FSR2 and FSR3 run as the
SDK allocates and dispatches them:

| Feature | Needed for |
| --- | --- |
| `SUBGROUP` | SPD's wave operations in the luminance pyramid |
| `TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES` | UAVs in R16G16F, R16F, R8, R8G8, R11G11B10F; read-write R8, R16F and (allocated as RGBA32F) R32G32F UAVs |
| `TEXTURE_ATOMIC` | `InterlockedMin`/`InterlockedMax` on the R32_UINT reconstructed depth (R32 integer UAVs are created with `STORAGE_ATOMIC`, without which wgpu's Metal backend performs no texture atomic) |
| `TEXTURE_FORMAT_16BIT_NORM` | the R16_SNORM Lanczos and maximum-bias lookup textures |
| `FLOAT32_FILTERABLE` | linear sampling of 32-bit float application inputs |

`core_required_features()` is `FLOAT32_FILTERABLE` alone.
`features_for(available)` returns the first of the two sets `available` holds,
or `None`. One pass binds at most `storage_textures_per_stage(effect)` storage
textures (5 for FSR2, 6 for the FSR3 upscaler); WebGPU's default limit is 4, so
request the adapter's `max_storage_textures_per_shader_stage`.

Clears use storage writes, so `CLEAR_TEXTURE` is not needed. `R32Uint` clears
preserve the float colour's bit pattern, including the `1.0` depth sentinel;
`R8Uint` and `Rg16Sint` support the zero clears used by the SDK.

## Resource sets

The backend reads the device's features, as it reads `SHADER_F16` for
`fp16Supported`, and runs FSR2 and the FSR3 upscaler on one of two resource
sets. The SDK's descriptions, jobs and dispatches are the same on both; an
observer and `get_resource_description` see the SDK's description of every
resource.

- **The SDK's**, on a device with `TEXTURE_ADAPTER_SPECIFIC_FORMAT_FEATURES`,
  `TEXTURE_ATOMIC` and `TEXTURE_FORMAT_16BIT_NORM`: the SDK's formats,
  read-write storage textures and texture atomics, SPD in one dispatch.
- **The core set**, on any other device: storage textures in WebGPU's core
  formats and accesses, atomics in a storage buffer, and SPD in two
  dispatches. Every texel a pass writes is the one the SDK's set writes
  ([SDK-P38](../sp-fidelity/CONFORMANCE.md#sdk-p38--the-core-resource-set)).

| SDK format and access | Core allocation |
| --- | --- |
| `R16G16_FLOAT`, `R16_FLOAT` UAV | `Rgba16Float` |
| `R8G8_UNORM`, `R8_UNORM` UAV | `Rgba8Unorm` |
| `R11G11B10_FLOAT` UAV | `Rgba16Float`; the port truncates each store to 11/11/10 bits |
| `R8_UNORM` read-write (new locks) | `R32Float` holding the unorm value |
| `R32G32_FLOAT`, `R32G32B32A32_FLOAT` 1×1 read-write (auto exposure, frame info) | `R32Float` 2×1 or 4×1, a texel a component |
| `R32_UINT` with `InterlockedMin`/`Max` (reconstructed previous depth) | `R32Uint`, its words in a storage buffer of atomics while the pass runs |
| `R16_SNORM` lookups | `R32Float` holding each snorm value; no pass of the core set reads one |
| mips SPD reads and writes | `Rgba16Float`, write-only in SPD's first dispatch and read-only in its second |

Subgroups are separate: with `SUBGROUP` SPD uses its wave operations, and
without it the SDK's `FFX_SPD_NO_WAVE_OPERATIONS` path. A device without
subgroups reports no wave lanes, so the SDK selects the permutations of
hardware without 64-wide waves.

A caller's own textures follow the set. Create FSR3's shared textures with
`ffx_create_texture_wgpu(FfxEffect::Fsr3Upscaler, &description)` and register
each with `ffx_get_described_resource_wgpu`, which keeps the SDK's
description. A texture a generate-reactive pass writes is `R8Unorm` on the
SDK's set and `Rgba8Unorm` on the core set. `ffx_sdk_texels_wgpu` and
`ffx_texels_from_sdk_wgpu` convert texels between an allocation and the SDK's
layout, for captures and uploads.

Frame generation runs on the SDK's set only.

## WASM and WebGPU

The runtime crates compile for `wasm32-unknown-unknown` with wgpu's WebGPU
backend enabled. Shader reflection uses Naga directly from wgpu's compatible
release line.

FSR2 and FSR3 upscaling run in a browser on the core resource set, where the
adapter has `float32-filterable` and six storage textures a stage. The
browser compiles the port's WGSL itself, so the core set's source also holds
to what WGSL's specification requires and naga does not: no infinite constant
expression, no two written pointers into one variable, and no
`workgroupBarrier` after a branch on a value the workgroup does not share
(SPD's one-dispatch exit, which its two dispatches do not take). A job's
validation error cannot be read back there (SDK-P28): leave it to the page's
error scopes and uncaptured-error handler.
`readback::Readback::read_all` blocks for GPU completion and is
native-only; it panics on WebGPU. GPU tests and the oracle remain native-only.

## Platform workarounds

Only here, never in the port:

- SDK-P10: wgpu turns an indirect dispatch above 65,535 groups into no work.
  A conversion pass writes a bounded 2D grid from the SDK's arguments and the
  pass entry point is wrapped to rebuild the SDK's logical group ID; surplus
  groups return before any barrier.
- SDK-P6: wgpu cannot force a subgroup size, so the backend reports shader
  model 6.2 and the SDK never selects a wave64 permutation.
- Metal has no read-write `Rg32Float` storage texture: an `R32G32_FLOAT` UAV
  the effect creates (FSR2's auto exposure) is an `Rgba32Float` texture, its
  initial data widened with zero `.zw`; the port reads and writes `.xy`.
- WGSL texture atomics return nothing. FSR2 and FSR3 upscaler SPD counters
  become private storage buffers on first use; their initial data and clears
  are preserved. Frame interpolation game-vector fields and optical flow's
  scene-change output, histogram, and temporary counters use packed
  `R32Uint` buffers while retaining
  their original texture handles. Compute transfers synchronize those texels
  before buffer-backed reads and after writes, including across effects.
- Metal cannot read and write `Rg16Sint` textures in one pass. Optical flow's
  advanced search binds a packed storage buffer, with signed X in the low
  16 bits and signed Y in the high 16 bits. Transfers preserve the texture's
  signed 16-bit values; later texture passes and caller reads see its writes.
- Metal cannot read and write `Rg16Float` textures in one pass. FSR3 upscaler's
  SPD mip texture is allocated as `Rgba16Float`; only `.xy` stores SDK data.
  Its read-write declarations are specialized by the backend. Other RG16F
  resources retain their original format on the SDK's resource set.
- SDK-P38: a device without the SDK's storage formats, read-write accesses
  or texture atomics runs FSR2 and the FSR3 upscaler on the core resource
  set ([Resource sets](#resource-sets)).
- Optical flow's optional 1D allocations use one-row 2D textures to match
  the original shaders' 2D bindings. Logical SDK descriptions remain 1D.
- SDK-P28: wgpu reports a view or bind group it rejects when it is created,
  but recording it invalidates the caller's whole encoder at `finish`. A
  clear or compute job creates its new ones inside validation and
  out-of-memory error scopes and fails before recording them if wgpu rejects
  one; execution stops at the first failed job. On WebGPU the scopes resolve
  only after the call, so there the error stays deferred to `finish`.
- Observers see each resource's SDK description beside the object, so a
  capture can write the SDK's layout.

`set_job_observer` sees every job before and after it is recorded, with its
resources and the encoder; `readback::Readback` copies resources out. The
fidelity tests in `sp-fidelity-oracle` use both.

## License

MIT. See `LICENSE.txt`; upstream copyright and permission notices are retained.
