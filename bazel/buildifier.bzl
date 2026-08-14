"""Workspace buildifier: cd to the consumer repo and recurse with `-r`."""

load("@bazel_utils_core//internal:workspace_tool.bzl", "workspace_test_tags", "workspace_tool_rule")

_buildifier_test = workspace_tool_rule(
    tool_attr = "buildifier",
    tool_default = Label("//:buildifier"),
    tool_doc = "Prebuilt buildifier from GitHub releases (override to use another).",
    flags_doc = "buildifier flags before `-r .`.",
    doc = "bazel test: check Starlark files in the workspace (no-sandbox).",
    test = True,
)

_buildifier_format = workspace_tool_rule(
    tool_attr = "buildifier",
    tool_default = Label("//:buildifier"),
    tool_doc = "Prebuilt buildifier from GitHub releases (override to use another).",
    flags_doc = "buildifier flags before `-r .`.",
    doc = "bazel run: format Starlark files in the workspace.",
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
        local = True,
        **kwargs):
    """Test that runs bazel_utils's buildifier after cd to the consumer workspace.

    The binary is the GitHub release for the exec OS/CPU. Recurses with `-r .`.

    Defaults flags to `-mode=check -lint=warn`. Defaults `local = True` and
    tags `external`, `no-cache`, `no-sandbox`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      tags: Extra test tags; merged with the defaults above.
      flags: buildifier flags before `-r .` (override the defaults above).
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`buildifier`, `size`, …).
    """
    _buildifier_test(
        name = name,
        workspace = workspace,
        tags = workspace_test_tags(tags),
        flags = flags + ["-r", "."],
        local = local,
        **kwargs
    )

def buildifier_format(
        name,
        workspace = "//:MODULE.bazel",
        flags = ["-mode=fix"],
        **kwargs):
    """Run that formats Starlark in the consumer workspace with bazel_utils's buildifier.

    The binary is the GitHub release for the exec OS/CPU. Recurses with `-r .`.
    Defaults flags to `-mode=fix`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      flags: buildifier flags before `-r .` (override the default above).
      **kwargs: Forwarded to the run rule (`buildifier`, …).
    """
    _buildifier_format(
        name = name,
        workspace = workspace,
        flags = flags + ["-r", "."],
        **kwargs
    )
