# sp-fidelity-oracle

Development-only evidence for the [`sp-fidelity`](../sp-fidelity/README.md) port
and [`sp-fidelity-wgpu`](../sp-fidelity-wgpu/README.md). Not
published; nothing depends on it. It holds the FSR2 host test
(`tests/fsr2_host_event_stream.rs`); the SSSR and denoiser cases were removed
with their port (009b728).

- `oracle/host.cpp` runs AMD's unchanged C++ host of an effect through a
  recording `FfxInterface` that prints one JSON event per backend call.
  `oracle/<effect>_host.cpp` drives the effect (`runEffect()`, see
  `oracle/host.h`). `oracle/compat.h` only supplies the Windows wide-character
  ABI. `host.cpp` also replaces `ffx_message.cpp`, which drops every message
  outside Windows, with its Windows callback path, so a driver can record
  messages with `recordMessage`.
- `oracle/metal.mm` executes a C++ trace's jobs with the DXC-compiled unchanged
  SDK HLSL translated to Metal ([shaders/README.md](shaders/README.md)); each
  pipeline runs the variant compiled for its pass and permutation options.
  With `--replay` it reloads every pass's inputs from the port's capture.
  With `--time N` it also runs each compute job N more times between GPU
  timestamps, with textures allocated as wgpu allocates them.
- `examples/fsr2_timing.rs` times FSR2's passes (`cargo run -p
  sp-fidelity-oracle --release --example fsr2_timing`): the compiled HLSL in
  the Metal oracle against the port through the wgpu backend, from the same
  captured inputs.
- `src/`: `host` builds and runs the C++ host for an `Effect`; `recorder` is
  the same recording backend for the port; `gpu` runs the port with a capture
  of every job and replays the trace on Metal; `compare` compares the two per
  pass.
- `tools/compile_dxc_oracle.py` compiles the pass HLSL for the Metal oracle;
  [shaders/README.md](shaders/README.md) records the proven toolchain and its
  exact DXC and SPIRV-Cross commands.

## Adding an effect

1. Add its table to `tools/compile_dxc_oracle.py` (passes in SDK pass order,
   SDK compile arguments, permutation-option defines, typed UAV formats) and
   compile every permutation options value its host selects.
2. Write `oracle/<effect>_host.cpp`: read the case from `word()`/`scalar()`,
   create the context with `backend()`, register application resources with
   `external()`, and print `frame()` and `result("create-result" |
   "dispatch-result" | "destroy-result", status)` around the SDK calls.
3. Describe it as a `sp_fidelity_oracle::Effect` (passes, driver, SDK sources
   and include directories).
4. Host test: run the port with `recorder::Recorder` the way the driver runs
   the C++ host, and compare the event streams and `init_data` with
   `host::run_cpp_host`.
5. GPU tests: `gpu::write_inputs`, run the port with `gpu::Capture`, write the
   C++ trace to `cpp.jsonl` (initialization data into `inputs/`), then
   `gpu::replay` and `compare::compare` with the effect's documented
   exceptions (CONFORMANCE.md).

The C++ host reads the device capabilities (`fp16Supported`,
`waveLaneCountMin`, `waveLaneCountMax`, `maximumSupportedShaderModel`) and
then the driver's words from stdin. Events: `resource` (name, type, format,
width, height, mips, usage, init type, init size, init value, heap type,
initial state, id, depth, flags), `register` (the registered resource),
`pipeline` (pass, options, indirect, root-constant sizes, samplers with their
stage, name, context flags, stage, backbuffer format, root-constant stages),
`constants`, `clear` (target, color, label), `copy` (…, label), `compute`
(pass, dimensions, indirect arguments and offset, bindings with mip, slot and
array index, constant buffers with slot, label), `memory-usage`, `execute`,
`unregister`, the `destroy-*` events, `message` (type, text), `frame` and the
driver's results. Bindings come from the DXC reflection of each compiled
variant, as AMD's generated per-permutation tables do.

## Tests

Run these tests when the port or backend changes. The workspace tests include
the host comparisons, which need clang++:

```sh
cargo test -p sp-fidelity-oracle
```

The GPU tests of an effect and `examples/fsr2_timing.rs` also need Metal and
the compiled variants they select. Only the host tests' variants are tracked:
generate the others first ([shaders/README.md](shaders/README.md#regeneration)),
then select the GPU tests explicitly:

```sh
cargo test -p sp-fidelity-oracle --release -- --ignored --nocapture
```

Captures, traces and reports go to `target/gpu-oracle/<case>-run-<time>`.

## Pass tests before the host

`src/pass.rs` runs one pass without an effect host: the port's WGSL for a
blob and, from the same inputs and constant buffers, the compiled unchanged
HLSL on Metal. It writes the case directory of the full-effect replay (a
`cpp.jsonl` with the `resource`, `pipeline`, `frame` and `compute` events the
C++ host would print, `inputs/`, `wgpu-inputs/`, `wgpu/`), so `gpu::replay`
and `compare::compare` run unchanged, and a host trace later replaces the
synthetic one. Resources persist from job to job, so a pass can read its own
previous outputs: `gpu::replay` feeds the Metal oracle the port's inputs of
every job, and `gpu::run_sequence` runs the trace from `inputs/` alone, each
side carrying its own outputs. `pass::port_variant` writes naga's MSL of the
port's WGSL as an oracle variant, so `gpu::replay_strict` runs the port and
the original through the same Metal compiler without fast math.

`tests/fsr2_passes.rs` covers FSR2's RCAS (`oracle/fsr2_rcas_constants.cpp`
computes its `cbRCAS` with AMD's host code) and the accumulate passes, whose
jobs, `cbFSR2` and Lanczos LUT data come from AMD's C++ host
(`oracle/fsr2_host.cpp`), in every permutation.
