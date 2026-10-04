# sp-fidelity

A Rust and WGSL port of the
[AMD FidelityFX SDK 1.1.4](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/tree/c6efa6bf7f2027b3ec94f28578bb5965eabb9e55)
(revision `c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`). It contains nothing that
is not in the SDK, so it stays diffable against upstream; `vendor/sdk-1.1.4/`
retains the upstream files, their notices and revision, unedited. It is not an
AMD product.

Ported: the host core (types, errors, the backend interface, messages, object
management, utilities and shader-blob selection), the FSR2 host (`src/fsr2/`,
its blob accessor and the `FFX_CPU` code it includes from the GPU headers,
`src/gpu/`), and the GPU core, SPD, FSR1's RCAS and every FSR2 pass as WGSL.
[CONFORMANCE.md](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md) records the evidence against the SDK.

- Host: `sdk/include/FidelityFX/host/*.h` and `sdk/src/components/*` function
  for function, in Rust casing (module table in `src/lib.rs`).
- GPU: `shaders/wgsl/` mirrors `sdk/include/FidelityFX/gpu/` one module per
  header, plus one entry module per `sdk/src/backends/dx12/shaders/*_pass.hlsl`.
  Where WGSL forces a difference, a `// WGSL:` comment cites the SDK line.
- Backend interface: `interface::FfxInterface` is the SDK's function table. A
  graphics API backend implements it, as AMD's DX12 and Vulkan backends do;
  [`sp-fidelity-wgpu`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity-wgpu/README.md) is the wgpu
  one.

## Vendored SDK files

`vendor/sdk-1.1.4/`, unedited, with the revision in `source-revision.txt`:

- `LICENSE.txt`
- `sdk/include/FidelityFX/host/`: `ffx_assert.h`, `ffx_error.h`,
  `ffx_interface.h`, `ffx_message.h`, `ffx_types.h`, `ffx_util.h`, `ffx_fsr2.h`
- `sdk/include/FidelityFX/gpu/`: `ffx_common_types.h`, the `ffx_core*.h`
  headers, `spd/`, `fsr2/` (every file) and `fsr1/ffx_fsr1.h` (FSR2's RCAS)
- `sdk/src/shared/`: `ffx_assert.cpp`, `ffx_message.cpp`,
  `ffx_object_management.{h,cpp}`
- `sdk/src/components/fsr2/`
- `sdk/src/backends/shared/`: `ffx_shader_blobs.{h,cpp}` and
  `blob_accessors/ffx_fsr2_shaderblobs.{h,cpp}`
- `sdk/src/backends/dx12/shaders/fsr2/` and `CMakeShadersFSR2.txt`, which
  holds the FSR2 permutation defines
- `docs/techniques/super-resolution-temporal.md`

## Shaders

Shader blobs carry the pass and permutation instead of bytecode;
`shaders::ffx_get_wgsl_source` assembles the WGSL for a blob from the entry
module `<shader_name>.wgsl`. The blob's table supplies `FFX_HALF`, each bit
of its `PermutationKey` the matching `FFX_<EFFECT>_OPTION_*` define, and the
effect's shader build its fixed defines (FSR2's `FSR2_BASE_ARGS`). Pass
modules declare HLSL registers `tN`, `uN`, `bN`, `sN` at bindings `N`,
`64 + N`, `128 + N` and `192 + N` of group 0 (`shaders::FFX_WGSL_BINDING_OFFSET_*`,
also defined as WGSL constants), 64 registers per class.
`FORCE_WAVE64` blobs share the default source: WGSL cannot request a subgroup
size, so a backend must not report the shader model that selects them (SDK-P6).

## Evidence

[`sp-fidelity-oracle`](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity-oracle/README.md) compares a ported host
with AMD's unchanged C++ host, and every pass and permutation with the
DXC-compiled unchanged HLSL executed on Metal. [CONFORMANCE.md](https://github.com/stevepryde/sp-fidelity/blob/main/crates/sp-fidelity/CONFORMANCE.md)
records the results and every known difference. Supported AMD DX12/Vulkan
execution remains the authority; nothing here claims it.

## License

MIT. See `LICENSE.txt`; upstream copyright and permission notices are retained.
