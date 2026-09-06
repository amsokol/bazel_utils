# bazel_utils

Starlark helpers for Bazel workspaces. Each language is a **separate Bazel module**. Depend only on the modules you use. Tools (linters, scanners, Buf CLI) are pinned inside those modules; the consumer does not declare them again.

`bazel_utils_core` is pulled in transitively. The root module `bazel_utils` in this repository is an aggregator for development, not a consumer dependency.

Current module version: **0.2.4**. See [CHANGELOG.md](CHANGELOG.md) for release notes.

| Module | Load | Public API |
| --- | --- | --- |
| [`bazel_utils_bazel`](#bazel_utils_bazel) | `@bazel_utils_bazel//:bazel.bzl` | `buildifier_test`, `buildifier_format` |
| [`bazel_utils_buf`](#bazel_utils_buf) | `@bazel_utils_buf//:buf.bzl` | `buf_module`, `buf_generate`, `buf_lint_test`, `buf_format`, `buf_plugin` |
| [`bazel_utils_go`](#bazel_utils_go) | `@bazel_utils_go//:go.bzl` | `golangci_test`, `govulncheck_test` |
| [`bazel_utils_python`](#bazel_utils_python) | `@bazel_utils_python//:python.bzl` | `ruff_test`, `ruff_format`, `pip_audit_test` |
| [`bazel_utils_rust`](#bazel_utils_rust) | `@bazel_utils_rust//:rust.bzl` | `cargo_audit_test` |
| [`bazel_utils_md`](#bazel_utils_md) | `@bazel_utils_md//:markdown.bzl` | `markdownlint_test` |

Workspace-cd tests (`*_test` macros that `cd` to the consumer repo) default `local = True` and tags `external`, `no-cache`, `no-sandbox`. Networked tests also add `requires-network`. Config files stay in the consumer (`go.mod`, `pyproject.toml`, `buf.yaml`, `.golangci.yaml`, …).

Pass `buildifier` / `golangci` / `govulncheck` / `buf` / `ruff` / `pip_audit` / `cargo_audit` / `markdownlint` only to replace this module's binary.

Modules live in subdirectories of [amsokol/bazel_utils](https://github.com/amsokol/bazel_utils.git). Pin each language module with `git_override` at tag `v0.2.4` and `strip_prefix` matching that directory. Language modules depend on `bazel_utils_core` (no public macros, not on the Bazel Central Registry), so add this once:

```starlark
bazel_dep(name = "bazel_utils_core", version = "0.2.4")

git_override(
    module_name = "bazel_utils_core",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "core",
    tag = "v0.2.4",
)
```

---

## bazel_utils_bazel

Prebuilt [buildifier](https://github.com/bazelbuild/buildtools) (GitHub release, selected by exec OS/CPU). Recurses with `-r .` from the consumer workspace root. The binary has no `-exclude`; pass `exclude_patterns` (`find -path` globs such as `"./.venv/*"`) to skip trees.

### Add to a Bazel project

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_bazel", version = "0.2.4")

git_override(
    module_name = "bazel_utils_bazel",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "bazel",
    tag = "v0.2.4",
)
```

```starlark
# bazel/BUILD.bazel
load("@bazel_utils_bazel//:bazel.bzl", "buildifier_format", "buildifier_test")
```

### `buildifier_test`

`bazel test`: check Starlark files (`-mode=check -lint=warn` by default).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`. |
| `flags` | `string_list` | no | `["-mode=check", "-lint=warn"]` | buildifier argv. |
| `exclude_patterns` | `string_list` | no | `[]` | `find -path` globs to skip (e.g. `"./.venv/*"`). Empty uses `-r .`. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `buildifier` | `label` | no | this module's binary | Override the pinned buildifier. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
buildifier_test(
    name = "lint",
    exclude_patterns = [
        "./.venv/*",
        "./.bazel/*",
    ],
)
```

### `buildifier_format`

`bazel run`: format Starlark files (`-mode=fix` by default).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `flags` | `string_list` | no | `["-mode=fix"]` | buildifier argv. |
| `exclude_patterns` | `string_list` | no | `[]` | `find -path` globs to skip (e.g. `"./.venv/*"`). Empty uses `-r .`. |
| `buildifier` | `label` | no | this module's binary | Override the pinned buildifier. |

```starlark
buildifier_format(
    name = "format",
    exclude_patterns = [
        "./.venv/*",
        "./.bazel/*",
    ],
)
```

---

## bazel_utils_buf

Hermetic [Buf CLI](https://buf.build) (GitHub release via `buf.toolchains`), generate/lint/format, and consumer-built local codegen plugins (`buf_plugin`).

The generate/lint template (`buf.gen.yaml`) and `buf.yaml` `deps` are the source of truth. `buf_generate` passes the template to `buf generate --template` as-is (`out`, `include_imports`, `include_wkt`, `inputs`).

`remote:` plugins and BSR proto modules need network. Put `BUF_TOKEN` in the environment and in the consumer `.bazelrc`:

```bazelrc
build --action_env=BUF_TOKEN
test --test_env=BUF_TOKEN
```

The action sandbox does not inherit the user shell. Without this, buf runs anonymously and hits BSR rate limits.

### Add to a Bazel project

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_buf", version = "0.2.4")

git_override(
    module_name = "bazel_utils_buf",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "buf",
    tag = "v0.2.4",
)

buf = use_extension("@bazel_utils_buf//:extensions.bzl", "buf")
buf.toolchains(version = "v1.72.0")
use_repo(buf, "buf")
```

`buf.toolchains(version)` is required (CLI tag must exist in this module's `registry.bzl`). Build local plugins in the consumer and pass them to `buf_generate` with `buf_plugin`.

```starlark
# api/v1/BUILD.bazel
load("@bazel_utils_buf//:buf.bzl", "buf_format", "buf_generate", "buf_lint_test", "buf_module", "buf_plugin")
```

#### `buf.toolchains`

Module-extension tag. At most one per module; the root module's tag wins.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `version` | `string` | yes | — | Buf CLI release tag (must exist in this module's `registry.bzl`). |

### `buf_module`

Stages protos plus the consumer `buf.yaml` into a directory TreeArtifact (workspace-relative paths). `buf_generate` and `buf_lint_test` run Buf on that copy. `buf_format` uses the same `srcs` / `config` but writes the checkout.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `srcs` | `label_list` (`.proto`) | yes | — | Protobuf sources; workspace-relative paths are preserved. |
| `config` | `label` | no | `"//:buf.yaml"` | Consumer `buf.yaml`. |
| `visibility` | `string_list` | no | package default | Target visibility. |

```starlark
filegroup(
    name = "protos",
    srcs = glob(["*.proto"]),
)

buf_module(
    name = "module",
    srcs = [":protos"],
)
```

### `buf_generate`

`buf generate` over a `buf_module`. `plugins` (typically `buf_plugin`) are on PATH. Returns a directory TreeArtifact of the files buf wrote (for `write_source_files`). Those files must share one directory; use a separate `buf_generate` per template when `out` paths are unrelated. On Windows, `buf.exe` looks up plugins with PATHEXT (`.exe`, `.bat`); `buf_generate` copies each plugin as `name.exe` so native LookPath succeeds.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `module` | `label` (`buf_module`) | yes | — | Module to generate from. |
| `template` | `label` | yes | — | `buf.gen.yaml` passed to `buf generate --template`. |
| `plugins` | `label_list` (executable) | no | `[]` | Consumer-built local plugins (typically `buf_plugin`). Target **name** is the PATH name (`local:` in the template). |
| `buf` | `label` | no | `@buf//:buf` | Override the pinned Buf CLI. |
| `visibility` | `string_list` | no | package default | Target visibility. |

```starlark
buf_generate(
    name = "go",
    module = ":module",
    template = "//:buf.gen.go.yaml",
)
```

### `buf_plugin`

Wraps an executable so the target **name** is the PATH name `buf` looks up. Use it when the binary Bazel built is not already named like `protoc-gen-…` (crate_universe often emits `*_bin`). Pass the target to `buf_generate(plugins = …)`.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | PATH name buf looks up; must match `local:` in the template. |
| `actual` | `label` (executable) | yes | — | Binary to wrap. |

```starlark
buf_plugin(
    name = "protoc-gen-my-thing",
    actual = ":my_codegen_bin",
)

buf_generate(
    name = "rust",
    module = ":module",
    template = "//:buf.gen.rust.yaml",
    plugins = [":protoc-gen-my-thing"],
)
```

```yaml
# buf.gen.rust.yaml
plugins:
  - local: protoc-gen-my-thing
    out: rust/api/gen/my_thing
```

### `buf_lint_test`

`bazel test`: `buf lint` on a staged `buf_module`. Fetches `buf.yaml` `deps` from the BSR.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `module` | `label` (`buf_module`) | yes | — | Staged module to lint. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`, `requires-network`. |
| `paths` | `string_list` | no | `[]` | Repeated `buf lint --path`. Empty = whole module. |
| `size` | `string` | no | Bazel test default | Bazel test size. |
| `buf` | `label` | no | `@buf//:buf` | Override the pinned Buf CLI. |

```starlark
buf_lint_test(
    name = "lint",
    size = "small",
    module = ":module",
)
```

### `buf_format`

`bazel run`: `cd` to the consumer workspace, then `buf format -w` for the proto files in `module` (`--path` each, `--config` from that module's `buf.yaml`). Writes the checkout; does not format the staged copy.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `module` | `label` (`buf_module`) | yes | — | Module whose proto files are formatted in the checkout. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `flags` | `string_list` | no | `[]` | Extra argv after `format -w --config --path …`. |
| `buf` | `label` | no | `@buf//:buf` | Override the pinned Buf CLI. |

```starlark
buf_format(
    name = "format",
    module = ":module",
)
```

---

## bazel_utils_go

Prebuilt [golangci-lint](https://github.com/golangci/golangci-lint) (GitHub release) and [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) (pinned in this module's `go.mod`). `go list` still uses the **consumer's** rules_go SDK.

`dirs` are Bazel paths from the repo root (`"//go"` → `<root>/go/...`).

### Add to a Bazel project

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_go", version = "0.2.4")

git_override(
    module_name = "bazel_utils_go",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "go",
    tag = "v0.2.4",
)
```

```starlark
# go/BUILD.bazel
load("@bazel_utils_go//:go.bzl", "golangci_test", "govulncheck_test")
```

### `golangci_test`

`bazel test`: `golangci-lint --config <config> run <flags> <dirs>`. Needs the consumer `.golangci.yaml`. Defaults include `requires-network` (`GOPROXY=off` in the sandbox).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `manifest` | `label` | no | `"//:go.mod"` | Consumer `go.mod`. |
| `config` | `label` | no | `"//:.golangci.yaml"` | Consumer `.golangci.yaml`. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`, `requires-network`. |
| `dirs` | `string_list` | no | `[]` | Bazel paths from the repo root (`"//go"` → `<root>/go/...`). |
| `flags` | `string_list` | no | `[]` | Extra argv after `golangci-lint run`. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `golangci` | `label` | no | this module's binary | Override the pinned golangci-lint. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
golangci_test(
    name = "lint",
    dirs = ["//go"],
)
```

### `govulncheck_test`

`bazel test`: `govulncheck <flags> <dirs>`. Needs vuln.go.dev (`requires-network`).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `manifest` | `label` | no | `"//:go.mod"` | Consumer `go.mod`. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`, `requires-network`. |
| `dirs` | `string_list` | no | `[]` | Bazel paths from the repo root (`"//go"` → `<root>/go/...`). |
| `flags` | `string_list` | no | `[]` | Extra govulncheck argv. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `govulncheck` | `label` | no | this module's binary | Override the pinned govulncheck. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
govulncheck_test(
    name = "vuln",
    dirs = ["//go"],
)
```

---

## bazel_utils_python

Prebuilt [ruff](https://github.com/astral-sh/ruff) (GitHub release) and [pip-audit](https://pypi.org/project/pip-audit/) (pinned in this module's `uv.lock`). Ruff config is the consumer `pyproject.toml` (`[tool.ruff]`).

`dirs` are Bazel paths from the repo root (`"//python"` → `python`).

### Add to a Bazel project

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_python", version = "0.2.4")

git_override(
    module_name = "bazel_utils_python",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "python",
    tag = "v0.2.4",
)
```

```starlark
# python/BUILD.bazel
load("@bazel_utils_python//:python.bzl", "pip_audit_test", "ruff_format", "ruff_test")
```

### `ruff_test`

`bazel test`: `ruff --config <manifest> check <flags> <dirs>` then `ruff --config <manifest> format --check <dirs>` (both run; non-zero if either fails).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `manifest` | `label` | no | `"//:pyproject.toml"` | Consumer `pyproject.toml` (`[tool.ruff]`). |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`. |
| `dirs` | `string_list` | no | `[]` | Bazel paths from the repo root (`"//python"` → `python`). |
| `flags` | `string_list` | no | `[]` | Extra `ruff check` flags. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `ruff` | `label` | no | this module's binary | Override the pinned ruff. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
ruff_test(
    name = "lint",
    dirs = ["//python"],
)
```

### `ruff_format`

`bazel run`: `ruff --config <manifest> format <flags> <dirs>`.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `manifest` | `label` | no | `"//:pyproject.toml"` | Consumer `pyproject.toml` (`[tool.ruff]`). |
| `dirs` | `string_list` | no | `[]` | Bazel paths from the repo root (`"//python"` → `python`). |
| `flags` | `string_list` | no | `[]` | Extra `ruff format` flags. |
| `ruff` | `label` | no | this module's binary | Override the pinned ruff. |

```starlark
ruff_format(
    name = "format",
    dirs = ["//python"],
)
```

### `pip_audit_test`

`bazel test`: `uv export --frozen --all-groups` from the consumer lock, then `pip-audit -r … --disable-pip`. Needs OSV (`requires-network`).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `lock` | `label` | no | `"//:uv.lock"` | Consumer `uv.lock` (`uv export --frozen --all-groups`). |
| `manifest` | `label` | no | `"//:pyproject.toml"` | Consumer `pyproject.toml`. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`, `requires-network`. |
| `flags` | `string_list` | no | `[]` | Extra pip-audit argv. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `pip_audit` | `label` | no | this module's binary | Override the pinned pip-audit. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
pip_audit_test(
    name = "vuln",
)
```

---

## bazel_utils_rust

Prebuilt [cargo-audit](https://github.com/rustsec/rustsec/tree/main/cargo-audit). RustSec GitHub releases cover Unix and Windows AMD64; Windows ARM64 uses the [cargo-quickinstall](https://github.com/cargo-bins/cargo-quickinstall) build of the same version. `cargo -V` still uses the **consumer's** rules_rust toolchain.

### Add to a Bazel project

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_rust", version = "0.2.4")

git_override(
    module_name = "bazel_utils_rust",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "rust",
    tag = "v0.2.4",
)
```

```starlark
# rust/BUILD.bazel
load("@bazel_utils_rust//:rust.bzl", "cargo_audit_test")
```

### `cargo_audit_test`

`bazel test`: `cargo-audit audit --file <lock>`. Needs the rustsec advisory DB (`requires-network`).

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `lock` | `label` | no | `"//:Cargo.lock"` | Consumer `Cargo.lock`. |
| `manifest` | `label` | no | `"//:Cargo.toml"` | Consumer `Cargo.toml`. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`, `requires-network`. |
| `flags` | `string_list` | no | `[]` | Extra cargo-audit argv. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `cargo_audit` | `label` | no | this module's binary | Override the pinned cargo-audit. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
cargo_audit_test(
    name = "vuln",
)
```

---

## bazel_utils_md

[markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) pinned in this module's pnpm catalog. Config and globs come from the consumer `.markdownlint-cli2.yaml`.

### Add to a Bazel project

```starlark
# MODULE.bazel
bazel_dep(name = "bazel_utils_md", version = "0.2.4")

git_override(
    module_name = "bazel_utils_md",
    remote = "https://github.com/amsokol/bazel_utils.git",
    strip_prefix = "markdown",
    tag = "v0.2.4",
)
```

```starlark
# bazel/BUILD.bazel
load("@bazel_utils_md//:markdown.bzl", "markdownlint_test")
```

### `markdownlint_test`

`bazel test`: markdownlint-cli2 after cd to the consumer workspace.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Target name. |
| `workspace` | `label` | no | `"//:MODULE.bazel"` | Repo-root marker when `BUILD_WORKSPACE_DIRECTORY` is unset. |
| `config` | `label` | no | `"//:.markdownlint-cli2.yaml"` | Consumer markdownlint config and globs. |
| `tags` | `string_list` | no | `[]` | Extra tags; merged with `external`, `no-cache`, `no-sandbox`. |
| `local` | `bool` | no | `True` | Bazel `local` test attribute. |
| `flags` | `string_list` | no | `[]` | Extra markdownlint-cli2 argv. |
| `markdownlint` | `label` | no | this module's binary | Override the pinned markdownlint-cli2. |
| `size` | `string` | no | Bazel test default | Bazel test size. |

```starlark
markdownlint_test(
    name = "markdown",
)
```
