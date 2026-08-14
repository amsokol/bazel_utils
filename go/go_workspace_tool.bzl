"""workspace_tool_rule with the consumer's rules_go SDK on PATH."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_utils_core//internal:runfiles.bzl", "rlocation")
load("@bazel_utils_core//internal:workspace_tool.bzl", "workspace_tool_rule")
load("//:go_sdk_env.bzl", "GO_SDK_BASH", "GO_TOOLCHAIN_TYPE", "go_sdk", "go_sdk_runfiles")

def _prepare_go_sdk(ctx):
    sdk = go_sdk(ctx)
    chunks = [
        GO_SDK_BASH,
        '_export_goroot "$(_rf {})"\n'.format(
            shell.quote(rlocation(sdk.go, ctx.workspace_name)),
        ),
    ]
    return chunks, go_sdk_runfiles(ctx, sdk)

def go_workspace_tool_rule(**kwargs):
    """Like workspace_tool_rule, plus GOROOT from the resolved Go toolchain."""
    return workspace_tool_rule(
        extra_toolchains = [GO_TOOLCHAIN_TYPE],
        prepare = _prepare_go_sdk,
        **kwargs
    )
