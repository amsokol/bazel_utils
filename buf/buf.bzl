"""Public Buf helpers. Load this file from consumers."""

load("//:format.bzl", _buf_format = "buf_format")
load(
    "//:generate.bzl",
    _buf_deps = "buf_deps",
    _buf_generate = "buf_generate",
    _buf_module = "buf_module",
)
load("//:lint.bzl", _buf_lint_test = "buf_lint_test")
load("//:plugin.bzl", _buf_plugin = "buf_plugin")

buf_deps = _buf_deps
buf_format = _buf_format
buf_generate = _buf_generate
buf_lint_test = _buf_lint_test
buf_module = _buf_module
buf_plugin = _buf_plugin
