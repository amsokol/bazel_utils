# bazel_utils

Starlark helpers for Bazel workspaces.

Public rules: `golangci_test`, `govulncheck_test`, `markdownlint_test`, `buildifier_test`, `buildifier_format`, `ruff_test`, `ruff_format`, `cargo_audit_test`.

Go binaries (golangci-lint, govulncheck, buildifier) are pinned in this module's `go.mod`. `markdownlint-cli2` is pinned in the pnpm catalog. Ruff is pinned in this module's `uv.lock`. `cargo-audit` is pinned in this module's `Cargo.lock` (crate_universe lockfile `cargo-bazel-lock.json`). The consumer does not need those tools in their own module. `go list` still uses the consumer's Go SDK so analysis matches the code under test. Markdown config (`.markdownlint-cli2.yaml`) and Ruff config (`pyproject.toml` `[tool.ruff]`) stay in the consumer.

## Use

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils", version = "0.1.0")

local_path_override(
    module_name = "bazel_utils",
    path = "../bazel_utils",
)
```

```starlark
# BUILD.bazel
load("@bazel_utils//:go.bzl", "golangci_test", "govulncheck_test")
load("@bazel_utils//:markdown.bzl", "markdownlint_test")
load("@bazel_utils//:bazel.bzl", "buildifier_format", "buildifier_test")
load("@bazel_utils//:python.bzl", "ruff_format", "ruff_test")
load("@bazel_utils//:rust.bzl", "cargo_audit_test")

golangci_test(
    name = "lint",
    dirs = ["//go"],
)

govulncheck_test(
    name = "vuln",
    dirs = ["//go"],
)

markdownlint_test(
    name = "markdown",
)

buildifier_test(
    name = "lint",
)

buildifier_format(
    name = "format",
)

ruff_test(
    name = "lint",
    dirs = ["//python"],
)

ruff_format(
    name = "format",
    dirs = ["//python"],
)

cargo_audit_test(
    name = "vuln",
)
```

Default `workspace = "//:MODULE.bazel"` (override if the marker is elsewhere). `manifest` is the consumer language file next to MODULE.bazel: Go `//:go.mod`, ruff `//:pyproject.toml`, cargo-audit `//:Cargo.toml`. `config` is the linter file: golangci `//:.golangci.yaml`, markdownlint `//:.markdownlint-cli2.yaml`. Go tests and `cargo_audit_test` default `local = True` and tags `external`, `no-cache`, `no-sandbox`, `requires-network`; markdownlint, buildifier, and ruff tests omit `requires-network`. `cargo_audit_test` also defaults `lock = "//:Cargo.lock"`. `dirs` are Bazel paths from the repo root (`//go` → `<root>/go/...`, `//python` → `<root>/python`). Pass `golangci` / `govulncheck` / `markdownlint` / `buildifier` / `ruff` / `cargo_audit` only to replace this module's binaries.
