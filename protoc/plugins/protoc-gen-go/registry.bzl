"""GitHub-release catalog for protoc-gen-go.

Selected by `protoc.plugin(name = "protoc-gen-go", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-go"

# kind `archive`: GitHub-release tar.gz / zip with the binary at the archive root.
PLUGIN = {
    "kind": "archive",
    "name": NAME,
    "url": "https://github.com/protocolbuffers/protobuf-go/releases/download/{version}/protoc-gen-go.{version}.{file}",
    "versions": {
        "v1.36.12": {
            "linux_amd64": {
                "bin": "protoc-gen-go",
                "file": "linux.amd64.tar.gz",
                "sha256": "14abe70d1557026d3dce6676b7a44d3ada91d79902c71cb075fbb8d315943320",
            },
            "linux_arm64": {
                "bin": "protoc-gen-go",
                "file": "linux.arm64.tar.gz",
                "sha256": "bf385e22e18661b044f7b96ec28384f3f76aa6da10e956b450ffb949306768de",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-go",
                "file": "darwin.amd64.tar.gz",
                "sha256": "1df5af4a047a54fb15b1f9c4a174562a692f55cab13e94b8fbf274e766800314",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-go",
                "file": "darwin.arm64.tar.gz",
                "sha256": "951d1d2558bbbc8c6680dcb6d302263fa35302cb6e1fccad297a50d21d827f2b",
            },
            "windows_amd64": {
                "bin": "protoc-gen-go.exe",
                "file": "windows.amd64.zip",
                "sha256": "ab2aa2c53df000ad47c6a546e56556d9adb1767e38136f7c9a042e0a1c22793f",
            },
            "windows_arm64": {
                "bin": "protoc-gen-go.exe",
                "file": "windows.arm64.zip",
                "sha256": "e1be29ac7430f3258df1f14098715c80e7470deae0d204f3d8d4fb4a770b0947",
            },
        },
    },
}
