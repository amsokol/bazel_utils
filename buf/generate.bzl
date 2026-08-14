"""Hermetic buf generate and staged buf_module.

Buf CLI is `@buf//:buf` from `buf.toolchains(version)` (cannot use go_binary — bufprivateusage).
Local codegen plugins are Bazel-built executables on PATH. `remote:` plugins and
`buf.yaml` `deps` are fetched from the BSR (needs network).
"""

BufGeneratedInfo = provider(
    doc = "Generated files from buf_generate.",
    fields = {
        "directory": "TreeArtifact directory of generated files.",
    },
)

def _module_directory(ctx):
    """Single TreeArtifact from a buf_module dependency."""
    files = ctx.files.module
    if len(files) != 1:
        fail("{}: module must be a single directory (buf_module), got {}".format(
            ctx.label,
            [f.path for f in files],
        ))
    return files[0]

def _plugin_path_lines(ctx):
    """Write PATH wrappers that exec Bazel-built local plugins."""
    lines = [
        'PLUGIN_BIN="$WORKDIR/plugin_bin"',
        'mkdir -p "$PLUGIN_BIN"',
    ]
    for i, target in enumerate(ctx.attr.plugins):
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
        'export HOME="$WORKDIR/home"',
        'export BUF_CACHE_DIR="$WORKDIR/buf-cache"',
        'mkdir -p "$HOME" "$BUF_CACHE_DIR"',
    ])
    return lines

def _workdir_lines(ctx, buf_bin, module_dir):
    """Copy buf_module into a workdir for the hermetic buf CLI."""
    return [
        "set -euo pipefail",
        'BUF="$(realpath "{}")"'.format(buf_bin.path),
        'WORKDIR="$PWD/{}.work"'.format(ctx.label.name),
        'rm -rf "$WORKDIR"',
        'mkdir -p "$WORKDIR"',
        'cp -a "{}/." "$WORKDIR/"'.format(module_dir.path),
        'chmod -R u+w "$WORKDIR"',
    ]

def _run_buf(ctx, *, module_dir, outputs, extra_inputs, extra_tools, lines, mnemonic, progress_message):
    """Run hermetic `$BUF ...` with a prebuilt buf CLI over a staged module."""
    buf_bin = ctx.executable._buf
    plugin_tools = [
        t[DefaultInfo].files_to_run
        for t in getattr(ctx.attr, "plugins", [])
    ]
    ctx.actions.run_shell(
        outputs = outputs,
        inputs = depset(
            direct = [module_dir] + extra_inputs,
        ),
        tools = [buf_bin] + extra_tools + plugin_tools,
        command = "\n".join(_workdir_lines(ctx, buf_bin, module_dir) + lines),
        mnemonic = mnemonic,
        progress_message = progress_message,
        use_default_shell_env = True,
        execution_requirements = {"requires-network": "1"},
    )

_MODULE_ATTR = attr.label(
    allow_files = True,
    mandatory = True,
    doc = "buf_module TreeArtifact (staged buf.yaml + protos).",
)

_BUF_ATTR = attr.label(
    default = Label("@buf//:buf"),
    executable = True,
    cfg = "exec",
    allow_single_file = True,
)

_PLUGIN_ATTR = attr.label_list(
    cfg = "exec",
    allow_files = True,
    doc = "Local codegen plugins; wrapped onto PATH under their target names. Omit when the template is all remote:.",
)

def _buf_generate_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name)
    outdir = ctx.attr.outdir
    module_dir = _module_directory(ctx)

    if ctx.attr.include_imports or ctx.attr.full_tree:
        generated_rel = outdir
    else:
        proto_dir = ctx.attr.proto_dir
        if not proto_dir:
            fail("{}: proto_dir is required when include_imports/full_tree is False".format(ctx.label))
        generated_rel = "{}/{}".format(outdir, proto_dir)

    path_flags = "".join([' --path "{}"'.format(p) for p in ctx.attr.paths])
    generate = '"$BUF" generate --template buf.gen.yaml{}'.format(path_flags)
    if ctx.attr.include_imports:
        generate += " --include-imports"

    lines = _plugin_path_lines(ctx) + [
        'cp "{}" "$WORKDIR/buf.gen.yaml"'.format(ctx.file.template.path),
        'mkdir -p "{}"'.format(out_dir.path),
        'OUT="$(realpath "{}")"'.format(out_dir.path),
        'cd "$WORKDIR"',
        '"$BUF" dep update',
        generate,
        'if [[ ! -d "{}" ]]; then'.format(generated_rel),
        '  echo "buf_generate: expected \'{}\' was not created" >&2'.format(generated_rel),
        "  exit 1",
        "fi",
        'cp -a "{}/." "$OUT/"'.format(generated_rel),
    ]
    if ctx.attr.ensure_python_init:
        lines.extend([
            'find "$OUT" -type d -print0 | while IFS= read -r -d "" d; do',
            '  if [[ ! -f "$d/__init__.py" ]]; then',
            "    printf '%s\\n' 'from __future__ import annotations' > \"$d/__init__.py\"",
            "  fi",
            "done",
        ])

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

Local plugins (if any) are Bazel-built and put on PATH. `remote:` plugins in
the template are fetched from the BSR (the action requires network).
`buf dep update` resolves `buf.yaml` `deps` into the action workdir.

Returns a directory TreeArtifact and BufGeneratedInfo for write_source_files.

Without include_imports/full_tree: contents of `<outdir>/<proto_dir>/`.
With include_imports or full_tree: full `<outdir>/` tree.
""",
    attrs = {
        "module": _MODULE_ATTR,
        "template": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "buf.gen.yaml template.",
        ),
        "outdir": attr.string(
            mandatory = True,
            doc = "plugins[].out from the template (e.g. \"go\").",
        ),
        "proto_dir": attr.string(
            default = "",
            doc = "Proto package dir inside the module (e.g. \"api/v1\"). Required unless include_imports/full_tree.",
        ),
        "include_imports": attr.bool(
            default = False,
            doc = "Pass --include-imports to buf generate.",
        ),
        "full_tree": attr.bool(
            default = False,
            doc = "Copy the whole outdir tree without --include-imports.",
        ),
        "ensure_python_init": attr.bool(
            default = False,
            doc = "Write missing __init__.py under the generated tree (protoc-gen-py omits them).",
        ),
        "paths": attr.string_list(
            doc = "Repeated `buf generate --path`. Empty = whole module (buf.yaml includes).",
        ),
        "plugins": _PLUGIN_ATTR,
        "_buf": _BUF_ATTR,
    },
)

def _buf_module_impl(ctx):
    """Stage workspace-relative protos and the consumer buf.yaml."""
    out = ctx.actions.declare_directory(ctx.label.name)
    lines = [
        "set -euo pipefail",
        'OUT="{}"'.format(out.path),
        'rm -rf "$OUT"',
        'mkdir -p "$OUT"',
        'cp "{}" "$OUT/buf.yaml"'.format(ctx.file.config.path),
    ]
    for src in ctx.files.srcs:
        lines.append('mkdir -p "$OUT/$(dirname "{}")"'.format(src.short_path))
        lines.append('cp "{}" "$OUT/{}"'.format(src.path, src.short_path))
    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset(direct = [ctx.file.config] + ctx.files.srcs),
        command = "\n".join(lines),
        mnemonic = "BufModule",
        progress_message = "Staging buf module %{label}",
        use_default_shell_env = True,
    )
    return [DefaultInfo(files = depset([out]))]

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
