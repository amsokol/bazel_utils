"""Public Go helpers. Load this file from consumers."""

load("//:golangci.bzl", _golangci_test = "golangci_test")
load("//:govulncheck.bzl", _govulncheck_test = "govulncheck_test")

golangci_test = _golangci_test
govulncheck_test = _govulncheck_test
