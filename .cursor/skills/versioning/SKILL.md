---
name: versioning
description: >-
  Bump bazel_utils module versions in lockstep (Rust-style 0.x or SemVer after
  1.0.0) and create the matching GitHub tag. Use when releasing, tagging,
  bumping module(version), editing MODULE.bazel versions, or updating README
  git_override tags.
---

# Versioning

One release version for the whole repo. Even if only one language module changed, bump **every** module and the root `MODULE.bazel`, then tag GitHub.

## Scheme

Versions are `MAJOR.MINOR.PATCH`. `module(version = "0.1.0")` has **no** `v`. The git tag and `git_override(tag = …)` **do**: `v0.1.0`.

If **major is 0** (Rust approach):

- Breaking change → bump **minor** (`0.1.2` → `0.2.0`)
- Bugfix or new features (compatible) → bump **patch** (`0.1.0` → `0.1.1`)

If **major > 0** (standard SemVer):

- Breaking → **major**
- Compatible features → **minor**
- Bugfixes → **patch**

Do not skip numbers. Do not jump to `1.0.0` unless the user explicitly wants a stable public API.

**Breaking** means consumer-visible Starlark: renamed/removed rules or attrs, required new attrs, provider changes, `buf.toolchains` / `buf.plugins` contract. Pinned tool upgrades are a patch (0.x) or minor (≥1.0) unless they force a breaking API/output change.

Tool pins (Buf CLI, ruff, plugins like `protoc-gen-protovalidate-buffa`) are **not** this version — see `update-pinned-tools` in the consumer repo.

## Lockstep files

Set the same `MAJOR.MINOR.PATCH` everywhere:

- Root `MODULE.bazel`: `module(version = …)` and every `bazel_dep(name = "bazel_utils_*", version = …)`
- Each language module `module(version = …)`: `bazel/`, `buf/`, `core/`, `go/`, `markdown/`, `python/`, `rust/`
- Each language module's `bazel_dep(name = "bazel_utils_core", version = …)` (except `core/` itself)
- `README.md`: “Current module version”, every example `bazel_dep(… version = …)`, every `git_override(… tag = "v…")`

Refresh `MODULE.bazel.lock` if it changes.

## Release

After the version commit is on the default branch, create an annotated tag and push it (only when the user asked to release):

```bash
git tag -a "vMAJOR.MINOR.PATCH" -m "vMAJOR.MINOR.PATCH"
git push origin "vMAJOR.MINOR.PATCH"
```

Examples: `v0.1.0`, `v0.1.1`, `v0.2.0`. Consumers pin that tag in `git_override`.
