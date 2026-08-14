"""Workspace buf format: rewrite the module's proto files in the checkout."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "@bazel_utils_core//internal:workspace_tool.bzl",
    "append_workspace_file",
    "wrapper_script_header",
)
load("//:generate.bzl", "BufModuleInfo")

def _buf_format_impl(ctx):
    """bazel run: format the module's proto files in the consumer checkout."""
    buf_bin = ctx.executable.buf
    if not buf_bin:
        fail("{}: buf is not executable".format(ctx.label))
    info = ctx.attr.module[BufModuleInfo]
    if not info.srcs:
        fail("{}: module {} has no proto srcs".format(ctx.label, ctx.attr.module.label))

    chunks = wrapper_script_header(
        ctx,
        binaries = [["buf", buf_bin]],
        workspace = ctx.file.workspace,
    )
    append_workspace_file(chunks, ctx, info.config, "config", "buf.yaml")
    argv = ["format", "-w", "--config", '"$config"']
    for src in info.srcs:
        rel = src.short_path
        argv.extend(["--path", shell.quote(rel)])
        chunks.append("""\
if [[ ! -f {q} ]]; then
  echo "proto not found: $PWD/{rel}" >&2
  exit 1
fi
""".format(q = shell.quote(rel), rel = rel))
    argv.extend([shell.quote(a) for a in ctx.attr.flags])
    chunks.append('exec "$buf" {}\n'.format(" ".join(argv)))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join(chunks),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [script, buf_bin, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.buf[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_buf_format = rule(
    implementation = _buf_format_impl,
    executable = True,
    doc = """bazel run: buf format -w on the module's proto files in the checkout.

Uses that module's buf.yaml (`--config`) and `--path` for each proto. Does not
format a copy — writes the consumer workspace after cd.
""",
    attrs = {
        "module": attr.label(
            mandatory = True,
            providers = [BufModuleInfo],
            doc = "buf_module whose proto srcs are formatted in-place.",
        ),
        "workspace": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
        ),
        "flags": attr.string_list(
            doc = "Extra argv after `format -w --config --path …`.",
        ),
        "buf": attr.label(
            default = Label("@buf//:buf"),
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            doc = "Prebuilt Buf CLI from GitHub releases (override to use another).",
        ),
    },
)

def buf_format(
        name,
        module,
        workspace = "//:MODULE.bazel",
        flags = [],
        **kwargs):
    """Run that formats the module's protobuf files in the consumer workspace.

    `bazel run`: `cd` to the checkout, then `buf format -w` with `--path` for
    each proto in `module` and `--config` from that module's buf.yaml.

    Args:
      name: Target name.
      module: `buf_module` target.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      flags: Extra argv after `format -w --config --path …`.
      **kwargs: Forwarded to the run rule (`buf`, …).
    """
    _buf_format(
        name = name,
        module = module,
        workspace = workspace,
        flags = flags,
        **kwargs
    )
