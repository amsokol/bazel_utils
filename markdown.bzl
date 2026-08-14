"""Public markdown helpers. Load this file from consumers."""

load("//markdown:markdown.bzl", _markdownlint_test = "markdownlint_test")

markdownlint_test = _markdownlint_test
