"""Pinned Buf CLI hashes. Unknown version → fail().

CLI versions are selected by the consumer's `buf.toolchains(version)`. This file
is the fetch catalog (GitHub asset names + sha256), not the pin.
"""

# Prebuilt GitHub release binaries (not tar.gz).
# sha256 from https://github.com/bufbuild/buf/releases/download/<version>/sha256.txt
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
    "v1.73.0": {
        "linux_amd64": {
            "file": "buf-Linux-x86_64",
            "sha256": "8f2986298ad08f0cc1bf999b9797b7c383adf32d7edf0f73d6f1e1a701baeac1",
        },
        "linux_arm64": {
            "file": "buf-Linux-aarch64",
            "sha256": "902b75267db7f4391e99b7fa0756050e5354234cc0437ef50eee9c788950c7a3",
        },
        "darwin_amd64": {
            "file": "buf-Darwin-x86_64",
            "sha256": "ff78d0ebf34180ebfa81d370275851ec630fcb088bf33e213fd723d0fd7444a6",
        },
        "darwin_arm64": {
            "file": "buf-Darwin-arm64",
            "sha256": "6e6df0fef4522e4e43dfe7c341873c3f2c29ceb45a9dfa5e0bad5580b8b2022f",
        },
        "windows_amd64": {
            "file": "buf-Windows-x86_64.exe",
            "sha256": "13542f2892c4f774150ddb525266d6421d457b3e741297056b64427853526e36",
        },
        "windows_arm64": {
            "file": "buf-Windows-arm64.exe",
            "sha256": "2250d5cba96a64f6ebc78d67221feab113622a24fbaf2909d43c87f8586d1bed",
        },
    },
}

def cli_platforms(version):
    """Return the platform map for a CLI version, or fail.

    Args:
      version: Buf CLI version tag (e.g. `v1.73.0`).

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
