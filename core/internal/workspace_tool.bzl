"""Workspace-cd wrapper that execs a hermetic tool binary."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//internal:labels.bzl", _lock_label = "lock_label", _manifest_label = "manifest_label", _workspace_file_label = "workspace_file_label", _workspace_rel_dir = "workspace_rel_dir")
load("//internal:runfiles.bzl", "rlocation")
load("//internal:workspace_cd.bzl", "WORKSPACE_BASH")

lock_label = _lock_label
manifest_label = _manifest_label
workspace_file_label = _workspace_file_label
workspace_rel_dir = _workspace_rel_dir

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

def wrapper_script_header(ctx, *, binaries, workspace):
    """Shebang, runfiles helper, `$var` assignments, and cd to the workspace.

    Args:
      ctx: Rule context.
      binaries: List of `[var, File]` pairs to resolve via `_rf`.
      workspace: Marker File for `_workspace_dir`.

    Returns:
      A list of script chunks.
    """
    ws = ctx.workspace_name
    chunks = [
        "#!/usr/bin/env bash\n",
        "set -euo pipefail\n\n",
        WORKSPACE_BASH,
    ]
    for item in binaries:
        chunks.append("{}=$(_rf {})\n".format(item[0], shell.quote(rlocation(item[1], ws))))
    chunks.append('cd "$(_workspace_dir "$(_rf {})")"\n'.format(
        shell.quote(rlocation(workspace, ws)),
    ))
    return chunks

def append_workspace_file(chunks, ctx, f, var, what):
    """After cd to the workspace, set `$var` to the source-relative path of `f`.

    Args:
      chunks: Script chunks to append to.
      ctx: Rule context (label used in errors).
      f: Consumer-workspace File.
      var: Bash variable name.
      what: Name used in error messages (`lock`, `manifest`, …).
    """
    rel = f.short_path
    if rel.startswith("../") or rel.startswith("/"):
        fail("{}: {} must be a file in the consumer workspace, got {}".format(
            ctx.label,
            what,
            rel,
        ))
    chunks.append("{}={}\n".format(var, shell.quote(rel)))
    chunks.append("""\
if [[ ! -f "${var}" ]]; then
  echo "{what} not found: $PWD/${var}" >&2
  exit 1
fi
""".format(var = var, what = what))

def _tool_cmds(ctx, *, require_flags, manifest_flag, config_flag):
    flags = _quote_args(ctx.attr.flags)
    if require_flags and not ctx.attr.flags:
        fail("{}: flags must be non-empty".format(ctx.label))
    extra = []
    if manifest_flag:
        extra.extend([shell.quote(manifest_flag), '"$manifest"'])
    if config_flag:
        extra.extend([shell.quote(config_flag), '"$config"'])
    tool = '"$tool"'
    if extra:
        tool = '"$tool" ' + " ".join(extra)
    if ctx.attr.also:
        return """\
