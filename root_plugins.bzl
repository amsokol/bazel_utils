"""Aggregator check: this workspace has no `protoc.plugin` tags."""

load("@protoc_root_plugins//:plugins.bzl", "ROOT_PLUGIN_LABELS")

def assert_empty_root_plugin_labels():
    """Fail if catalog fallbacks leaked into ROOT_PLUGIN_LABELS."""
    if len(ROOT_PLUGIN_LABELS) != 0:
        fail("protoc_root_plugins leaked non-root tags: {}".format(ROOT_PLUGIN_LABELS))
