# Releasing

The runtime packages are `sp-fidelity` and `sp-fidelity-wgpu`.
`sp-fidelity-oracle` is development tooling and must remain unpublished.
All three packages use MIT. Preserve their package-local license files and
the unchanged upstream notices in `vendor/`.

## Prepare

Set the release version in `[workspace.package]` and update both internal
version requirements in `[workspace.dependencies]`. Describe changes in the
package documentation and record any SDK differences in `CONFORMANCE.md`.
Run the [development checks](crates/sp-fidelity-oracle/README.md#development-checks)
separately from publishing.

From a clean commit, prepare and build both registry packages without uploading:

```sh
cargo publish --dry-run -p sp-fidelity -p sp-fidelity-wgpu
```

Cargo stages the two selected packages together, so the backend can be
verified before the new core version exists on crates.io. The runtime
archives include their sources, shaders where applicable, and MIT licenses;
the core also includes its vendored reference and conformance record. Oracle
code and generated Metal shaders are repository-only development material.

## Publish when authorized

With an authenticated crates.io account, publish the selected packages:

```sh
cargo publish -p sp-fidelity -p sp-fidelity-wgpu
```

Cargo publishes them in dependency order. Do not include the oracle.
After the first release, replace the README's Git dependency example with:

```toml
[dependencies]
sp-fidelity = "0.1.0"
sp-fidelity-wgpu = "0.1.0"
wgpu = "29.0.4"
```

Applications import `sp_fidelity` and `sp_fidelity_wgpu`.
