"""Workspace govulncheck: cd to the consumer repo and run this module's binary."""

load("//go:dirs.bzl", "go_list_patterns", "go_mod_label")
load("//internal:workspace_tool.bzl", "workspace_test_tags", "workspace_tool_rule")

_govulncheck_test = workspace_tool_rule(
    tool_attr = "govulncheck",
    tool_default = "//go:govulncheck",
    tool_doc = "govulncheck binary from bazel_utils go.mod (override to use another).",
    flags_doc = "govulncheck arguments after the binary and before package dirs.",
    doc = "bazel test: govulncheck against the workspace (no-sandbox, needs vuln.go.dev).",
    use_go_sdk = True,
    use_go_mod = True,
)

def govulncheck_test(
        name,
        workspace = "//:MODULE.bazel",
        go_mod = "//:go.mod",
        tags = [],
        dirs = [],
        flags = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's govulncheck after cd to the consumer workspace.

    The scanner binary is pinned in this module's go.mod. `go list` still uses the
    consumer's rules_go SDK so analysis matches the code under test.

    Invokes `govulncheck <flags> <dirs>` from the workspace root.
    Defaults `local = True` (modules + vuln.go.dev) and tags to `external`,
    `no-cache`, `no-sandbox`, `requires-network`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      go_mod: Consumer go.mod from repo root (default `//:go.mod`; also `//go/go.mod`).
      tags: Extra test tags; merged with the defaults above.
      dirs: Bazel paths from repo root (e.g. `["//go"]` → `<root>/go/...`).
      flags: Extra govulncheck flags before `dirs`.
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`govulncheck`, `size`, …).
    """
    _govulncheck_test(
        name = name,
        workspace = workspace,
        go_mod = go_mod_label(go_mod),
        tags = workspace_test_tags(tags, requires_network = True),
        flags = flags + go_list_patterns(dirs),
        local = local,
        **kwargs
    )
