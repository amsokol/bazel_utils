"""buf.toolchains: fetch the CLI and expose @buf."""

load("//:registry.bzl", "cli_platforms")

_BUF_URL = "https://github.com/bufbuild/buf/releases/download/{version}/{file}"

_PLATFORMS = [
    "linux_amd64",
    "linux_arm64",
    "darwin_amd64",
    "darwin_arm64",
    "windows_amd64",
    "windows_arm64",
]

def _buf_cli_repo_impl(rctx):
    """Download every platform of the requested Buf CLI; BUILD selects exec OS/CPU."""
    platforms = json.decode(rctx.attr.platforms_json)
    files = {}
    for plat in _PLATFORMS:
        spec = platforms[plat]
        dest = "{}/{}".format(plat, "buf.exe" if spec["file"].endswith(".exe") else "buf")
        rctx.download(
            url = _BUF_URL.format(file = spec["file"], version = rctx.attr.version),
            output = dest,
            sha256 = spec["sha256"],
            executable = True,
        )
        files[plat] = dest
    rctx.file("BUILD.bazel", """\
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")

package(default_visibility = ["//visibility:public"])

native_binary(
    name = "buf",
    src = select(
        {{
            "@bazel_utils_core//:linux_amd64": "{linux_amd64}",
            "@bazel_utils_core//:linux_arm64": "{linux_arm64}",
            "@bazel_utils_core//:darwin_amd64": "{darwin_amd64}",
            "@bazel_utils_core//:darwin_arm64": "{darwin_arm64}",
            "@bazel_utils_core//:windows_amd64": "{windows_amd64}",
            "@bazel_utils_core//:windows_arm64": "{windows_arm64}",
        }},
        no_match_error = "No prebuilt buf for this OS/CPU",
    ),
    out = "buf.bin",
)
""".format(**files))
    rctx.file("REPO.bazel", "")

_buf_cli_repo = repository_rule(
    implementation = _buf_cli_repo_impl,
    attrs = {
        "platforms_json": attr.string(),
        "version": attr.string(),
    },
)

def _toolchains_version(module_ctx):
    root = None
    ours = None
    for mod in module_ctx.modules:
        tags = mod.tags.toolchains
        if len(tags) > 1:
            fail("buf.toolchains: at most one tag per module, got {} in {}".format(
                len(tags),
                mod.name,
            ))
        if tags:
            if mod.is_root:
                root = tags[0].version
            elif mod.name == "bazel_utils_buf":
                ours = tags[0].version
    version = root or ours
    if not version:
        fail("buf.toolchains(version) is required")
    return version

def _buf_impl(module_ctx):
    version = _toolchains_version(module_ctx)
    _buf_cli_repo(
        name = "buf",
        platforms_json = json.encode(cli_platforms(version)),
        version = version,
    )
    return module_ctx.extension_metadata(reproducible = True)

_toolchain_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
    },
    doc = "Buf CLI GitHub release tag (must exist in registry.bzl CLI).",
)

buf = module_extension(
    implementation = _buf_impl,
    tag_classes = {
        "toolchains": _toolchain_tag,
    },
)
