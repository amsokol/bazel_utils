"""Public markdown helpers. Load this file from consumers."""

load("//:markdownlint.bzl", _markdownlint_test = "markdownlint_test")

markdownlint_test = _markdownlint_test
