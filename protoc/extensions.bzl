"""protoc.plugin: fetch prebuilt local codegen plugins."""

load("//plugins:defs.bzl", "PLUGINS", "plugin_platforms", "plugin_repo_name")

_CONSTRAINTS = {
    "linux_amd64": "@bazel_utils_core//:linux_amd64",
    "linux_arm64": "@bazel_utils_core//:linux_arm64",
    "darwin_amd64": "@bazel_utils_core//:darwin_amd64",
    "darwin_arm64": "@bazel_utils_core//:darwin_arm64",
    "windows_amd64": "@bazel_utils_core//:windows_amd64",
    "windows_arm64": "@bazel_utils_core//:windows_arm64",
}

# Bazel 9.2 ZipReader crashes (ArrayIndexOutOfBoundsException) on zip comments
# such as protobuf-go Windows releases. Host Python zipfile handles those zips.
_ZIP_EXTRACT = """
import pathlib
import shutil
import sys
import zipfile

archive, dest, strip = sys.argv[1], pathlib.Path(sys.argv[2]), sys.argv[3]
dest.mkdir(parents=True, exist_ok=True)
tmp = dest / "_zip_extract"
if tmp.exists():
    shutil.rmtree(tmp)
tmp.mkdir()
with zipfile.ZipFile(archive) as zf:
    zf.extractall(tmp)
root = tmp / strip if strip else tmp
if not root.is_dir():
    raise SystemExit("strip_prefix %r missing in zip" % strip)
for child in root.iterdir():
    shutil.move(str(child), str(dest / child.name))
shutil.rmtree(tmp)
"""

def _plugin_url(plugin, version, spec):
    kwargs = {
        "file": spec["file"],
        "version": version,
    }
    if "{version_bare}" in plugin["url"]:
        kwargs["version_bare"] = version[1:] if version.startswith("v") else version
    return plugin["url"].format(**kwargs)

def _plugin_repo_impl(rctx):
    """Download every platform of the requested plugin; BUILD selects exec OS/CPU."""
    plugin = PLUGINS[rctx.attr.plugin_name]
    platforms = json.decode(rctx.attr.platforms_json)
    files = {}
    for plat, spec in platforms.items():
        if plat not in _CONSTRAINTS:
            fail("protoc.plugin: unknown platform {} for {}".format(plat, rctx.attr.plugin_name))
        url = _plugin_url(plugin, rctx.attr.version, spec)
        dest = "{}/{}".format(plat, spec["bin"])
        if plugin["kind"] == "file":
            rctx.download(
                url = url,
                output = dest,
                sha256 = spec["sha256"],
                executable = True,
            )
        elif plugin["kind"] == "archive":
            strip_prefix = spec.get("strip_prefix", plugin.get("strip_prefix", ""))
            if spec["file"].endswith(".zip"):
                archive = "{}/_plugin.zip".format(plat)
                rctx.download(
                    url = url,
                    output = archive,
                    sha256 = spec["sha256"],
                )
                python = rctx.which("python3")
                if not python:
                    python = rctx.which("python")
                if not python:
                    fail("protoc.plugin: python3 is required to extract zip for {}".format(
                        rctx.attr.plugin_name,
                    ))
                result = rctx.execute([
                    str(python),
                    "-c",
                    _ZIP_EXTRACT,
                    archive,
                    plat,
                    strip_prefix,
                ])
                if result.return_code != 0:
                    fail("protoc.plugin: zip extract failed for {}: {}".format(
                        url,
                        result.stderr or result.stdout,
                    ))
                rctx.delete(archive)
            else:
                rctx.download_and_extract(
                    url = url,
                    output = plat,
                    sha256 = spec["sha256"],
                    stripPrefix = strip_prefix,
                )
        else:
            fail("protoc.plugin: unknown kind {} for {}".format(plugin["kind"], rctx.attr.plugin_name))
        files[plat] = dest

    select_lines = []
    for plat in _CONSTRAINTS:
        path = files.get(plat)
        if path:
            select_lines.append('            "{}": "{}",'.format(_CONSTRAINTS[plat], path))

    rctx.file("BUILD.bazel", """\
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")

package(default_visibility = ["//visibility:public"])

native_binary(
    name = "{name}",
    src = select(
        {{
{select_body}
        }},
        no_match_error = "No prebuilt {name} for this OS/CPU",
    ),
    out = "{name}.bin",
)
""".format(
        name = rctx.attr.plugin_name,
        select_body = "\n".join(select_lines),
    ))
    rctx.file("REPO.bazel", "")

_plugin_repo = repository_rule(
    implementation = _plugin_repo_impl,
    attrs = {
        "platforms_json": attr.string(),
        "plugin_name": attr.string(),
        "version": attr.string(),
    },
)

def _plugin_versions(module_ctx):
    root = {}
    ours = {}
    for mod in module_ctx.modules:
        seen = {}
        for tag in mod.tags.plugin:
            if tag.name in seen:
                fail("protoc.plugin: duplicate name {} in {}".format(tag.name, mod.name))
            if tag.name not in PLUGINS:
                fail("protoc.plugin: unknown plugin {n}; known: {known}".format(
                    known = ", ".join(sorted(PLUGINS.keys())),
                    n = tag.name,
                ))
            seen[tag.name] = True
            if mod.is_root:
                root[tag.name] = tag.version
            elif mod.name == "bazel_utils_protoc":
                ours[tag.name] = tag.version
    versions = dict(ours)
    versions.update(root)
    missing = [name for name in PLUGINS if name not in versions]
    if missing:
        fail("protoc.plugin: version required for {}".format(", ".join(sorted(missing))))
    return versions

def _protoc_impl(module_ctx):
    versions = _plugin_versions(module_ctx)
    for name in sorted(PLUGINS.keys()):
        version = versions[name]
        _plugin_repo(
            name = plugin_repo_name(name),
            plugin_name = name,
            platforms_json = json.encode(plugin_platforms(name, version)),
            version = version,
        )
    return module_ctx.extension_metadata(reproducible = True)

_plugin_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
    doc = "Plugin PATH name and GitHub release tag (must exist in that plugin's registry.bzl).",
)

protoc = module_extension(
    implementation = _protoc_impl,
    tag_classes = {
        "plugin": _plugin_tag,
    },
)
