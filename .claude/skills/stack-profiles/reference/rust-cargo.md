# Profile: rust-cargo

Rust with cargo. Suits binaries, libraries, simulation cores and WASM modules
that a JavaScript or Godot front end drives.

## Gate commands for project.conf

    gate | format    | optional | . | cargo fmt --check
    gate | lint      | required | . | cargo clippy --all-targets -- -D warnings
    gate | typecheck | required | . | cargo check --all-targets
    gate | unit      | required | . | cargo test
    gate | coverage  | required | . | cargo llvm-cov --fail-under-lines 100
    gate | build     | required | . | cargo build --release
    gate | mutation  | optional | . | cargo mutants

    task | install | - | . | cargo fetch
    task | dev     | - | . | cargo run
    task | test    | - | . | cargo test

`cargo check` and `clippy` overlap; keeping both is cheap and the failure
messages differ usefully.

## Layout

    src/                    production code, unit tests in-module
    tests/                  integration tests, one binary per file
    benches/                criterion benchmarks, if performance is a criterion
    Cargo.toml              deps with exact-enough versions
    Cargo.lock              committed for binaries

## paths.conf additions

Rust puts unit tests inside source files under `#[cfg(test)]`, which the phase
lock cannot separate from production code. Two options:

- **Keep them in-module** and accept that `src/**/*.rs` is classified `source`.
  The RED phase then cannot write them. Prefer integration tests in `tests/` for
  story work, and treat in-module tests as an implementation detail written
  during GREEN.
- **Move story-level tests to `tests/`** entirely, which the defaults already
  classify as `test`. This is the recommended arrangement under this harness.

## Notes for the bootstrap story

- Install `cargo-llvm-cov`; it is the coverage tool that works without nightly.
- A workspace with a `core` library crate and a thin binary makes the logic
  testable without the IO. Do this from the start.
- For WASM, add `wasm-bindgen` and a `build-wasm` gate; test the core crate
  natively and keep the binding layer thin enough to need almost no tests.
- Set `-D warnings` in the clippy gate, not in CI config, so it means the same
  thing locally.

## Testing notes

`proptest` for invariants - Rust's type system removes whole classes of test,
so what remains is mostly logic and boundaries. `insta` for snapshots of
generated output, reviewed rather than blessed blindly.

## Prerequisites

`rustup` installs and manages the whole toolchain.

    # Windows
    winget install --id Rustlang.Rustup
    # macOS / Linux
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

On Windows, rustup will ask for the MSVC build tools if they are absent; accept,
or install them first with:

    winget install --id Microsoft.VisualStudio.2022.BuildTools

Then the extras the gates use:

    rustup component add clippy rustfmt
    cargo install cargo-llvm-cov
    cargo install cargo-mutants     # optional, mutation gate

Verify: `cargo --version`, `cargo clippy --version`, `cargo llvm-cov --version`.

`cargo install` builds from source and is slow the first time - expect several
minutes for `cargo-llvm-cov`.
