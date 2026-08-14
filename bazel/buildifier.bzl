"""Workspace buildifier: cd to the consumer repo, skip hidden dirs."""

load("//internal:workspace_tool.bzl", "workspace_test_tags", "workspace_tool_rule")

_buildifier_test = workspace_tool_rule(
    tool_attr = "buildifier",
    tool_default = "//bazel:buildifier",
    tool_doc = "buildifier binary from bazel_utils go.mod (override to use another).",
    flags_doc = "buildifier flags before discovered Starlark files.",
    doc = "bazel test: check Starlark files in the workspace (no-sandbox).",
    find_starlark = True,
    test = True,
)

_buildifier_format = workspace_tool_rule(
    tool_attr = "buildifier",
    tool_default = "//bazel:buildifier",
    tool_doc = "buildifier binary from bazel_utils go.mod (override to use another).",
    flags_doc = "buildifier flags before discovered Starlark files.",
    doc = "bazel run: format Starlark files in the workspace.",
    find_starlark = True,
    executable = True,
    test = False,
)

def buildifier_test(
        name,
        workspace = "//:MODULE.bazel",
        tags = [],
        flags = [
            "-mode=check",
            "-lint=warn",
        ],
        **kwargs):
    """Test that runs bazel_utils's buildifier after cd to the consumer workspace.

    The binary is pinned in this module's go.mod. Discovers `*.bzl` / `*.bazel` /
    BUILD / WORKSPACE files, skipping hidden directories.

    Defaults flags to `-mode=check -lint=warn`. Defaults tags to `external`,
    `no-cache`, `no-sandbox`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      tags: Extra test tags; merged with the defaults above.
      flags: buildifier flags (override the defaults above).
      **kwargs: Forwarded to the test rule (`buildifier`, `size`, `local`, …).
    """
    _buildifier_test(
        name = name,
        workspace = workspace,
        tags = workspace_test_tags(tags),
        flags = flags,
        **kwargs
    )

def buildifier_format(
        name,
        workspace = "//:MODULE.bazel",
        flags = ["-mode=fix"],
        **kwargs):
    """Run that formats Starlark in the consumer workspace with bazel_utils's buildifier.

    The binary is pinned in this module's go.mod. Discovers the same files as
    `buildifier_test`. Defaults flags to `-mode=fix`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      flags: buildifier flags (override the default above).
      **kwargs: Forwarded to the run rule (`buildifier`, …).
    """
    _buildifier_format(
        name = name,
        workspace = workspace,
        flags = flags,
        **kwargs
    )
