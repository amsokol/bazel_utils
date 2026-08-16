"""Hermetic buf generate and staged buf_module.

Buf CLI is `@buf//:buf` from `buf.toolchains(version)` (cannot use go_binary — bufprivateusage).
Consumer `plugins` (`buf_plugin` or any executable) are put on PATH. `remote:`
plugins and `buf.yaml` `deps` are fetched from the BSR (needs network).
"""

BufGeneratedInfo = provider(
    doc = "Generated files from buf_generate.",
    fields = {
        "directory": "TreeArtifact directory of generated files.",
    },
)

BufModuleInfo = provider(
    doc = "Staged buf.yaml + protos from buf_module.",
    fields = {
        "directory": "TreeArtifact (buf.yaml + protos at workspace-relative paths).",
        "srcs": "Proto Files in the consumer workspace (format --path).",
        "config": "Consumer buf.yaml File.",
    },
)

def _workspace_rel(ctx, f, what):
    """short_path of a file that must live in the consumer workspace."""
    rel = f.short_path
    if rel.startswith("../") or rel.startswith("/"):
        fail("{}: {} must be a file in the consumer workspace, got {}".format(
            ctx.label,
            what,
            rel,
        ))
    return rel

def _module_directory(ctx):
    """TreeArtifact from a buf_module dependency."""
    return ctx.attr.module[BufModuleInfo].directory

def _plugin_targets(ctx):
    """Consumer `plugins` (target name is the PATH name)."""
    return list(ctx.attr.plugins)

def _plugin_path_lines(ctx):
    """Write PATH wrappers that exec Bazel-built local plugins.

    Wrappers live in `$PLUGIN_BIN`, which `_workdir_lines` places next to
    (not inside) `$WORKDIR` so `find` during generate does not see them.
    """
    lines = []
    for i, target in enumerate(_plugin_targets(ctx)):
        exe = target[DefaultInfo].files_to_run.executable
        if not exe:
            fail("{}: plugin {} has no executable".format(ctx.label, target.label))
        name = target.label.name
        lines.append('PLUGIN_{}="$(realpath "{}")"'.format(i, exe.path))

        # Quote $@ so it is expanded when buf invokes the wrapper, not when
        # this action writes the wrapper (unquoted EOF would bake in "").
        lines.append("\n".join([
            'cat > "$PLUGIN_BIN/{}" <<EOF'.format(name),
            "#!/usr/bin/env bash",
            'exec "$PLUGIN_{}" "\\$@"'.format(i),
            "EOF",
            'chmod +x "$PLUGIN_BIN/{}"'.format(name),
        ]))
    lines.append('export PATH="$PLUGIN_BIN:$PATH"')
    lines.extend([
        'export HOME="$HOME_DIR"',
        'export BUF_CACHE_DIR="$BUF_CACHE_DIR"',
    ])
    return lines

def _workdir_lines(ctx, buf_bin, module_dir):
    """Copy buf_module into a workdir; cache/home/plugins sit beside it."""
    prefix = ctx.label.name
    return [
        "set -euo pipefail",
        'BUF="$(realpath "{}")"'.format(buf_bin.path),
        'WORKDIR="$PWD/{}.work"'.format(prefix),
        'PLUGIN_BIN="$PWD/{}.plugin_bin"'.format(prefix),
        'HOME_DIR="$PWD/{}.home"'.format(prefix),
        'BUF_CACHE_DIR="$PWD/{}.buf-cache"'.format(prefix),
        'rm -rf "$WORKDIR" "$PLUGIN_BIN" "$HOME_DIR" "$BUF_CACHE_DIR"',
        'mkdir -p "$WORKDIR" "$PLUGIN_BIN" "$HOME_DIR" "$BUF_CACHE_DIR"',
        'cp -a "{}/." "$WORKDIR/"'.format(module_dir.path),
        'chmod -R u+w "$WORKDIR"',
    ]

def _run_buf(ctx, *, module_dir, outputs, extra_inputs, extra_tools, lines, mnemonic, progress_message):
    """Run hermetic `$BUF ...` with a prebuilt buf CLI over a staged module."""
    buf_bin = ctx.executable.buf
    plugin_tools = [
        t[DefaultInfo].files_to_run
        for t in _plugin_targets(ctx)
    ]
    env = {}
    token = ctx.configuration.default_shell_env.get("BUF_TOKEN")
    if token:
        env["BUF_TOKEN"] = token
    ctx.actions.run_shell(
        outputs = outputs,
        inputs = depset(
            direct = [module_dir] + extra_inputs,
        ),
        tools = [buf_bin] + extra_tools + plugin_tools,
        command = "\n".join(_workdir_lines(ctx, buf_bin, module_dir) + lines),
        mnemonic = mnemonic,
        progress_message = progress_message,
        env = env,
        use_default_shell_env = True,
        execution_requirements = {"requires-network": "1"},
    )

_MODULE_ATTR = attr.label(
    mandatory = True,
    providers = [BufModuleInfo],
    doc = "buf_module (staged buf.yaml + protos).",
)

_BUF_ATTR = attr.label(
    default = Label("@buf//:buf"),
    executable = True,
    cfg = "exec",
    allow_single_file = True,
    doc = "Prebuilt Buf CLI from GitHub releases (override to use another).",
)

