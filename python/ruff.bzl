"""Hermetic ruff from this module's uv lock; workspace check and format targets."""

load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("//internal:workspace_tool.bzl", "workspace_test_tags", "workspace_tool_rule")

def _ruff_binary_impl(ctx):
    """Copy `bin/ruff` out of the installed ruff wheel (no console_scripts)."""
    dirs = [
        f
        for f in ctx.attr.pkg[DefaultInfo].default_runfiles.files.to_list()
        if f.is_directory and f.basename == "install"
    ]
    if len(dirs) != 1:
        fail("{}: expected one wheel install dir from {}, got {}".format(
            ctx.label,
            ctx.attr.pkg.label,
            [d.path for d in dirs],
        ))
    exe = ctx.actions.declare_file(ctx.label.name)
    copy_file_action(ctx, dirs[0], exe, dir_path = ctx.attr.script_path)
    return [
        DefaultInfo(
            executable = exe,
            files = depset([exe]),
            runfiles = ctx.runfiles(files = [exe]),
        ),
    ]

ruff_binary = rule(
    implementation = _ruff_binary_impl,
    doc = "Native ruff executable from the pinned uv hub wheel install.",
    executable = True,
    attrs = {
        "pkg": attr.label(
            doc = "Hub package providing the installed ruff wheel.",
            mandatory = True,
        ),
        "script_path": attr.string(
            default = "bin/ruff",
            doc = "Path to the ruff binary inside the wheel install directory.",
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)

def _ruff_paths(dirs):
    """Workspace-root paths: `//python` → `python`."""
    out = []
    for d in dirs:
        if d.startswith("//") or d.startswith(":") or d.startswith("@"):
            out.append(_repo_dir(d))
        else:
            out.append(d)
    return out

def _repo_dir(label):
    if label.startswith("@") or label.startswith(":"):
        fail("dirs must be an absolute label in the consumer workspace, got {}".format(label))
    if not label.startswith("//"):
        fail("dirs must be an absolute Bazel label, got {}".format(label))
    rest = label[2:]
    if rest.startswith(":"):
        return "."
    if ":" in rest:
        pkg, _, _name = rest.partition(":")
        return pkg if pkg else "."
    return rest if rest else "."

_ruff_test = workspace_tool_rule(
    tool_attr = "ruff",
    tool_default = "//python:ruff",
    tool_doc = "ruff binary from bazel_utils uv lock (override to use another).",
    flags_doc = "First ruff argv (check <dirs>).",
    doc = "bazel test: ruff check + format --check against the workspace (no-sandbox).",
    require_flags = True,
    test = True,
)

_ruff_format = workspace_tool_rule(
    tool_attr = "ruff",
    tool_default = "//python:ruff",
    tool_doc = "ruff binary from bazel_utils uv lock (override to use another).",
    flags_doc = "ruff argv (format <dirs>).",
    doc = "bazel run: ruff format against the workspace.",
    require_flags = True,
    executable = True,
    test = False,
)

def ruff_test(name, workspace = "//:MODULE.bazel", tags = [], dirs = [], flags = [], **kwargs):
    """Test that runs bazel_utils's ruff after cd to the consumer workspace.

    The binary is pinned in this module's uv.lock. Config stays in the consumer
    (`pyproject.toml` `[tool.ruff]`).

    Runs `ruff check <flags> <dirs>` then `ruff format --check <dirs>`.
    Defaults tags to `external`, `no-cache`, `no-sandbox`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      tags: Extra test tags; merged with the defaults above.
      dirs: Bazel paths from repo root (e.g. `["//python"]` → `python`).
      flags: Extra ruff check flags before `dirs`.
      **kwargs: Forwarded to the test rule (`ruff`, `size`, `local`, …).
    """
    paths = _ruff_paths(dirs)
    _ruff_test(
        name = name,
        workspace = workspace,
        tags = workspace_test_tags(tags),
        flags = ["check"] + flags + paths,
        also = ["format", "--check"] + paths,
        **kwargs
    )

def ruff_format(name, workspace = "//:MODULE.bazel", dirs = [], flags = [], **kwargs):
    """Run that formats the consumer workspace with bazel_utils's ruff.

    The binary is pinned in this module's uv.lock. Defaults to `ruff format <dirs>`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      dirs: Bazel paths from repo root (e.g. `["//python"]` → `python`).
      flags: Extra ruff format flags before `dirs`.
      **kwargs: Forwarded to the run rule (`ruff`, …).
    """
    _ruff_format(
        name = name,
        workspace = workspace,
        flags = ["format"] + flags + _ruff_paths(dirs),
        **kwargs
    )
