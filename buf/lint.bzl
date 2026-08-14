"""Hermetic buf lint over a staged buf_module."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_utils_core//internal:runfiles.bzl", "rlocation")
load("@bazel_utils_core//internal:workspace_cd.bzl", "RUNFILES_BASH")
load("@bazel_utils_core//internal:workspace_tool.bzl", "workspace_test_tags")
load("//:generate.bzl", "BufModuleInfo", "module_directory")

def _buf_lint_test_impl(ctx):
    """Test: `buf lint` inside a copy of the staged buf_module."""
    buf_bin = ctx.executable.buf
    if not buf_bin:
        fail("{}: buf is not executable".format(ctx.label))
    module_dir = module_directory(ctx)
    ws = ctx.workspace_name
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        content = "".join([
            "#!/usr/bin/env bash\n",
            "set -euo pipefail\n\n",
            RUNFILES_BASH,
            "buf=$(_rf {})\n".format(shell.quote(rlocation(buf_bin, ws))),
            "module=$(_rf {})\n".format(shell.quote(rlocation(module_dir, ws))),
            "ROOT=$(mktemp -d)\n",
            "trap 'rm -rf \"$ROOT\"' EXIT\n",
            "WORKDIR=\"$ROOT/work\"\n",
            "mkdir -p \"$WORKDIR\" \"$ROOT/home\" \"$ROOT/buf-cache\"\n",
            "cp -a \"$module/.\" \"$WORKDIR/\"\n",
            "chmod -R u+w \"$WORKDIR\"\n",
            "export HOME=\"$ROOT/home\"\n",
            "export BUF_CACHE_DIR=\"$ROOT/buf-cache\"\n",
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
    runfiles = runfiles.merge(ctx.attr.buf[DefaultInfo].default_runfiles)
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
            mandatory = True,
            providers = [BufModuleInfo],
            doc = "buf_module TreeArtifact.",
        ),
        "buf": attr.label(
            default = Label("@buf//:buf"),
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            doc = "Prebuilt Buf CLI from GitHub releases (override to use another).",
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
