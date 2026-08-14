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

def workspace_file_label(label, what = "file"):
    """Normalize a file path to a file label (`//pkg/file` → `//pkg:file`).

    Macros pass the result as a string so it resolves in the consumer.

    Args:
      label: `//:file`, `//pkg:file`, or `//pkg/file`.
      what: Name used in error messages (`manifest`, `config`, …).

    Returns:
      A Bazel file label.
    """
    if label.startswith("@") or label.startswith(":"):
        fail("{} must be an absolute label in the consumer workspace, got {}".format(
            what,
            label,
        ))
    if not label.startswith("//"):
        fail("{} must be an absolute Bazel label, got {}".format(what, label))
    rest = label[2:]
    if ":" in rest:
        return label
    if "/" not in rest:
        return "//:" + rest
    pkg, _, name = rest.rpartition("/")
    if not name:
        fail("{} must be a file, got {}".format(what, label))
    return "//{}:{}".format(pkg, name)

def manifest_label(manifest):
    """Normalize a manifest path (`//go/go.mod` → `//go:go.mod`)."""
    return workspace_file_label(manifest, what = "manifest")

def _workspace_relpath(ctx, f, what):
    rel = f.short_path
    if rel.startswith("../") or rel.startswith("/"):
        fail("{}: {} must be a file in the consumer workspace, got {}".format(
            ctx.label,
            what,
            rel,
        ))
    return rel

def _append_workspace_file(chunks, ctx, f, var, what):
    chunks.append("{}={}\n".format(var, shell.quote(_workspace_relpath(ctx, f, what))))
    chunks.append("""\
if [[ ! -f "${var}" ]]; then
  echo "{what} not found: $PWD/${var}" >&2
  exit 1
fi
""".format(var = var, what = what))

def _tool_cmds(ctx, *, find_starlark, require_flags, manifest_flag, config_flag):
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
    if find_starlark:
        return """find . -path './.*' -prune -o -type f \\( \\
    -name '*.bzl' \\
    -o -name '*.bazel' \\
    -o -name BUILD \\
    -o -name '*.BUILD' \\
    -o -name WORKSPACE \\
    -o -name WORKSPACE.bazel \\
    \\) -print0 \\
    | xargs -r -0 """ + tool + " " + flags + ' "$@"\n'
    if ctx.attr.also:
        return "{tool} {first}\nexec {tool} {second} \"$@\"\n".format(
            tool = tool,
            first = flags,
            second = _quote_args(ctx.attr.also),
        )
    return 'exec {tool} {flags} "$@"\n'.format(tool = tool, flags = flags)

def _workspace_tool_impl(
        ctx,
        *,
        tool,
        tool_target,
        use_go_sdk,
        pre_exec,
        find_starlark,
        require_flags,
        manifest_flag,
        config_flag,
        manifest = None,
        config = None):
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
    if manifest:
        _append_workspace_file(chunks, ctx, manifest, "manifest", "manifest")
    if config:
        _append_workspace_file(chunks, ctx, config, "config", "config")
    if pre_exec:
        chunks.append(pre_exec)
        if not pre_exec.endswith("\n"):
            chunks.append("\n")
    chunks.append(_tool_cmds(
        ctx,
        find_starlark = find_starlark,
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
        use_manifest = False,
        manifest_flag = "",
        use_config = False,
        config_flag = "",
        find_starlark = False,
        require_flags = False,
        executable = False,
        test = True,
        pre_exec = ""):
    """Return a run or test rule that cds to the workspace and execs `tool`.

    `tool_default` is resolved in bazel_utils (Label in this .bzl). `workspace`,
    `manifest`, and `config` have no rule default: the calling macro must pass
    strings so they resolve in the consumer repo.

    Args:
      doc: Rule doc.
      tool_attr: Attribute name for the hermetic binary (e.g. "golangci").
      tool_doc: Attribute doc for the binary.
      flags_doc: Attribute doc for `flags`.
      tool_default: Default label string for the binary in this module.
      use_go_sdk: Put the resolved rules_go SDK on PATH.
      use_manifest: Require `manifest` and check it exists after cd to the workspace.
      manifest_flag: If set, pass this flag and `$manifest` before the tool argv
        (e.g. ruff `--config`).
      use_config: Require `config` and check it exists after cd to the workspace.
      config_flag: If set, pass this flag and `$config` before the tool argv
        (e.g. golangci `--config`).
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
    if manifest_flag and not use_manifest:
        fail("workspace_tool_rule: manifest_flag requires use_manifest")
    if config_flag and not use_config:
        fail("workspace_tool_rule: config_flag requires use_config")
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
        return _workspace_tool_impl(
            ctx,
            tool = getattr(ctx.executable, tool_attr),
            tool_target = getattr(ctx.attr, tool_attr),
            use_go_sdk = use_go_sdk,
            pre_exec = pre_exec,
            find_starlark = find_starlark,
            require_flags = require_flags,
            manifest_flag = manifest_flag,
            config_flag = config_flag,
            manifest = ctx.file.manifest if use_manifest else None,
            config = ctx.file.config if use_config else None,
        )

    return rule(
        implementation = _impl,
        executable = executable,
        test = test,
        toolchains = [GO_TOOLCHAIN_TYPE] if use_go_sdk else [],
        attrs = attrs,
        doc = doc,
    )
