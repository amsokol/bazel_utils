"""Workspace golangci-lint: cd to the consumer repo and run this module's binary."""

load("//go:dirs.bzl", "go_list_patterns")
load("//internal:workspace_tool.bzl", "manifest_label", "workspace_file_label", "workspace_test_tags", "workspace_tool_rule")

_golangci_test = workspace_tool_rule(
    tool_attr = "golangci",
    tool_default = "//go:golangci-lint",
    tool_doc = "golangci-lint binary from bazel_utils go.mod (override to use another).",
    flags_doc = "golangci-lint arguments after `run` and before package dirs.",
    doc = "bazel test: golangci-lint against the workspace (no-sandbox).",
    use_go_sdk = True,
    use_manifest = True,
    use_config = True,
    config_flag = "--config",
)

def golangci_test(
        name,
        workspace = "//:MODULE.bazel",
        manifest = "//:go.mod",
        config = "//:.golangci.yaml",
        tags = [],
        dirs = [],
        flags = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's golangci-lint after cd to the consumer workspace.

    The linter binary is pinned in this module's go.mod. `go list` still uses the
    consumer's rules_go SDK so analysis matches the code under test.

    Invokes `golangci-lint --config <config> run <flags> <dirs>` from the workspace root.
    Defaults `local = True` (sandbox has GOPROXY=off) and tags to `external`,
    `no-cache`, `no-sandbox`, `requires-network`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      manifest: Consumer go.mod from repo root (default `//:go.mod`; also `//go/go.mod`).
      config: Consumer golangci config (default `//:.golangci.yaml`).
      tags: Extra test tags; merged with the defaults above.
      dirs: Bazel paths from repo root (e.g. `["//go"]` → `<root>/go/...`).
      flags: Extra golangci-lint flags after `run` and before `dirs`.
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`golangci`, `size`, …).
    """
    _golangci_test(
        name = name,
        workspace = workspace,
        manifest = manifest_label(manifest),
        config = workspace_file_label(config, what = "config"),
        tags = workspace_test_tags(tags, requires_network = True),
        flags = ["run"] + flags + go_list_patterns(dirs),
        local = local,
        **kwargs
    )
