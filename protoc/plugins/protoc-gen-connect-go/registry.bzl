"""GitHub-release catalog for protoc-gen-connect-go.

Selected by `protoc.plugin(name = "protoc-gen-connect-go", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-connect-go"

# kind `archive`: GitHub-release tar.gz / zip with the binary at the archive root.
PLUGIN = {
    "kind": "archive",
    "name": NAME,
    "url": "https://github.com/connectrpc/connect-go/releases/download/{version}/protoc-gen-connect-go-{version}-{file}",
    "versions": {
        "v1.21.0": {
            "linux_amd64": {
                "bin": "protoc-gen-connect-go",
                "file": "Linux-x86_64.tar.gz",
                "sha256": "26c542ab11b20a04edbbd12b03f770efdf1fcb321f41beaeed143eee27d1c185",
            },
            "linux_arm64": {
                "bin": "protoc-gen-connect-go",
                "file": "Linux-aarch64.tar.gz",
                "sha256": "6d431d50755512ea32f118213ada2b363e284e83209f55136b54927742bd45aa",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-connect-go",
                "file": "Darwin-x86_64.tar.gz",
                "sha256": "e11d8f92bcfeeae00a2601a5d09cbf5cc4db18a8147dda7277d320f27a524dc2",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-connect-go",
                "file": "Darwin-arm64.tar.gz",
                "sha256": "94e6b10f1911b5a8f103c5fef3664f8b398f2dd16168aa647a478728e2abbcaa",
            },
            "windows_amd64": {
                "bin": "protoc-gen-connect-go.exe",
                "file": "Windows-x86_64.zip",
                "sha256": "4a2b125fd5abb8350f2f36f713bc86d84bb7bcfab631f4c16a8718a477d67723",
            },
            "windows_arm64": {
                "bin": "protoc-gen-connect-go.exe",
                "file": "Windows-arm64.zip",
                "sha256": "ddebd2ab81fbfd039d3643e5dabe39d16b67c8fc38e8ae16542b37b09842ef84",
            },
        },
    },
}
