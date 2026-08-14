"""Workspace pip-audit: audit locked Python runtime deps from the consumer uv.lock."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//internal:runfiles.bzl", "rlocation")
load("//internal:workspace_cd.bzl", "RUNFILES_BASH")
load("//internal:workspace_tool.bzl", "manifest_label", "workspace_test_tags")

def _impl(ctx):
    pip_audit = ctx.executable.pip_audit
    if not pip_audit:
        fail("{}: pip-audit {} is not executable".format(
            ctx.label,
            ctx.attr.pip_audit.label,
        ))
    uv = ctx.file.uv
    if not uv:
        fail("{}: uv {} is missing".format(
            ctx.label,
            ctx.attr.uv.label,
        ))

    ws = ctx.workspace_name
    flags = " ".join([shell.quote(a) for a in ctx.attr.flags])
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join([
            "#!/usr/bin/env bash\n",
            "set -euo pipefail\n\n",
            RUNFILES_BASH,
            "pip_audit=$(_rf {})\n".format(shell.quote(rlocation(pip_audit, ws))),
            "uv=$(_rf {})\n".format(shell.quote(rlocation(uv, ws))),
            "lock=$(_rf {})\n".format(shell.quote(rlocation(ctx.file.lock, ws))),
            'cd "$(dirname "$lock")"\n\n',
            'reqs="$(mktemp)"\n',
            "trap 'rm -f \"$reqs\"' EXIT\n",
            '"$uv" export --frozen --no-dev --no-emit-project --output-file "$reqs"\n',
            # -r is a requirements file from uv; --disable-pip skips the pip resolver.
            'exec "$pip_audit" -r "$reqs" --disable-pip --progress-spinner off {flags} "$@"\n'.format(
                flags = flags,
            ),
        ]),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        script,
        pip_audit,
        uv,
        ctx.file.lock,
        ctx.file.manifest,
    ])
    runfiles = runfiles.merge(ctx.attr.pip_audit[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.uv[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_pip_audit_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "flags": attr.string_list(
            doc = "pip-audit arguments after -r <exported lock> --disable-pip.",
        ),
        "lock": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer uv.lock used by `uv export --frozen`.",
        ),
        "manifest": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer pyproject.toml next to uv.lock (required by uv export).",
        ),
        "pip_audit": attr.label(
            default = Label("//python:pip-audit"),
            executable = True,
            cfg = "target",
            doc = "pip-audit binary from bazel_utils uv.lock (override to use another).",
        ),
        "uv": attr.label(
            default = Label("@uv//:uv"),
            allow_single_file = True,
            cfg = "exec",
            doc = "uv binary from uv_bin.toolchain (export --frozen).",
        ),
    },
    doc = "bazel test: pip-audit against locked runtime deps (no-sandbox, needs OSV).",
)

def pip_audit_test(
        name,
        lock = "//:uv.lock",
        manifest = "//:pyproject.toml",
        tags = [],
        flags = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's pip-audit against the consumer lockfile.

    The scanner binary is pinned in this module's uv.lock. `uv export --frozen`
    still reads the consumer `lock` / `manifest`. Defaults `local = True` and
    tags `external`, `no-cache`, `no-sandbox`, `requires-network`. Always passes
    `--disable-pip` and `--progress-spinner off`.

    Args:
      name: Target name.
      lock: Consumer uv.lock (default `//:uv.lock`).
      manifest: Consumer pyproject.toml next to the lock (default `//:pyproject.toml`).
      tags: Extra test tags; merged with the defaults above.
      flags: Extra pip-audit flags after `-r` and `--disable-pip`.
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`pip_audit`, `size`, …).
    """
    _pip_audit_test(
        name = name,
        lock = lock,
        manifest = manifest_label(manifest),
        tags = workspace_test_tags(tags, requires_network = True),
        flags = flags,
        local = local,
        **kwargs
    )
