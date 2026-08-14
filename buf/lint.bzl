"""Workspace buf format and hermetic buf lint over a staged buf_module."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_utils_core//internal:runfiles.bzl", "rlocation")
load("@bazel_utils_core//internal:workspace_cd.bzl", "WORKSPACE_BASH")
load("@bazel_utils_core//internal:workspace_tool.bzl", "workspace_test_tags", "workspace_tool_rule")
load("//:generate.bzl", "module_directory")

_buf_format = workspace_tool_rule(
    tool_attr = "buf",
    tool_default = Label("@buf//:buf"),
    tool_doc = "Prebuilt Buf CLI from GitHub releases (override to use another).",
    flags_doc = "buf argv (format -w).",
    doc = "bazel run: buf format -w against the workspace.",
    executable = True,
    test = False,
)

def buf_format(
        name,
        workspace = "//:MODULE.bazel",
        flags = [],
        **kwargs):
    """Run that formats protobuf in the consumer workspace with this module's buf.

    Defaults to `buf format -w`. Config is the consumer `buf.yaml` at the
    workspace root after cd.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      flags: Extra argv after `format -w`.
      **kwargs: Forwarded to the run rule (`buf`, …).
    """
    _buf_format(
        name = name,
        workspace = workspace,
        flags = ["format", "-w"] + flags,
        **kwargs
    )

def _buf_lint_test_impl(ctx):
    """Test: `buf lint` inside a copy of the staged buf_module."""
    buf_bin = ctx.executable._buf
    if not buf_bin:
        fail("{}: buf is not executable".format(ctx.label))
    module_dir = module_directory(ctx)
    ws = ctx.workspace_name
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        content = "".join([
            "#!/usr/bin/env bash\n",
            "set -euo pipefail\n\n",
            WORKSPACE_BASH,
            "buf=$(_rf {})\n".format(shell.quote(rlocation(buf_bin, ws))),
            "module=$(_rf {})\n".format(shell.quote(rlocation(module_dir, ws))),
            "WORKDIR=$(mktemp -d)\n",
            "trap 'rm -rf \"$WORKDIR\"' EXIT\n",
            "cp -a \"$module/.\" \"$WORKDIR/\"\n",
            "chmod -R u+w \"$WORKDIR\"\n",
            "export HOME=\"$WORKDIR/home\"\n",
            "export BUF_CACHE_DIR=\"$WORKDIR/buf-cache\"\n",
            "mkdir -p \"$HOME\" \"$BUF_CACHE_DIR\"\n",
            "cd \"$WORKDIR\"\n",
            "\"$buf\" dep update\n",
            "exec \"$buf\" lint{}\n".format("".join(
                [" --path " + shell.quote(p) for p in ctx.attr.paths],
            )),
        ]),
        is_executable = True,
        output = script,
    )
    runfiles = ctx.runfiles(files = [script, buf_bin, module_dir])
    runfiles = runfiles.merge(ctx.attr._buf[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_buf_lint_test = rule(
    implementation = _buf_lint_test_impl,
    test = True,
    doc = "bazel test: buf lint over a staged buf_module (BSR deps from buf.yaml).",
    attrs = {
        "module": attr.label(
            allow_files = True,
            mandatory = True,
            doc = "buf_module TreeArtifact.",
        ),
        "_buf": attr.label(
            default = Label("@buf//:buf"),
            executable = True,
            cfg = "exec",
            allow_single_file = True,
        ),
        "paths": attr.string_list(
            doc = "Repeated `buf lint --path`. Empty = whole module (buf.yaml includes).",
        ),
    },
)

def buf_lint_test(name, module, tags = [], **kwargs):
    """Test that runs `buf lint` on a staged buf_module.

    `buf.yaml` `deps` are fetched from the BSR.

    Args:
      name: Target name.
      module: `buf_module` target.
      tags: Extra test tags.
      **kwargs: Forwarded to the test rule (`size`, `buf`, …).
    """
    _buf_lint_test(
        name = name,
        module = module,
        tags = workspace_test_tags(tags, requires_network = True),
        **kwargs
    )
