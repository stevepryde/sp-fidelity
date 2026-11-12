# Agent instructions

- This workspace owns the FidelityFX Rust/WGSL port, its wgpu backend, and
  development-only oracles. Games and renderer-specific policy belong to consumers.
- Keep the port faithful to the vendored AMD FidelityFX SDK. Rust/wgpu/WGSL
  adaptations must preserve its behavior. Do not change FSR3 algorithms unless
  a bug is verified in AMD's original C++/HLSL implementation, or a measured
  optimization improves performance without losing quality. Record the evidence
  and any necessary platform constraints in `crates/sp-fidelity/CONFORMANCE.md`.
  Replaying original shaders with consumer-supplied inputs does not validate
  those inputs: rule out consumer integration errors before changing the port.
- Preserve the SDK's MIT license and provenance. Do not change vendored
  sources to make a comparison pass.
- Runtime behavior and public API changes must update the package README
  and affected examples. Platform integration adaptations belong in the backend.
- Run `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D warnings`,
  and `cargo test --workspace`. Run the affected oracle comparisons for
  algorithm changes; their setup is in `crates/sp-fidelity-oracle/README.md`.
- Test observable behavior against upstream or an independent boundary.
  Do not add source-text checks or assertions derived from the implementation.
- Generated oracle shaders are refreshed only by their explicit export
  command when inputs or format change. Do not add staleness checks or hashes.
- Do not publish crates, create releases, or add CI workflows without an
  explicit request. Packaging checks are separate from publication commands.
