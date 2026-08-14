"""Workspace cargo-audit: audit locked crates from the consumer Cargo.lock."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("@bazel_utils_core//internal:workspace_tool.bzl", "append_workspace_file", "lock_label", "manifest_label", "workspace_test_tags", "wrapper_script_header")

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

    flags = " ".join([shell.quote(a) for a in ctx.attr.flags])
    chunks = wrapper_script_header(
        ctx,
        binaries = [["cargo_audit", cargo_audit], ["cargo", cargo]],
        workspace = ctx.file.workspace,
    )
    append_workspace_file(chunks, ctx, ctx.file.lock, "lock", "lock")
    append_workspace_file(chunks, ctx, ctx.file.manifest, "manifest", "manifest")
    chunks.append("".join([
        "# tame-index runs `$CARGO -V` (else `cargo`) to pick the crates.io index hash.\n",
        "# debian:13 CI has no host cargo; use the rules_rust toolchain binary.\n",
        'export CARGO="$cargo"\n',
        'export PATH="$(dirname "$cargo"):${PATH:-}"\n',
        "export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse\n\n",
        'export CARGO_HOME="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/cargo-audit-home"\n',
        'mkdir -p "$CARGO_HOME"\n',
        'exec "$cargo_audit" audit --file "$lock" {flags} "$@"\n'.format(flags = flags),
    ]))

    script = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = script,
        content = "".join(chunks),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        script,
        cargo_audit,
        cargo,
        ctx.file.workspace,
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
            cfg = "exec",
            doc = "Hermetic cargo from the rules_rust toolchain (`cargo -V`).",
        ),
        "cargo_audit": attr.label(
            default = Label("//:cargo-audit"),
            executable = True,
            cfg = "exec",
            doc = "Prebuilt cargo-audit from GitHub releases (override to use another).",
        ),
        "flags": attr.string_list(
            doc = "cargo-audit arguments after `audit --file <lock>` (e.g. --color never).",
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
        "workspace": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Repo-root marker used when BUILD_WORKSPACE_DIRECTORY is unset.",
        ),
    },
    doc = "bazel test: cargo-audit against locked crates (no-sandbox, needs rustsec DB).",
)

def cargo_audit_test(
        name,
        workspace = "//:MODULE.bazel",
        lock = "//:Cargo.lock",
        manifest = "//:Cargo.toml",
        tags = [],
        flags = [],
        local = True,
        **kwargs):
    """Test that runs bazel_utils's cargo-audit against the consumer lockfile.

    The scanner binary is the GitHub release for the exec OS/CPU. `cargo -V`
    still uses the consumer's rules_rust toolchain. Defaults `local = True` and tags
    `external`, `no-cache`, `no-sandbox`, `requires-network`.

    Args:
      name: Target name.
      workspace: Repo-root marker file (used when BUILD_WORKSPACE_DIRECTORY is unset).
      lock: Consumer Cargo.lock (default `//:Cargo.lock`).
      manifest: Consumer Cargo.toml next to the lock (default `//:Cargo.toml`).
      tags: Extra test tags; merged with the defaults above.
      flags: Extra cargo-audit flags after `audit --file`.
      local: Run outside the sandbox (default True).
      **kwargs: Forwarded to the test rule (`cargo_audit`, `size`, …).
    """
    _cargo_audit_test(
        name = name,
        workspace = workspace,
        lock = lock_label(lock),
        manifest = manifest_label(manifest),
        tags = workspace_test_tags(tags, requires_network = True),
        flags = flags,
        local = local,
        **kwargs
    )
