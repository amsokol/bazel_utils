"""GitHub-release catalog for protoc-gen-buffa-packaging.

Selected by `protoc.plugin(name = "protoc-gen-buffa-packaging", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-buffa-packaging"

# kind `file`: raw GitHub release binary.
PLUGIN = {
    "kind": "file",
    "name": NAME,
    "url": "https://github.com/anthropics/buffa/releases/download/{version}/protoc-gen-buffa-packaging-{version}-{file}",
    "versions": {
        "v0.9.2": {
            "linux_amd64": {
                "bin": "protoc-gen-buffa-packaging",
                "file": "linux-x86_64",
                "sha256": "965e5b7b2ef6847f6597d32565468a093d70ab82ee74c326ff5397b04d419161",
            },
            "linux_arm64": {
                "bin": "protoc-gen-buffa-packaging",
                "file": "linux-aarch64",
                "sha256": "37a51a9dc9d62db6070f202f12e9a0bd9a8bf37cfa4adbfeb603cfabe0f9ff58",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-buffa-packaging",
                "file": "darwin-x86_64",
                "sha256": "c2fd8182dd1ae141fcddbdc4f8ed8e4af0f4c28d5fdc0db6c4374e1cefff929a",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-buffa-packaging",
                "file": "darwin-aarch64",
                "sha256": "7f2213ebb3de60361b5ef9c91aa76e092f61c70bd9b0cb631302fecf677f78ec",
            },
            "windows_amd64": {
                "bin": "protoc-gen-buffa-packaging.exe",
                "file": "windows-x86_64.exe",
                "sha256": "0db4cdfc67fe8a3b45f3690cc766abdaf2a10f67122c6ce94b46d6c62abd6015",
            },
        },
    },
}
