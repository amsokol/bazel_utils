"""GitHub-release catalog for protoc-gen-protovalidate-buffa.

Selected by `protoc.plugin(name = "protoc-gen-protovalidate-buffa", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-protovalidate-buffa"

# kind `archive`: cargo-dist tar.gz / zip with the binary at the archive root.
PLUGIN = {
    "kind": "archive",
    "name": NAME,
    "url": "https://github.com/mathematic-inc/protovalidate-buffa/releases/download/protoc-gen-protovalidate-buffa-{version}/protoc-gen-protovalidate-buffa-{version_bare}-{file}",
    "versions": {
        "v0.10.0": {
            "linux_amd64": {
                "bin": "protoc-gen-protovalidate-buffa",
                "file": "x86_64-unknown-linux-gnu.tar.gz",
                "sha256": "81023bfde8c991023c163839f6ef713068cd49f651c2bf8e82d746be7ee806c1",
            },
            "linux_arm64": {
                "bin": "protoc-gen-protovalidate-buffa",
                "file": "aarch64-unknown-linux-gnu.tar.gz",
                "sha256": "f16ee891c298461e87844dd575f9f95506a4008d9ab6f01dc3737eb8e858e22d",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-protovalidate-buffa",
                "file": "x86_64-apple-darwin.tar.gz",
                "sha256": "9bab6e5aa85b012e69eb30fdbec62cf1f637e309458cab2e2aad6bc03c8e5792",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-protovalidate-buffa",
                "file": "aarch64-apple-darwin.tar.gz",
                "sha256": "2bbd6158c2de84b3eb46cb11a0b0600b00ff47957b95554127c18cb5b42361ed",
            },
            "windows_amd64": {
                "bin": "protoc-gen-protovalidate-buffa.exe",
                "file": "x86_64-pc-windows-msvc.zip",
                "sha256": "ead34f6f275ab1a488042bda2d41cbe7150254bcddd76f905cc1aece189d135b",
            },
            "windows_arm64": {
                "bin": "protoc-gen-protovalidate-buffa.exe",
                "file": "aarch64-pc-windows-msvc.zip",
                "sha256": "a0f4057b44aa2588b534e26bd770124c9109c705e2f931d7675af1560bc14827",
            },
        },
    },
}
