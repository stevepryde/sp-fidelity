# Oracle shaders

`generated/<effect>/<variant>/` holds the unchanged **FidelityFX SDK 1.1.4**
pass HLSL (`../sp-fidelity/vendor/sdk-1.1.4`, revision
`c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`) compiled for the Metal oracle,
one directory per permutation options value. AMD's MIT license applies to them
as derivatives of the SDK source. They are the oracle's shader path, not the
port's, and are never shipped. Only the FSR2 host test's variants are tracked;
the others are generated before a Metal oracle run (see Regeneration).

Each pass has:

- `.metal`: DXC to SPIR-V (the SDK's wave32 arguments: SM6.2, `FFX_HLSL_SM=62`,
  HLSL 2021, `FFX_HALF` and `-enable-16bit-types` for the FP16 table, the
  effect's compile arguments and the permutation's option defines), then
  SPIRV-Cross to MSL. Entry point `main0`. The FP16 table is the one the SDK's
  blob accessor selects: `ffx_fsr2_shaderblobs.cpp` takes the 32-bit table of
  `fsr2_rcas` and `fsr2_compute_luminance_pyramid` whatever `ALLOW_FP16` says
  (the tool's `fp32_only`).
- `.reflection.json`: DXC's reflection of the pass (resource names, registers,
  array indices, constant-buffer sizes) joined to the Metal argument indices,
  and the workgroup size. The C++ host oracle builds its binding tables from it.
- `manifest.json`: the effect, its passes in SDK pass order, the forced-wave64
  flag and, per pass, the permutation options it was compiled for and the
  exact command. The Metal oracle runs a pipeline only with the variant
  compiled for the trace's pass and options.

## Adaptations

The HLSL is unchanged. The translation adds only what the Metal target needs:

| Boundary | Translation |
| --- | --- |
| D3D typed UAV formats | `vk::image_format` from the C++ resource descriptions, before SPIR-V compilation; no format widened. |
| HLSL resource bounds | Texture loads outside the coordinates or mips return zero; stores outside are discarded. |
| Read/write texture visibility | SPIRV-Cross's `img.fence()` before read/write texture loads is kept (see SDK-P14). |
| Texture atomics (FSR2) | MSL 3.1, which has them natively; below it SPIRV-Cross emulates them through a buffer the texture must alias. |

Forced wave64 is not supported: the tool refuses the flag and the oracle
rejects a trace that asks for it.

## Regeneration

```sh
python3 tools/compile_dxc_oracle.py --effect fsr2 --options 0x04 \
  --dxc ~/VulkanSDK/1.4.357.1/macOS/bin/dxc-3.7 --spirv-cross /opt/homebrew/bin/spirv-cross
```

This writes `generated/fsr2/options-0x04/`; `--pass-name` limits it to some
passes and `--output` chooses another directory. Intermediate files go to
`target/dxc-oracle/`.

Tracked, and refreshed only when the SDK pin or the translation changes: the
FSR2 host test's variants (the exceptions in `.gitignore`). For base options
`0x05` and `0x06` (FP16 devices) the host test selects every pass but RCAS and
`fsr2_accumulate_sharpen` at `base | 0x80`, `fsr2_rcas` at `base` and
`fsr2_accumulate_sharpen` at `base | 0xa0`; for `0x1b` and `0x1c` (FP32
devices) every pass but `fsr2_accumulate_sharpen` at `base` and
`fsr2_accumulate_sharpen` at `base | 0x20`. A forced-wave64 table reuses its
wave32 variant's reflection.

Not tracked: the other variants the GPU pass tests (`tests/fsr2_passes.rs`)
select. Before a Metal oracle run, generate them all from this crate's
directory; this rewrites the tracked ones unchanged:

```sh
for o in $(seq 0 63) $(seq 128 191); do
  a=fsr2_accumulate; [ $((o & 32)) -ne 0 ] && a=fsr2_accumulate_sharpen
  set -- --pass-name $a --pass-name fsr2_depth_clip --pass-name fsr2_reconstruct_previous_depth \
    --pass-name fsr2_lock --pass-name fsr2_generate_reactive --pass-name fsr2_tcr_autogenerate
  [ $o -lt 128 ] && set -- "$@" --pass-name fsr2_rcas --pass-name fsr2_compute_luminance_pyramid
  python3 tools/compile_dxc_oracle.py --effect fsr2 --options $o "$@" \
    --dxc ~/VulkanSDK/1.4.357.1/macOS/bin/dxc-3.7 --spirv-cross /opt/homebrew/bin/spirv-cross
done
```

Every options value of both tables, `0x00`-`0x3f` and `0x80`-`0xbf`, gets the
depth clip, reconstruct-previous-depth, lock, generate-reactive and TCR passes,
and `fsr2_accumulate` without `ENABLE_SHARPENING` (`0x20`) or
`fsr2_accumulate_sharpen` with it. RCAS and the luminance pyramid have only
the 32-bit table, so only `0x00`-`0x3f`; RCAS's variants are identical, since
no FSR2 option reaches it.

Toolchain proven on Apple M5, macOS, 2026-09-30, with DXC 1.9.0.5399
(`libdxcompiler.dylib: 1.9(5399-a107ba61)`, Vulkan SDK 1.4.357.1) and
SPIRV-Cross 1.4.357.0 (Homebrew): every FSR2 pass compiled for options `0x04`
and `0x84` (FP16), and `fsr2_accumulate_sharpen` for `0xa4`, builds a Metal
compute pipeline in `oracle/metal.mm` (`--compiler-mode wgpu`). For RCAS the
tool runs:

```sh
dxc-3.7 -spirv -fspv-target-env=vulkan1.1 -T cs_6_2 -E CS -HV 2021 \
  -DFFX_GPU=1 -DFFX_HLSL=1 -DFFX_HLSL_SM=62 -DFFX_HALF=0 \
  -Wno-for-redefinition -Wno-ambig-lit-shift \
  -DFFX_FSR2_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0 \
  -DFFX_FSR2_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0 \
  -DFFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=1 \
  -DFFX_FSR2_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0 \
  -DFFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2 \
  -DFFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE=0 -DFFX_FSR2_OPTION_HDR_COLOR_INPUT=0 \
  -DFFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS=1 -DFFX_FSR2_OPTION_JITTERED_MOTION_VECTORS=0 \
  -DFFX_FSR2_OPTION_INVERTED_DEPTH=0 -DFFX_FSR2_OPTION_APPLY_SHARPENING=0 \
  -I <gpu> -I <gpu>/fsr2 \
  -fvk-t-shift 0 0 -fvk-u-shift 64 0 -fvk-b-shift 128 0 -fvk-s-shift 192 0 \
  -Fo fsr2_rcas.spv sdk/src/backends/dx12/shaders/fsr2/ffx_fsr2_rcas_pass.hlsl
spirv-cross fsr2_rcas.spv --msl --msl-version 30100 \
  --rename-entry-point CS main0 comp --output fsr2_rcas.metal
spirv-cross fsr2_rcas.spv --reflect --output fsr2_rcas.spirv.json
```

`<gpu>` is a copy of `sdk/include/FidelityFX/gpu` whose
`fsr2/ffx_fsr2_callbacks_hlsl.h` carries the `vk::image_format` annotations.
The register shifts are the port's WGSL binding offsets, 64 registers per
class. A manifest records each command with the checkout's paths relative to
the crate.
