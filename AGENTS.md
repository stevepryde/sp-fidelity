# Agent instructions

- This workspace owns the FidelityFX Rust/WGSL port, its wgpu backend, and
  development-only oracles. Games and renderer-specific policy belong to consumers.
- Keep the port 1:1 with the vendored AMD FidelityFX SDK. Differences are
  limited to Rust/wgpu/WGSL constraints, known upstream bug fixes, or explicit
  owner decisions; record them in `crates/sp-fidelity/CONFORMANCE.md`.
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
