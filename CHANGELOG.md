# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
While the major version is 0, compatible fixes and tool-pin updates bump the
patch; breaking Starlark API changes bump the minor.

## [Unreleased]

### Added

- `buf_deps`: import-only proto tree with its own `strip_import_prefix`
  (include root). Subfolders stay, so files can import each other.
- `buf_module` `deps`: `buf_deps` targets staged at those import paths,
  not passed to `buf_format`. Distinct from `buf.yaml` `deps` (BSR).

## [0.2.8] - 2026-09-18

### Added

- `buf_generate` puts the root module's `protoc.plugin` tags on PATH
  automatically (not catalog fallbacks). Extra `plugins` (`buf_plugin` or
  other executables) are merged; the same PATH name prefers the explicit
  target.

### Changed

- Raised every language module and the aggregator to `0.2.8` (lockstep).

## [0.2.7] - 2026-09-18

### Added

- `bazel_utils_protoc`: prebuilt `protoc-gen-*` plugins from GitHub
  (`protoc-gen-buffa`, `protoc-gen-buffa-packaging`, `protoc-gen-connect-go`,
  `protoc-gen-connect-rust`, `protoc-gen-go`, `protoc-gen-grpc-gateway`,
  `protoc-gen-openapiv2`, `protoc-gen-protovalidate-buffa`). Version catalog
  is `plugins/<name>/registry.bzl` (same shape as `buf.toolchains` /
  `registry.bzl`). Select a tag with `protoc.plugin(name, version)`. Canonical
  labels: `@bazel_utils_protoc//plugins/<name>`. `bazel_utils_buf` re-exports
  them at `@bazel_utils_buf//protoc/plugins/<name>` for `buf_generate`.
  Fallback tags when this module is root: buffa/packaging `v0.9.2`, connect-go
  `v1.21.0`, connect-rust `v0.9.0`, go `v1.36.12`, grpc-gateway/openapiv2
  `v2.30.0`, protovalidate `v0.10.0`.

### Changed

- Raised every language module and the aggregator to `0.2.7` (lockstep).

## [0.2.6] - 2026-09-17

### Added

- `bazel_utils_buf`: Buf CLI `v1.73.0` in the fetch catalog (`registry.bzl`).
  `v1.72.0` stays available.

### Changed

- `bazel_utils_buf`: fallback `buf.toolchains` when this module is root is
  `v1.73.0`.
- Bumped Python `build` from 1.6.0 to 1.6.1 (`bazel_utils_python`).
- markdownlint ignores nested `.venv` trees (`**/.venv/**`), not only a
  repo-root `.venv`.
- Raised every language module and the aggregator to `0.2.6` (lockstep).

## [0.2.5] - 2026-09-10

### Changed

- Bumped gazelle to 0.54.0 (`bazel_utils_go`).
- Bumped golang.org/x/vuln (govulncheck) from 1.7.0 to 1.8.0 (`bazel_utils_go`).
- Bumped rules_python to 2.3.3 (`bazel_utils_python`).
- Raised every language module and the aggregator to `0.2.5` (lockstep).

## [0.2.4] - 2026-09-06

### Changed

- Bumped the Go toolchain pin from 1.26.6 to 1.27.1 (`bazel_utils_go`).
- Bumped golangci-lint from 2.12.2 to 2.13.2 (`bazel_utils_go`).
- Bumped gazelle to 0.53.0 and rules_go to 0.63.0 (`bazel_utils_go`).
- Bumped protobuf from 35.1 to 36.1.bcr.1 (`bazel_utils_buf`).
- Bumped ruff from 0.16.3 to 0.16.6 and Python `build` from 1.5.0 to 1.6.0
  (`bazel_utils_python`).
- Bumped rules_python to 2.3.2 and aspect_rules_py to 1.12.1
  (`bazel_utils_python`).
- Bumped rules_rust to 0.74.0 (`bazel_utils_rust`).
- Bumped aspect_rules_js to 3.4.1 (`bazel_utils_md`).
- Raised every language module and the aggregator to `0.2.4` (lockstep).

## [0.2.3] - 2026-08-24

### Fixed

- `bazel_utils_buf`: `buf_generate` installs local plugins as `name.exe` on
  Windows so native `buf.exe` can find them. Go `LookPath` only searches
  PATHEXT; the Unix extensionless bash wrappers were "not found in %PATH%".

### Changed

- Raised every language module and the aggregator to `0.2.3` (lockstep).

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

[unreleased]: https://github.com/amsokol/bazel_utils/compare/v0.2.8...HEAD
[0.2.8]: https://github.com/amsokol/bazel_utils/compare/v0.2.7...v0.2.8
[0.2.7]: https://github.com/amsokol/bazel_utils/compare/v0.2.6...v0.2.7
[0.2.6]: https://github.com/amsokol/bazel_utils/compare/v0.2.5...v0.2.6
[0.2.5]: https://github.com/amsokol/bazel_utils/compare/v0.2.4...v0.2.5
[0.2.4]: https://github.com/amsokol/bazel_utils/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/amsokol/bazel_utils/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/amsokol/bazel_utils/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/amsokol/bazel_utils/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/amsokol/bazel_utils/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/amsokol/bazel_utils/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/amsokol/bazel_utils/releases/tag/v0.1.0
