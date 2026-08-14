"""Workspace-cd wrapper that execs a hermetic tool binary."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//go:go_sdk_env.bzl", "GO_SDK_BASH", "GO_TOOLCHAIN_TYPE", "go_sdk", "go_sdk_runfiles")
load("//internal:runfiles.bzl", "rlocation")
load("//internal:workspace_cd.bzl", "WORKSPACE_BASH")

def _quote_args(args):
    return " ".join([shell.quote(a) for a in args])

def workspace_test_tags(tags, *, requires_network = False):
    """Default tags for workspace-cd tests; `tags` are appended without duplicates.

    Args:
      tags: Extra tags from the caller.
      requires_network: If True, also include `requires-network`.

    Returns:
      Tag list starting with `external`, `no-cache`, `no-sandbox`.
    """
    merged = ["external", "no-cache", "no-sandbox"]
    if requires_network:
        merged.append("requires-network")
    for tag in tags:
        if tag not in merged:
            merged.append(tag)
    return merged

def _go_mod_relpath(ctx, go_mod):
    rel = go_mod.short_path
    if rel.startswith("../") or rel.startswith("/"):
        fail("{}: go_mod must be a file in the consumer workspace, got {}".format(
            ctx.label,
            rel,
        ))
    return rel

def _tool_cmds(ctx, *, find_starlark, require_flags):
    flags = _quote_args(ctx.attr.flags)
    if require_flags and not ctx.attr.flags:
        fail("{}: flags must be non-empty".format(ctx.label))
    if find_starlark:
        return """find . -path './.*' -prune -o -type f \\( \\
    -name '*.bzl' \\
    -o -name '*.bazel' \\
    -o -name BUILD \\
    -o -name '*.BUILD' \\
    -o -name WORKSPACE \\
    -o -name WORKSPACE.bazel \\
    \\) -print0 \\
    | xargs -r -0 "$tool" """ + flags + ' "$@"\n'
    if ctx.attr.also:
        return '"$tool" {first}\nexec "$tool" {second} "$@"\n'.format(
            first = flags,
            second = _quote_args(ctx.attr.also),
        )
    return 'exec "$tool" {flags} "$@"\n'.format(flags = flags)

def _workspace_tool_impl(
        ctx,
        *,
        tool,
        tool_target,
        use_go_sdk,
        pre_exec,
        find_starlark,
        require_flags,
        go_mod = None):
    if not tool:
        fail("{}: {} is not executable".format(ctx.label, tool_target.label))

    ws = ctx.workspace_name
    chunks = [
        "#!/usr/bin/env bash\n",
        "set -euo pipefail\n\n",
        WORKSPACE_BASH,
    ]
    sdk = None
    if use_go_sdk:
        chunks.append(GO_SDK_BASH)
        sdk = go_sdk(ctx)

    chunks.append("tool=$(_rf {})\n".format(shell.quote(rlocation(tool, ws))))
    if sdk:
        chunks.append('_export_goroot "$(_rf {})"\n'.format(
            shell.quote(rlocation(sdk.go, ws)),
        ))
    chunks.append('cd "$(_workspace_dir "$(_rf {})")"\n'.format(
        shell.quote(rlocation(ctx.file.workspace, ws)),
    ))
    if go_mod:
        chunks.append("go_mod={}\n".format(shell.quote(_go_mod_relpath(ctx, go_mod))))
        chunks.append("""\
if [[ ! -f "$go_mod" ]]; then
  echo "go.mod not found: $PWD/$go_mod" >&2
  exit 1
fi
""")
    if pre_exec:
        chunks.append(pre_exec)
        if not pre_exec.endswith("\n"):
            chunks.append("\n")
    chunks.append(_tool_cmds(ctx, find_starlark = find_starlark, require_flags = require_flags))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join(chunks),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [script, tool, ctx.file.workspace])
    runfiles = runfiles.merge(tool_target[DefaultInfo].default_runfiles)
    if sdk:
        runfiles = runfiles.merge(go_sdk_runfiles(ctx, sdk))
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

def workspace_tool_rule(
        *,
        doc,
        tool_attr,
        tool_doc,
        flags_doc,
        tool_default = None,
        use_go_sdk = False,
        use_go_mod = False,
        find_starlark = False,
        require_flags = False,
        executable = False,
        test = True,
        pre_exec = ""):
    """Return a run or test rule that cds to the workspace and execs `tool`.

    `tool_default` is resolved in bazel_utils (Label in this .bzl). `workspace`
    and `go_mod` have no rule default: the calling macro must pass strings so
    they resolve in the consumer repo.

    Args:
      doc: Rule doc.
      tool_attr: Attribute name for the hermetic binary (e.g. "golangci").
      tool_doc: Attribute doc for the binary.
      flags_doc: Attribute doc for `flags`.
      tool_default: Default label string for the binary in this module.
      use_go_sdk: Put the resolved rules_go SDK on PATH.
      use_go_mod: Require `go_mod` and check it exists after cd to the workspace.
      find_starlark: Discover Starlark files with find|xargs (buildifier).
      require_flags: Fail if `flags` is empty (ruff).
      executable: If True, `bazel run` rule.
      test: If True, `bazel test` rule (default).
      pre_exec: Optional bash after `cd`, before the tool (markdownlint env).

    Returns:
      A `rule`.
    """
    if executable == test:
        fail("workspace_tool_rule: set exactly one of executable or test")
    tool_label = dict(
        executable = True,
        cfg = "target",
        doc = tool_doc,
    )
    if tool_default:
        tool_label["default"] = Label(tool_default)
    else:
        tool_label["mandatory"] = True

    attrs = {
        tool_attr: attr.label(**tool_label),
        "flags": attr.string_list(doc = flags_doc),
        "also": attr.string_list(
            doc = "Optional second tool argv after flags (e.g. ruff format --check).",
        ),
        "workspace": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
        ),
    }
    if use_go_mod:
        attrs["go_mod"] = attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer go.mod (workspace-root path; default via macro: //:go.mod).",
        )

    def _impl(ctx):
        return _workspace_tool_impl(
            ctx,
            tool = getattr(ctx.executable, tool_attr),
            tool_target = getattr(ctx.attr, tool_attr),
            use_go_sdk = use_go_sdk,
            pre_exec = pre_exec,
            find_starlark = find_starlark,
            require_flags = require_flags,
            go_mod = ctx.file.go_mod if use_go_mod else None,
        )

    return rule(
        implementation = _impl,
        executable = executable,
        test = test,
        toolchains = [GO_TOOLCHAIN_TYPE] if use_go_sdk else [],
        attrs = attrs,
        doc = doc,
    )