rc=0
{tool} {first} || rc=$?
{tool} {second} "$@" || rc=$?
exit "$rc"
""".format(
            tool = tool,
            first = flags,
            second = _quote_args(ctx.attr.also),
        )
    return 'exec {tool} {flags} "$@"\n'.format(tool = tool, flags = flags)

def workspace_tool_impl(
        ctx,
        *,
        tool,
        tool_target,
        pre_exec,
        require_flags,
        manifest_flag,
        config_flag,
        extra_chunks = [],
        extra_runfiles = None,
        manifest = None,
        config = None):
    """Write the workspace-cd wrapper script and return DefaultInfo.

    Args:
      ctx: Rule context.
      tool: Executable File for the hermetic binary.
      tool_target: Target that provides the binary's DefaultInfo/runfiles.
      pre_exec: Optional bash after `cd`, before the tool.
      require_flags: Fail if `flags` is empty.
      manifest_flag: If set, pass this flag and `$manifest` before the tool argv.
      config_flag: If set, pass this flag and `$config` before the tool argv.
      extra_chunks: Extra bash after the header (e.g. Go SDK exports).
      extra_runfiles: Optional runfiles to merge (e.g. Go SDK files).
      manifest: Optional consumer-workspace File for `$manifest`.
      config: Optional consumer-workspace File for `$config`.

    Returns:
      A list containing DefaultInfo for the wrapper script.
    """
    if not tool:
        fail("{}: {} is not executable".format(ctx.label, tool_target.label))

    chunks = wrapper_script_header(
        ctx,
        binaries = [["tool", tool]],
        workspace = ctx.file.workspace,
    )
    for c in extra_chunks:
        chunks.append(c)
        if not c.endswith("\n"):
            chunks.append("\n")
    if manifest:
        append_workspace_file(chunks, ctx, manifest, "manifest", "manifest")
    if config:
        append_workspace_file(chunks, ctx, config, "config", "config")
    if pre_exec:
        chunks.append(pre_exec)
        if not pre_exec.endswith("\n"):
            chunks.append("\n")
    chunks.append(_tool_cmds(
        ctx,
        require_flags = require_flags,
        manifest_flag = manifest_flag,
        config_flag = config_flag,
    ))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join(chunks),
        is_executable = True,
    )

    runfiles_files = [script, tool, ctx.file.workspace]
    if manifest:
        runfiles_files.append(manifest)
    if config:
        runfiles_files.append(config)
    runfiles = ctx.runfiles(files = runfiles_files)
    runfiles = runfiles.merge(tool_target[DefaultInfo].default_runfiles)
    if extra_runfiles:
        runfiles = runfiles.merge(extra_runfiles)
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
        use_manifest = False,
        manifest_flag = "",
        use_config = False,
        config_flag = "",
        require_flags = False,
        executable = False,
        test = True,
        pre_exec = "",
        extra_toolchains = [],
        prepare = None):
    """Return a run or test rule that cds to the workspace and execs `tool`.

    `tool_default` must be a `Label()` constructed in the calling `.bzl` file
    (a string would resolve in this module). `workspace`, `manifest`, and
    `config` have no rule default: the calling macro must pass strings so they
    resolve in the consumer repo.

    Args:
      doc: Rule doc.
      tool_attr: Attribute name for the hermetic binary (e.g. "golangci").
      tool_doc: Attribute doc for the binary.
      flags_doc: Attribute doc for `flags`.
      tool_default: Default tool `Label()` from the calling `.bzl` (not a string).
      use_manifest: Require `manifest` and check it exists after cd to the workspace.
      manifest_flag: If set, pass this flag and `$manifest` before the tool argv
        (e.g. ruff `--config`).
      use_config: Require `config` and check it exists after cd to the workspace.
      config_flag: If set, pass this flag and `$config` before the tool argv
        (e.g. golangci `--config`).
      require_flags: Fail if `flags` is empty (ruff).
      executable: If True, `bazel run` rule.
      test: If True, `bazel test` rule (default).
      pre_exec: Optional bash after `cd`, before the tool (markdownlint env).
      extra_toolchains: Extra toolchain types (e.g. Go SDK).
      prepare: Optional `ctx -> (extra_chunks, extra_runfiles)` after header.

    Returns:
      A `rule`.
    """
    if executable == test:
        fail("workspace_tool_rule: set exactly one of executable or test")
    if extra_toolchains:
        for t in extra_toolchains:
            if type(t) != "Label":
                fail("workspace_tool_rule: extra_toolchains items must be Label() in the calling .bzl, got {}".format(type(t)))
    if manifest_flag and not use_manifest:
        fail("workspace_tool_rule: manifest_flag requires use_manifest")
    if config_flag and not use_config:
        fail("workspace_tool_rule: config_flag requires use_config")
    tool_label = dict(
        executable = True,
        cfg = "exec",
        doc = tool_doc,
    )
    if tool_default:
        if type(tool_default) != "Label":
            fail("workspace_tool_rule: tool_default must be Label() in the calling .bzl, got {}".format(type(tool_default)))
        tool_label["default"] = tool_default
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
    if use_manifest:
        attrs["manifest"] = attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer manifest (go.mod, pyproject.toml, …); default via the macro.",
        )
    if use_config:
        attrs["config"] = attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer linter config; default via the macro.",
        )

    def _impl(ctx):
        extra_chunks = []
        extra_runfiles = None
        if prepare:
            extra_chunks, extra_runfiles = prepare(ctx)
        return workspace_tool_impl(
            ctx,
            tool = getattr(ctx.executable, tool_attr),
            tool_target = getattr(ctx.attr, tool_attr),
            pre_exec = pre_exec,
            require_flags = require_flags,
            manifest_flag = manifest_flag,
            config_flag = config_flag,
            extra_chunks = extra_chunks,
            extra_runfiles = extra_runfiles,
            manifest = ctx.file.manifest if use_manifest else None,
            config = ctx.file.config if use_config else None,
        )

    return rule(
        implementation = _impl,
        executable = executable,
        test = test,
        toolchains = extra_toolchains,
        attrs = attrs,
        doc = doc,
    )
