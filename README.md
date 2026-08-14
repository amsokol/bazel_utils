# bazel_utils

Starlark helpers for Bazel workspaces.

Public rules: `golangci_test`, `govulncheck_test`, `markdownlint_test`, `buildifier_test`, `buildifier_format`.

Go binaries (golangci-lint, govulncheck, buildifier) are pinned in this module's `go.mod`. `markdownlint-cli2` is pinned in the pnpm catalog. The consumer does not need those tools in their own module. `go list` still uses the consumer's Go SDK so analysis matches the code under test. Markdown config (`.markdownlint-cli2.yaml`) stays in the consumer.

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
```

Default `workspace = "//:MODULE.bazel"` (override if the marker is elsewhere). Go tests default `go_mod = "//:go.mod"` (next to MODULE.bazel), `local = True`, and tags `external`, `no-cache`, `no-sandbox`, `requires-network`; markdownlint and buildifier tests omit `requires-network`. `dirs` are Bazel paths from the repo root (`//go` → `<root>/go/...`), not relative to `go.mod`. Pass `golangci` / `govulncheck` / `markdownlint` / `buildifier` only to replace this module's binaries.
