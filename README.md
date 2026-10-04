# sp-fidelity

Unofficial Rust and WGSL port of AMD FidelityFX FSR2 from FidelityFX SDK
1.1.4, with a wgpu backend. MIT licensed. Not an AMD product or endorsed by AMD.

The Rust/WGSL port was produced entirely using AI coding agents. Its
conformance evidence and limitations are documented below. This project is
independent of [Traverse Research's `fidelityfx` bindings](https://github.com/Traverse-Research/fidelityfx-rs).

| Package | Purpose |
| --- | --- |
| [`sp-fidelity`](crates/sp-fidelity/README.md) | FSR2 host, SDK core, SPD, RCAS, and every FSR2 GPU pass as WGSL; no Rust dependencies |
| [`sp-fidelity-wgpu`](crates/sp-fidelity-wgpu/README.md) | SDK backend interface implemented on wgpu 29.0.4 |
| [`sp-fidelity-oracle`](crates/sp-fidelity-oracle/README.md) | Development-only comparisons with AMD's unchanged C++ host and HLSL; not published |

This is the FSR2 port and its supporting SDK code, not the entire FidelityFX
SDK. Applications own rendering, resource inputs, motion vectors, jitter,
frame scheduling, and submission. Neither runtime crate depends on SGL.

## Use from Git

The crates are prepared for their first crates.io release but are not yet
published. Until then, use both packages from this repository:

```toml
[dependencies]
sp-fidelity = { git = "https://github.com/stevepryde/sp-fidelity" }
sp-fidelity-wgpu = { git = "https://github.com/stevepryde/sp-fidelity" }
wgpu = "=29.0.4"
```

Rust imports are `sp_fidelity` and `sp_fidelity_wgpu`.
See the [backend integration guide](crates/sp-fidelity-wgpu/README.md)
for device features, resource lifetimes, and command encoder ownership.
The backend requires native GPU features beyond baseline browser WebGPU.

## Scope and evidence

The vendored reference is AMD FidelityFX SDK 1.1.4, revision
`c6efa6bf7f2027b3ec94f28578bb5965eabb9e55`. Upstream sources and notices are
retained unchanged. Originally developed in SGL, this repository starts with
a standalone extraction; historical short commit IDs in the conformance
record refer to that earlier development history. The host and shader port
follows that SDK; adaptations
and known differences are recorded in
[CONFORMANCE.md](crates/sp-fidelity/CONFORMANCE.md).

Recorded GPU conformance evidence is from Apple M5 / Metal. It includes
known fast-math and cross-workgroup differences; it does not establish
DX12/Vulkan parity. See the record before choosing supported platforms.

## Development

Use the pinned Rust toolchain. From the repository root:

```sh
cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
SP_FIDELITY_REQUIRE_GPU=1 cargo test --workspace
cargo doc --no-deps --workspace
```

The host oracle needs `clang++` (or `CXX`). GPU tests need a compatible
adapter; `SP_FIDELITY_REQUIRE_GPU=1` makes its absence a failure. On hosts
without a compatible adapter, omit that variable to allow backend GPU tests
to skip. The ignored Metal oracle tests additionally need generated shader
variants and the documented DXC/SPIRV-Cross toolchain; see
[oracle tests](crates/sp-fidelity-oracle/README.md#tests).

## Publishing

Both runtime packages start at `0.1.0`; the oracle stays `publish = false`.
The backend depends on the matching `sp-fidelity` registry version while
using its local path during development. See [RELEASING.md](RELEASING.md)
for packaging and publication commands.

## License

MIT; see [LICENSE](LICENSE). AMD's copyright and permission notices remain
with the SDK and port. The backend and port modifications are also MIT.
Dependencies retain their own licenses.
