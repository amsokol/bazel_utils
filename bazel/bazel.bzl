"""Public Bazel/Starlark helpers. Load this file from consumers."""

load("//:buildifier.bzl", _buildifier_format = "buildifier_format", _buildifier_test = "buildifier_test")

buildifier_test = _buildifier_test
buildifier_format = _buildifier_format
