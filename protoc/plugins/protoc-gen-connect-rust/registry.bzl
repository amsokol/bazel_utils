"""GitHub-release catalog for protoc-gen-connect-rust.

Selected by `protoc.plugin(name = "protoc-gen-connect-rust", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-connect-rust"

# kind `file`: raw GitHub release binary.
PLUGIN = {
    "kind": "file",
    "name": NAME,
    "url": "https://github.com/connectrpc/connect-rust/releases/download/{version}/protoc-gen-connect-rust-{version}-{file}",
    "versions": {
        "v0.9.0": {
            "linux_amd64": {
                "bin": "protoc-gen-connect-rust",
                "file": "linux-x86_64",
                "sha256": "41c342e7589cbf05bec0e0a98d45ef23e01f514eb30ca7b73ac6d8cd054c7a4e",
            },
            "linux_arm64": {
                "bin": "protoc-gen-connect-rust",
                "file": "linux-aarch64",
                "sha256": "d91fd99afd2406db87f4bb90e86eb7bd5814f2ee69dc40a5932d31978fd2a1f8",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-connect-rust",
                "file": "darwin-x86_64",
                "sha256": "8c24ae17bf27d7bb4c1a6b7f0ac2f6f267930fe7955f7f2271e768126ae54e3a",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-connect-rust",
                "file": "darwin-aarch64",
                "sha256": "269ea76c84a63677a5a42c6aeb1537edafa91267096dafce164994f097de22f9",
            },
            "windows_amd64": {
                "bin": "protoc-gen-connect-rust.exe",
                "file": "windows-x86_64.exe",
                "sha256": "cfb22284fe46063203b50d096a8829d364d0cbafce5f80dd1903da0734ec56f3",
            },
        },
    },
}
