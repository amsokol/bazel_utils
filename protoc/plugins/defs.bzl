"""Index of prebuilt local codegen plugins.

Each plugin keeps its GitHub-release catalog in `plugins/<name>/registry.bzl`.
This file only merges those catalogs for `protoc.plugin`.
"""

load("//plugins/protoc-gen-buffa:registry.bzl", _buffa = "PLUGIN")
load("//plugins/protoc-gen-buffa-packaging:registry.bzl", _packaging = "PLUGIN")
load("//plugins/protoc-gen-connect-go:registry.bzl", _connect_go = "PLUGIN")
load("//plugins/protoc-gen-connect-rust:registry.bzl", _connect_rust = "PLUGIN")
load("//plugins/protoc-gen-go:registry.bzl", _go = "PLUGIN")
load("//plugins/protoc-gen-grpc-gateway:registry.bzl", _grpc_gateway = "PLUGIN")
load("//plugins/protoc-gen-openapiv2:registry.bzl", _openapiv2 = "PLUGIN")
load("//plugins/protoc-gen-protovalidate-buffa:registry.bzl", _protovalidate = "PLUGIN")

PLUGINS = {
    _buffa["name"]: _buffa,
    _connect_go["name"]: _connect_go,
    _connect_rust["name"]: _connect_rust,
    _go["name"]: _go,
    _grpc_gateway["name"]: _grpc_gateway,
    _openapiv2["name"]: _openapiv2,
    _packaging["name"]: _packaging,
    _protovalidate["name"]: _protovalidate,
}

def plugin_platforms(name, version):
    """Return the platform map for a plugin version, or fail.

    Args:
      name: Plugin PATH name (`protoc-gen-buffa-packaging`, …).
      version: Release tag in that plugin's catalog (e.g. `v0.9.2`).

    Returns:
      Dict of platform name to `{file, sha256, bin}`.
    """
    plugin = PLUGINS.get(name)
    if not plugin:
        fail("protoc.plugin: unknown plugin {n}; known: {known}".format(
            known = ", ".join(sorted(PLUGINS.keys())),
            n = name,
        ))
    platforms = plugin["versions"].get(version)
    if not platforms:
        fail("protoc.plugin: unknown version {v} for {n}; known: {known}".format(
            known = ", ".join(sorted(plugin["versions"].keys())),
            n = name,
            v = version,
        ))
    return platforms

def plugin_repo_name(name):
    """Bazel repository name for a plugin (`protoc-gen-foo` → `protoc_gen_foo`).

    Args:
      name: Plugin PATH name.

    Returns:
      Repository name used by the module extension.
    """
    return name.replace("-", "_")
