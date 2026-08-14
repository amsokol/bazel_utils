"""Pinned Buf CLI hashes and local codegen plugins. Unknown name/version → fail().

CLI versions are selected by the consumer's `buf.toolchains(version)`. This file
is the fetch catalog (GitHub asset names + sha256), not the pin.
"""

# Prebuilt GitHub release binaries (not tar.gz).
# sha256 from https://github.com/bufbuild/buf/releases/download/v1.72.0/sha256.txt
CLI = {
    "v1.72.0": {
        "linux_amd64": {
            "file": "buf-Linux-x86_64",
            "sha256": "8720830e26a733da55bb89bcd3cb44849c0965fc0c44fb5d691cccdc64dca5af",
        },
        "linux_arm64": {
            "file": "buf-Linux-aarch64",
            "sha256": "bdbb275fb9624104ef4d8513d269cc410a153138646e67136cb3f8cc185be289",
        },
        "darwin_amd64": {
            "file": "buf-Darwin-x86_64",
            "sha256": "eb815a2708d4a43d31799049d5a2987ea81d0a9e98b53976d47bd1e78d154a8f",
        },
        "darwin_arm64": {
            "file": "buf-Darwin-arm64",
            "sha256": "5176f23a6118b9978de1340c3e3301a4ed0d48e16a669510be44b4c355170d57",
        },
        "windows_amd64": {
            "file": "buf-Windows-x86_64.exe",
            "sha256": "6e8f6d043e520bc81cae7b85d4cd6d93e57716a8a9842d5d18200191ee259cb5",
        },
        "windows_arm64": {
            "file": "buf-Windows-arm64.exe",
            "sha256": "cc06910c1b69715b598fc8d1958538c86b656c05f6dd0a516dfa90c325dcbead",
        },
    },
}

# Local plugins compiled in this module. Each version is
# plugins/<name>/<version>/ (Cargo + crate_universe).
PLUGINS = {
    "protoc-gen-protovalidate-buffa": {
        "v0.6.0": {
            "kind": "source",
            "target": "//plugins/protoc-gen-protovalidate-buffa/v0.6.0:protoc-gen-protovalidate-buffa",
        },
    },
}

def cli_platforms(version):
    """Return the platform map for a CLI version, or fail.

    Args:
      version: Buf CLI version tag (e.g. `v1.72.0`).

    Returns:
      Dict of platform name to `{file, sha256}`.
    """
    platforms = CLI.get(version)
    if not platforms:
        fail("buf.toolchains: unknown version {v}; known: {known}".format(
            known = ", ".join(sorted(CLI.keys())),
            v = version,
        ))
    return platforms

def plugin_spec(name, version):
    """Return the registry entry for a local plugin, or fail.

    Args:
      name: Plugin binary name (e.g. `protoc-gen-protovalidate-buffa`).
      version: Plugin version tag (e.g. `v0.6.0`).

    Returns:
      Registry dict for that name+version (`kind`, `target`, …).
    """
    versions = PLUGINS.get(name)
    if not versions:
        fail("buf.plugins: unknown plugin {n}; known: {known}".format(
            known = ", ".join(sorted(PLUGINS.keys())),
            n = name,
        ))
    spec = versions.get(version)
    if not spec:
        fail("buf.plugins: unknown {n} version {v}; known: {known}".format(
            known = ", ".join(sorted(versions.keys())),
            n = name,
            v = version,
        ))
    return spec
