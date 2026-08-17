"""Workspace buildifier: cd to the consumer repo and recurse with `-r`.

The buildifier binary has no `-exclude`. `exclude_patterns` is applied with
`find … ! -path` (same as buildifier-prebuilt / buildtools runner), then the
file list is passed to the binary without `-r`.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "@bazel_utils_core//internal:workspace_tool.bzl",
    "workspace_test_tags",
    "wrapper_script_header",
)

# Same names as buildifier `-r` (`isStarlarkFile` in buildtools v8.5.1).
_STARLARK_FIND = """find . -type f {excludes} \\( \
  -name '*.bzl' -o -name '*.sky' -o -name '*.star' -o -name '*.bazel' \
  -o -name BUILD -o -name WORKSPACE -o -name WORKSPACE.bzlmod \
  -o -name '*.BUILD.oss' -o -name '*.WORKSPACE.oss' \
\\)"""

def _quote_args(args):
    return " ".join([shell.quote(a) for a in args])

def _find_starlark(exclude_patterns):
    """`find` that skips `.git` (as `buildifier -r` does) plus consumer paths."""
    paths = []
    seen = {}
    for p in ["./.git/*"] + list(exclude_patterns):
        if p not in seen:
            seen[p] = True
            paths.append(p)
    excludes = " ".join(["! -path " + shell.quote(p) for p in paths])
    return _STARLARK_FIND.format(excludes = excludes)

def _buildifier_impl(ctx):
    tool = ctx.executable.buildifier
    if not tool:
        fail("{}: {} is not executable".format(ctx.label, ctx.attr.buildifier.label))

    chunks = wrapper_script_header(
        ctx,
        binaries = [["tool", tool]],
        workspace = ctx.file.workspace,
    )
    flags = _quote_args(ctx.attr.flags)
    if ctx.attr.exclude_patterns:
        # `-exec … {} +` does not run the binary when the list is empty
        # (unlike xargs without `-r`, which would hang on stdin).
        chunks.append('{find} -exec "$tool" {flags} "$@" {{}} +\n'.format(
            find = _find_starlark(ctx.attr.exclude_patterns),
            flags = flags,
        ))
    else:
        chunks.append('exec "$tool" {flags} "$@"\n'.format(flags = flags))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join(chunks),
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [script, tool, ctx.file.workspace])
    runfiles = runfiles.merge(ctx.attr.buildifier[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_BUILDIFIER_ATTRS = {
    "buildifier": attr.label(
        executable = True,
        cfg = "exec",
        default = Label("//:buildifier"),
        doc = "Prebuilt buildifier from GitHub releases (override to use another).",
    ),
    "flags": attr.string_list(
        doc = "buildifier argv (without `-r .` when exclude_patterns is set).",
    ),
    "exclude_patterns": attr.string_list(
        doc = "find(1) -path globs to skip, e.g. `./.venv/*`. Empty uses `buildifier -r .`.",
    ),
    "workspace": attr.label(
        mandatory = True,
        allow_single_file = True,
        doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
    ),
}

_buildifier_test = rule(
    implementation = _buildifier_impl,
    test = True,
    attrs = dict(_BUILDIFIER_ATTRS),
    doc = "bazel test: check Starlark files in the workspace (no-sandbox).",
)

_buildifier_format = rule(
    implementation = _buildifier_impl,
    executable = True,
    attrs = dict(_BUILDIFIER_ATTRS),
    doc = "bazel run: format Starlark files in the workspace.",
)

def buildifier_test(
        name,
        workspace = "//:MODULE.bazel",
        tags = [],
        flags = [
            "-mode=check",
            "-lint=warn",
        ],
        exclude_patterns = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's buildifier after cd to the consumer workspace.

    The binary is the GitHub release for the exec OS/CPU. With empty
    `exclude_patterns`, recurses with `-r .`. Otherwise `find … ! -path` collects
    Starlark files (always skips `./.git/*`) and passes them to the binary.

    Defaults flags to `-mode=check -lint=warn`. Defaults `local = True` and
    tags `external`, `no-cache`, `no-sandbox`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      tags: Extra test tags; merged with the defaults above.
      flags: buildifier flags (override the defaults above).
      exclude_patterns: `find -path` globs to skip (e.g. `["./.venv/*"]`).
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`buildifier`, `size`, …).
    """
    rule_flags = list(flags)
    if not exclude_patterns:
        rule_flags = rule_flags + ["-r", "."]
    _buildifier_test(
        name = name,
        workspace = workspace,
        tags = workspace_test_tags(tags),
        flags = rule_flags,
        exclude_patterns = exclude_patterns,
        local = local,
        **kwargs
    )

def buildifier_format(
        name,
        workspace = "//:MODULE.bazel",
        flags = ["-mode=fix"],
        exclude_patterns = [],
        **kwargs):
    """Run that formats the consumer workspace with bazel_utils's buildifier.

    The binary is the GitHub release for the exec OS/CPU. With empty
    `exclude_patterns`, recurses with `-r .`. Otherwise `find … ! -path` collects
    Starlark files (always skips `./.git/*`) and passes them to the binary.
    Defaults flags to `-mode=fix`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      flags: buildifier flags (override the default above).
      exclude_patterns: `find -path` globs to skip (e.g. `["./.venv/*"]`).
      **kwargs: Forwarded to the run rule (`buildifier`, …).
    """
    rule_flags = list(flags)
    if not exclude_patterns:
        rule_flags = rule_flags + ["-r", "."]
    _buildifier_format(
        name = name,
        workspace = workspace,
        flags = rule_flags,
        exclude_patterns = exclude_patterns,
        **kwargs
    )
