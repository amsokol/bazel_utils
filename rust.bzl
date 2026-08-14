"""Public Rust helpers. Load this file from consumers."""

load("//rust:cargo_audit.bzl", _cargo_audit_test = "cargo_audit_test")

cargo_audit_test = _cargo_audit_test
