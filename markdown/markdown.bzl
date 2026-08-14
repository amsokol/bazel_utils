"""Workspace markdownlint-cli2: cd to the consumer repo and run this module's binary."""

load("//internal:workspace_tool.bzl", "workspace_file_label", "workspace_test_tags", "workspace_tool_rule")

_markdownlint_test = workspace_tool_rule(
    tool_attr = "markdownlint",
    tool_default = "//markdown:markdownlint-cli2",
    tool_doc = "markdownlint-cli2 js_binary from this module's pnpm lock (override to use another).",
    flags_doc = "markdownlint-cli2 arguments after `--config` (empty uses config globs).",
    doc = "bazel test: markdownlint-cli2 against the workspace (no-sandbox).",
    use_config = True,
    config_flag = "--config",
    pre_exec = """\
export BAZEL_BINDIR="${BAZEL_BINDIR:-.}"
export JS_BINARY__CHDIR="$PWD"
""",
)

def markdownlint_test(
        name,
        workspace = "//:MODULE.bazel",
        config = "//:.markdownlint-cli2.yaml",
        tags = [],
        **kwargs):
    """Test that runs bazel_utils's markdownlint-cli2 after cd to the consumer workspace.

    The linter binary is pinned in this module's pnpm lock. Config and globs come
    from the consumer `config` (typically .markdownlint-cli2.yaml).

    Defaults tags to `external`, `no-cache`, `no-sandbox` (workspace-cd, not hermetic inputs).

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      config: Consumer markdownlint-cli2 config (default `//:.markdownlint-cli2.yaml`).
      tags: Extra test tags; merged with the defaults above.
      **kwargs: Forwarded to the test rule (`markdownlint`, `flags`, `size`, `local`, …).
    """
    _markdownlint_test(
        name = name,
        workspace = workspace,
        config = workspace_file_label(config, what = "config"),
        tags = workspace_test_tags(tags),
        **kwargs
    )
