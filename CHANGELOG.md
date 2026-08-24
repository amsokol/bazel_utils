# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
While the major version is 0, compatible fixes and tool-pin updates bump the
patch; breaking Starlark API changes bump the minor.

## [Unreleased]

## [0.2.2] - 2026-08-24

### Added

- `bazel_utils_rust`: Windows ARM64 `cargo-audit` via cargo-quickinstall
  (`aarch64-pc-windows-msvc`). RustSec does not publish that triple.

### Changed

- Raised every language module and the aggregator to `0.2.2` (lockstep).

## [0.2.1] - 2026-08-17

### Added

- `bazel_utils_bazel`: `exclude_patterns` on `buildifier_test` and `buildifier_format` (`find … ! -path`, same shape as buildifier-prebuilt). Empty keeps `buildifier -r .`.

### Changed

- Raised every language module and the aggregator to `0.2.1` (lockstep).

## [0.2.0] - 2026-08-16

### Removed

- `bazel_utils_buf`: `buf.plugins` module-extension tag, `@buf_plugins`, and shipped plugin sources (`buf/plugins/…`). Build local codegen plugins in the consumer and pass them to `buf_generate(plugins = …)` via `buf_plugin`.

### Changed

- Raised every language module and the aggregator to `0.2.0` (lockstep).

## [0.1.1] - 2026-08-14

### Changed

- Bumped the Go toolchain pin from 1.26.5 to 1.26.6 (`bazel_utils_go`).
- Raised every language module and the aggregator to `0.1.1` (lockstep).

## [0.1.0] - 2026-08-14

Initial tagged release. Language modules for Bazel workspaces:

- `bazel_utils_bazel` — `buildifier_test`, `buildifier_format`
- `bazel_utils_buf` — `buf_module`, `buf_generate`, `buf_lint_test`, `buf_format`, `buf_plugin`
- `bazel_utils_go` — `golangci_test`, `govulncheck_test`
- `bazel_utils_python` — `ruff_test`, `ruff_format`, `pip_audit_test`
- `bazel_utils_rust` — `cargo_audit_test`
- `bazel_utils_md` — `markdownlint_test`

Pin modules with `git_override` at tag `v0.1.0`. `bazel_utils_core` is a
transitive dependency, not a consumer API.

[unreleased]: https://github.com/amsokol/bazel_utils/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/amsokol/bazel_utils/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/amsokol/bazel_utils/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/amsokol/bazel_utils/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/amsokol/bazel_utils/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/amsokol/bazel_utils/releases/tag/v0.1.0
