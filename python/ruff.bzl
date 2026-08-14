"""Hermetic ruff from GitHub releases; workspace check and format targets."""

load("@bazel_utils_core//internal:labels.bzl", "manifest_label", "workspace_rel_dir")
load("@bazel_utils_core//internal:workspace_tool.bzl", "workspace_test_tags", "workspace_tool_rule")

def _ruff_paths(dirs):
    """Workspace-root paths: `//python` → `python`."""
    out = []
    for d in dirs:
        if d.startswith("//") or d.startswith(":") or d.startswith("@"):
            path = workspace_rel_dir(d)
            out.append(path if path else ".")
        else:
            out.append(d)
    return out

_ruff_test = workspace_tool_rule(
    tool_attr = "ruff",
    tool_default = Label("//:ruff"),
    tool_doc = "Prebuilt ruff from GitHub releases (override to use another).",
    flags_doc = "First ruff argv (check <dirs>).",
    doc = "bazel test: ruff check + format --check against the workspace (no-sandbox).",
    require_flags = True,
    use_manifest = True,
    manifest_flag = "--config",
    test = True,
)

_ruff_format = workspace_tool_rule(
    tool_attr = "ruff",
    tool_default = Label("//:ruff"),
    tool_doc = "Prebuilt ruff from GitHub releases (override to use another).",
    flags_doc = "ruff argv (format <dirs>).",
    doc = "bazel run: ruff format against the workspace.",
    require_flags = True,
    use_manifest = True,
    manifest_flag = "--config",
    executable = True,
    test = False,
)

def ruff_test(
        name,
        workspace = "//:MODULE.bazel",
        manifest = "//:pyproject.toml",
        tags = [],
        dirs = [],
        flags = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's ruff after cd to the consumer workspace.

    The linter binary is the GitHub release for the exec OS/CPU. Config is the
    consumer `manifest` (`[tool.ruff]` in pyproject.toml).

    Runs `ruff --config <manifest> check <flags> <dirs>` then
    `ruff --config <manifest> format --check <dirs>` (both run; non-zero if
    either fails). Defaults `local = True` and tags `external`, `no-cache`,
    `no-sandbox`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      manifest: Consumer pyproject.toml (default `//:pyproject.toml`).
      tags: Extra test tags; merged with the defaults above.
      dirs: Bazel paths from repo root (e.g. `["//python"]` → `python`).
      flags: Extra ruff check flags before `dirs`.
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`ruff`, `size`, …).
    """
    paths = _ruff_paths(dirs)
    _ruff_test(
        name = name,
        workspace = workspace,
        manifest = manifest_label(manifest),
        tags = workspace_test_tags(tags),
        flags = ["check"] + flags + paths,
        also = ["format", "--check"] + paths,
        local = local,
        **kwargs
    )

def ruff_format(
        name,
        workspace = "//:MODULE.bazel",
        manifest = "//:pyproject.toml",
        dirs = [],
        flags = [],
        **kwargs):
    """Run that formats the consumer workspace with bazel_utils's ruff.

    The binary is the GitHub release for the exec OS/CPU. Defaults to
    `ruff --config <manifest> format <dirs>`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      manifest: Consumer pyproject.toml (default `//:pyproject.toml`).
      dirs: Bazel paths from repo root (e.g. `["//python"]` → `python`).
      flags: Extra ruff format flags before `dirs`.
      **kwargs: Forwarded to the run rule (`ruff`, …).
    """
    _ruff_format(
        name = name,
        workspace = workspace,
        manifest = manifest_label(manifest),
        flags = ["format"] + flags + _ruff_paths(dirs),
        **kwargs
    )
