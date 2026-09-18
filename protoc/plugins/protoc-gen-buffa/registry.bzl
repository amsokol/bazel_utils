"""GitHub-release catalog for protoc-gen-buffa.

Selected by `protoc.plugin(name = "protoc-gen-buffa", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-buffa"

# kind `file`: raw GitHub release binary.
PLUGIN = {
    "kind": "file",
    "name": NAME,
    "url": "https://github.com/anthropics/buffa/releases/download/{version}/protoc-gen-buffa-{version}-{file}",
    "versions": {
        "v0.9.2": {
            "linux_amd64": {
                "bin": "protoc-gen-buffa",
                "file": "linux-x86_64",
                "sha256": "e8d87b0cc34beb5524835888da694901deeeccaefd834fd5c03300375b629688",
            },
            "linux_arm64": {
                "bin": "protoc-gen-buffa",
                "file": "linux-aarch64",
                "sha256": "14f8285cc558f136aaa8a401e802f0e9e7a655e86dbf85ded7841f35fdf62b42",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-buffa",
                "file": "darwin-x86_64",
                "sha256": "3d63f43f1a72797e2f5f120d09fe33d7b9e8dff59919b649bfe0dbb5d4a96903",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-buffa",
                "file": "darwin-aarch64",
                "sha256": "654f4a5d58212afbdb3dec7475d99d6bc6cba2c10807c3751652cd3806cf5a5d",
            },
            "windows_amd64": {
                "bin": "protoc-gen-buffa.exe",
                "file": "windows-x86_64.exe",
                "sha256": "d6346bda11fa0845f46e43935a2c17beb5dcfe56b96db9109a4db88ea0f47814",
            },
        },
    },
}
