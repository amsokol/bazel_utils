# bazel_utils

Starlark helpers for Bazel workspaces, split into modules in this repo:

| Module | Load | Rules |
| --- | --- | --- |
| `bazel_utils_bazel` | `@bazel_utils_bazel//:bazel.bzl` | `buildifier_test`, `buildifier_format` |
| `bazel_utils_buf` | `@bazel_utils_buf//:buf.bzl` | `buf_generate`, `buf_module`, `buf_lint_test`, `buf_format` |
| `bazel_utils_go` | `@bazel_utils_go//:go.bzl` | `golangci_test`, `govulncheck_test` |
| `bazel_utils_python` | `@bazel_utils_python//:python.bzl` | `ruff_test`, `ruff_format`, `pip_audit_test` |
| `bazel_utils_rust` | `@bazel_utils_rust//:rust.bzl` | `cargo_audit_test` |
| `bazel_utils_md` | `@bazel_utils_md//:markdown.bzl` | `markdownlint_test` |
| `bazel_utils_core` | (transitive) | workspace-cd helpers |

Depend only on the language modules you need. `bazel_utils_core` comes in transitively. The root `bazel_utils` module is this repo's aggregator (dogfood tests), not a consumer dependency.

Go binaries: **golangci-lint** is pinned in `go/golangci.MODULE.bazel` (GitHub release `http_archive`, selected by exec OS/CPU); **govulncheck** is pinned in `go/go.mod`. Prebuilt **buildifier** is pinned in `bazel/buildifier.MODULE.bazel` (GitHub release `http_file`, selected by exec OS/CPU). Prebuilt **ruff** is pinned in `python/ruff.MODULE.bazel` (GitHub release `http_archive`, selected by exec OS/CPU). Prebuilt **cargo-audit** is pinned in `rust/cargo_audit.MODULE.bazel` (GitHub release `http_archive`, selected by exec OS/CPU; no Windows ARM64 build upstream). Prebuilt **Buf CLI** is fetched by `buf.toolchains(version)` (GitHub release; hashes in `buf/registry.bzl`). Local codegen plugins live in `buf/plugins/<name>/<version>/`. BSR proto modules stay in the consumer `buf.yaml` `deps`. `markdownlint-cli2` is pinned in `markdown/` pnpm catalog. `pip-audit` is pinned in `python/uv.lock`. The consumer does not need those tools in their own module. `go list` still uses the consumer's Go SDK so analysis matches the code under test. `cargo -V` still uses the consumer's rules_rust toolchain. Markdown config (`.markdownlint-cli2.yaml`) and Ruff config (`pyproject.toml` `[tool.ruff]`) stay in the consumer.

## Use

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_bazel", version = "0.1.0")
bazel_dep(name = "bazel_utils_buf", version = "0.1.0")
bazel_dep(name = "bazel_utils_core", version = "0.1.0")
bazel_dep(name = "bazel_utils_go", version = "0.1.0")
bazel_dep(name = "bazel_utils_md", version = "0.1.0")
bazel_dep(name = "bazel_utils_python", version = "0.1.0")
bazel_dep(name = "bazel_utils_rust", version = "0.1.0")

local_path_override(
    module_name = "bazel_utils_bazel",
    path = "../bazel_utils/bazel",
)

local_path_override(
    module_name = "bazel_utils_buf",
    path = "../bazel_utils/buf",
)

local_path_override(
    module_name = "bazel_utils_core",
    path = "../bazel_utils/core",
)

local_path_override(
    module_name = "bazel_utils_go",
    path = "../bazel_utils/go",
)

local_path_override(
    module_name = "bazel_utils_md",
    path = "../bazel_utils/markdown",
)

local_path_override(
    module_name = "bazel_utils_python",
    path = "../bazel_utils/python",
)

local_path_override(
    module_name = "bazel_utils_rust",
    path = "../bazel_utils/rust",
)
```

Omit language `bazel_dep` / `local_path_override` pairs you do not use. Keep `bazel_utils_core` (or rely on it transitively and still override its path when developing against a checkout).

Put each language's targets in that language's package so names do not collide.

```starlark
# go/BUILD.bazel
load("@bazel_utils_go//:go.bzl", "golangci_test", "govulncheck_test")

golangci_test(
    name = "lint",
    dirs = ["//go"],
)

govulncheck_test(
    name = "vuln",
    dirs = ["//go"],
)
```

```starlark
# bazel/BUILD.bazel
load("@bazel_utils_bazel//:bazel.bzl", "buildifier_format", "buildifier_test")
load("@bazel_utils_md//:markdown.bzl", "markdownlint_test")

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

```starlark
# python/BUILD.bazel
load("@bazel_utils_python//:python.bzl", "pip_audit_test", "ruff_format", "ruff_test")

ruff_test(
    name = "lint",
    dirs = ["//python"],
)

ruff_format(
    name = "format",
    dirs = ["//python"],
)

pip_audit_test(
    name = "vuln",
)
```

```starlark
# rust/BUILD.bazel
load("@bazel_utils_rust//:rust.bzl", "cargo_audit_test")

cargo_audit_test(
    name = "vuln",
)
```

```starlark
# MODULE.bazel (Buf)
buf = use_extension("@bazel_utils_buf//:extensions.bzl", "buf")
buf.toolchains(version = "v1.72.0")
buf.plugins(name = "protoc-gen-protovalidate-buffa", version = "v0.6.0")
use_repo(buf, "buf", "buf_plugins")
```

```starlark
# api/v1/BUILD.bazel
load("@bazel_utils_buf//:buf.bzl", "buf_format", "buf_generate", "buf_lint_test", "buf_module")

buf_module(
    name = "module",
    srcs = [":protos"],
)

buf_lint_test(
    name = "lint",
    module = ":module",
)

buf_format(
    name = "format",
)
```

Default `workspace = "//:MODULE.bazel"` (override if the marker is elsewhere). `manifest` is the consumer language file next to MODULE.bazel: Go `//:go.mod`, ruff and pip-audit `//:pyproject.toml`, cargo-audit `//:Cargo.toml`. `config` is the linter file: golangci `//:.golangci.yaml`, markdownlint `//:.markdownlint-cli2.yaml`. All workspace-cd tests default `local = True` and tags `external`, `no-cache`, `no-sandbox`. Go tests, `pip_audit_test`, and `cargo_audit_test` also add `requires-network`. `pip_audit_test` defaults `lock = "//:uv.lock"` and audits all lock groups (`uv export --frozen --all-groups`). `cargo_audit_test` defaults `lock = "//:Cargo.lock"`. `dirs` are Bazel paths from the repo root (`//go` → `<root>/go/...`, `//python` → `<root>/python`). Pass `golangci` / `govulncheck` / `markdownlint` / `buildifier` / `ruff` / `pip_audit` / `cargo_audit` / `buf` only to replace this module's binaries.

## Develop

Language trees are separate Bazel modules (listed in `.bazelignore`). From this repo root:

```bash
bazel test //:lint
bazel test //:markdown
bazel test @bazel_utils_core//internal:workspace_rel_dir_test @bazel_utils_core//internal:workspace_file_label_test
```