def _copy_generated_lines():
    """Run buf generate and copy the files it wrote (common parent of new files)."""
    return [
        "find . -type f -print | sort > \"$WORKDIR.before_files\"",
        '"$BUF" generate --template buf.gen.yaml',
        "find . -type f -print | sort > \"$WORKDIR.after_files\"",
        "comm -13 \"$WORKDIR.before_files\" \"$WORKDIR.after_files\" > \"$WORKDIR.new_files\"",
        'if [[ ! -s "$WORKDIR.new_files" ]]; then',
        '  echo "buf_generate: buf generate wrote no files" >&2',
        "  exit 1",
        "fi",
        "COMMON=",
        "while IFS= read -r f; do",
        '  d=$(dirname "$f")',
        '  if [[ -z "$COMMON" ]]; then',
        '    COMMON="$d"',
        "  else",
        '    while [[ "$d" != "$COMMON" && "$d" != "$COMMON"/* ]]; do',
        '      if [[ "$COMMON" == "." ]]; then',
        '        echo "buf_generate: generated files do not share a directory" >&2',
        "        exit 1",
        "      fi",
        '      COMMON=$(dirname "$COMMON")',
        "    done",
        "  fi",
        'done < "$WORKDIR.new_files"',
        'if [[ -z "$COMMON" || "$COMMON" == "." ]]; then',
        '  echo "buf_generate: generated files do not share a directory" >&2',
        "  exit 1",
        "fi",
        'cp -a "$COMMON/." "$OUT/"',
    ]

def _buf_generate_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)
    module_dir = _module_directory(ctx)

    lines = _plugin_path_lines(ctx) + [
        'cp "{}" "$WORKDIR/buf.gen.yaml"'.format(ctx.file.template.path),
        'mkdir -p "{}"'.format(out_dir.path),
        'OUT="$(realpath "{}")"'.format(out_dir.path),
        'cd "$WORKDIR"',
        '"$BUF" dep update',
    ] + _copy_generated_lines()

    _run_buf(
        ctx,
        module_dir = module_dir,
        outputs = [out_dir],
        extra_inputs = [ctx.file.template],
        extra_tools = [],
        lines = lines,
        mnemonic = "BufGenerate",
        progress_message = "Generating %{label} with buf",
    )
    return [
        DefaultInfo(files = depset([out_dir])),
        BufGeneratedInfo(directory = out_dir),
    ]

buf_generate = rule(
    implementation = _buf_generate_impl,
    doc = """`buf generate` over a buf_module.

`plugins` (typically `buf_plugin`) are put on PATH. Target name is the
PATH name (`local:` in the template). `remote:` plugins in the template
are fetched from the BSR (the action requires network). `buf dep update`
resolves `buf.yaml` `deps` into the action workdir.

The template is passed to `buf generate --template` as-is (`out`,
`include_imports`, `include_wkt`, `inputs`). This rule does not parse it.
Generated files must share a single directory (one TreeArtifact); use a
separate `buf_generate` per template when `out` paths are unrelated.

Cache, HOME, and plugin PATH wrappers sit beside the workdir so they are
not copied into the output.

BSR fetches (`buf dep update`, `remote:` plugins) need `BUF_TOKEN` in the
action env: `build --action_env=BUF_TOKEN` (sandbox does not inherit the
user shell).

Returns a directory TreeArtifact of the files buf wrote and BufGeneratedInfo
for write_source_files.
""",
    attrs = {
        "module": _MODULE_ATTR,
        "template": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "buf.gen.yaml passed to `buf generate --template`.",
        ),
        "plugins": attr.label_list(
            cfg = "exec",
            allow_files = True,
            doc = "Consumer-built local plugins. Target name is the PATH name (`local:` in the template). Wrap with buf_plugin when the binary name differs.",
        ),
        "buf": _BUF_ATTR,
    },
)

def _buf_module_impl(ctx):
    """Stage workspace-relative protos and the consumer buf.yaml."""
    _workspace_rel(ctx, ctx.file.config, "buf.yaml")
    out = ctx.actions.declare_directory(ctx.label.name)
    lines = [
        "set -euo pipefail",
        'OUT="{}"'.format(out.path),
        'rm -rf "$OUT"',
        'mkdir -p "$OUT"',
        'cp "{}" "$OUT/buf.yaml"'.format(ctx.file.config.path),
    ]
    for src in ctx.files.srcs:
        rel = _workspace_rel(ctx, src, "proto")
        lines.append('mkdir -p "$OUT/$(dirname "{}")"'.format(rel))
        lines.append('cp "{}" "$OUT/{}"'.format(src.path, rel))
    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(direct = [ctx.file.config] + ctx.files.srcs),
        command = "\n".join(lines),
        mnemonic = "BufModule",
        progress_message = "Staging buf module %{label}",
        use_default_shell_env = True,
    )
    return [
        DefaultInfo(files = depset([out])),
        BufModuleInfo(
            directory = out,
            srcs = ctx.files.srcs,
            config = ctx.file.config,
        ),
    ]

_buf_module = rule(
    implementation = _buf_module_impl,
    doc = """Directory with staged buf.yaml and protos at workspace-relative paths.

`config` is copied as-is (BSR `deps` stay remote). Fetch happens in generate/lint.
""",
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".proto"],
            mandatory = True,
            doc = "Protobuf sources (paths preserved under the module root).",
        ),
        "config": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Consumer buf.yaml.",
        ),
    },
)

def buf_module(name, srcs, config = "//:buf.yaml", **kwargs):
    """Stage protos plus the consumer buf.yaml (default `//:buf.yaml`)."""
    _buf_module(
        name = name,
        srcs = srcs,
        config = config,
        **kwargs
    )

# Re-export for lint.bzl (same TreeArtifact helper).
module_directory = _module_directory
