"""Workspace cargo-audit: audit locked crates from the consumer Cargo.lock."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//internal:runfiles.bzl", "rlocation")
load("//internal:workspace_cd.bzl", "RUNFILES_BASH")
load("//internal:workspace_tool.bzl", "manifest_label", "workspace_test_tags")

def _impl(ctx):
    cargo_audit = ctx.executable.cargo_audit
    if not cargo_audit:
        fail("{}: cargo-audit {} is not executable".format(
            ctx.label,
            ctx.attr.cargo_audit.label,
        ))
    cargo = None
    for f in ctx.files.cargo:
        if f.basename in ("cargo", "cargo.exe"):
            cargo = f
            break
    if not cargo:
        fail("{}: {} has no cargo binary".format(ctx.label, ctx.attr.cargo.label))

    ws = ctx.workspace_name
    flags = " ".join([shell.quote(a) for a in ctx.attr.flags])
    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join([
            "#!/usr/bin/env bash\n",
            "set -euo pipefail\n\n",
            RUNFILES_BASH,
            "cargo_audit=$(_rf {})\n".format(shell.quote(rlocation(cargo_audit, ws))),
            "cargo=$(_rf {})\n".format(shell.quote(rlocation(cargo, ws))),
            "lock=$(_rf {})\n".format(shell.quote(rlocation(ctx.file.lock, ws))),
            'cd "$(dirname "$lock")"\n\n',
            "# tame-index runs `$CARGO -V` (else `cargo`) to pick the crates.io index hash.\n",
            "# debian:13 CI has no host cargo; use the rules_rust toolchain binary.\n",
            'export CARGO="$cargo"\n',
            'export PATH="$(dirname "$cargo"):${PATH:-}"\n',
            "export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse\n\n",
            'export CARGO_HOME="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/cargo-audit-home"\n',
            'mkdir -p "$CARGO_HOME"\n',
            'exec "$cargo_audit" audit {flags} "$@"\n'.format(flags = flags),
        ]),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        script,
        cargo_audit,
        cargo,
        ctx.file.lock,
        ctx.file.manifest,
    ])
    runfiles = runfiles.merge(ctx.attr.cargo_audit[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(ctx.attr.cargo[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = script,
        files = depset([script]),
        runfiles = runfiles,
    )]

_cargo_audit_test = rule(
    implementation = _impl,
    test = True,
    attrs = {
        "cargo": attr.label(
            default = Label("@rules_rust//rust/toolchain:current_cargo_files"),
            allow_files = True,
            cfg = "target",
            doc = "Hermetic cargo from the rules_rust toolchain (`cargo -V`).",
        ),
        "cargo_audit": attr.label(
            default = Label("//rust:cargo-audit"),
            executable = True,
            cfg = "target",
            doc = "cargo-audit binary from bazel_utils Cargo.lock (override to use another).",
        ),
        "flags": attr.string_list(
            doc = "cargo-audit arguments after `audit` (e.g. --color never).",
        ),
        "lock": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer Cargo.lock to audit.",
        ),
        "manifest": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Consumer Cargo.toml next to Cargo.lock.",
        ),
    },
    doc = "bazel test: cargo-audit against locked crates (no-sandbox, needs rustsec DB).",
)

def cargo_audit_test(
        name,
        lock = "//:Cargo.lock",
        manifest = "//:Cargo.toml",
        tags = [],
        flags = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's cargo-audit against the consumer lockfile.

    The scanner binary is pinned in this module's Cargo.lock. `cargo -V` still
    uses the consumer's rules_rust toolchain. Defaults `local = True` and tags
    `external`, `no-cache`, `no-sandbox`, `requires-network`.

    Args:
      name: Target name.
      lock: Consumer Cargo.lock (default `//:Cargo.lock`).
      manifest: Consumer Cargo.toml next to the lock (default `//:Cargo.toml`).
      tags: Extra test tags; merged with the defaults above.
      flags: Extra cargo-audit flags after `audit`.
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`cargo_audit`, `size`, …).
    """
    _cargo_audit_test(
        name = name,
        lock = lock,
        manifest = manifest_label(manifest),
        tags = workspace_test_tags(tags, requires_network = True),
        flags = flags,
        local = local,
        **kwargs
    )
