"""Public Go helpers. Load this file from consumers."""

load("//go:golangci.bzl", _golangci_test = "golangci_test")
load("//go:govulncheck.bzl", _govulncheck_test = "govulncheck_test")

golangci_test = _golangci_test
govulncheck_test = _govulncheck_test
