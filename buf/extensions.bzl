"""buf.toolchains + buf.plugins: fetch the CLI and expose @buf / @buf_plugins."""

load("//:registry.bzl", "cli_platforms", "plugin_spec")

_BUF_URL = "https://github.com/bufbuild/buf/releases/download/{version}/{file}"

_PLATFORMS = [
    "linux_amd64",
    "linux_arm64",
    "darwin_amd64",
    "darwin_arm64",
    "windows_amd64",
    "windows_arm64",
]

def _alias_repo_impl(rctx):
    lines = [
        "package(default_visibility = [\"//visibility:public\"])\n",
    ]
    names = rctx.attr.names
    actuals = rctx.attr.actuals
    if len(names) != len(actuals):
        fail("buf hub: names and actuals must be the same length")
    for i in range(len(names)):
        lines.append("alias(\n    name = \"{}\",\n    actual = \"{}\",\n)\n".format(
            names[i],
            actuals[i],
        ))
    rctx.file("BUILD.bazel", "".join(lines))
    plugin_labels = [
        '    "@buf_plugins//:{}",\n'.format(n)
        for n in names
    ]
    rctx.file("plugins.bzl", "BUF_PLUGIN_LABELS = [\n" + "".join(plugin_labels) + "]\n")
    rctx.file("REPO.bazel", "")

_alias_repo = repository_rule(
    implementation = _alias_repo_impl,
    attrs = {
        "actuals": attr.string_list(),
        "names": attr.string_list(),
    },
)

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

def _declared_plugins(module_ctx):
    """Root-module buf.plugins tags, validated against the registry."""
    seen = {}
    for mod in module_ctx.modules:
        if not mod.is_root:
            continue
        for tag in mod.tags.plugins:
            spec = plugin_spec(tag.name, tag.version)
            prev = seen.get(tag.name)
            if prev and prev != tag.version:
                fail("buf.plugins: {n} declared twice ({a} and {b})".format(
                    a = prev,
                    b = tag.version,
                    n = tag.name,
                ))
            seen[tag.name] = (tag.version, spec)
    return seen

def _buf_impl(module_ctx):
    version = _toolchains_version(module_ctx)
    _buf_cli_repo(
        name = "buf",
        platforms_json = json.encode(cli_platforms(version)),
        version = version,
    )

    names = []
    actuals = []
    for name, (_version, spec) in _declared_plugins(module_ctx).items():
        names.append(name)
        actuals.append(str(Label(spec["target"])))
    _alias_repo(
        name = "buf_plugins",
        names = names,
        actuals = actuals,
    )
    return module_ctx.extension_metadata(reproducible = True)

_toolchain_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
    },
    doc = "Buf CLI GitHub release tag (must exist in registry.bzl CLI).",
)

_plugin_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    doc = "Pin a local codegen plugin to a version in this module's plugin registry.",
)

buf = module_extension(
    implementation = _buf_impl,
    tag_classes = {
        "plugins": _plugin_tag,
        "toolchains": _toolchain_tag,
    },
)
