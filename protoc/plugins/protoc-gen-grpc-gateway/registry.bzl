"""GitHub-release catalog for protoc-gen-grpc-gateway.

Selected by `protoc.plugin(name = "protoc-gen-grpc-gateway", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-grpc-gateway"

# kind `file`: raw GitHub release binary.
PLUGIN = {
    "kind": "file",
    "name": NAME,
    "url": "https://github.com/grpc-ecosystem/grpc-gateway/releases/download/{version}/protoc-gen-grpc-gateway-{version}-{file}",
    "versions": {
        "v2.30.0": {
            "linux_amd64": {
                "bin": "protoc-gen-grpc-gateway",
                "file": "linux-x86_64",
                "sha256": "3451a430e9dfaa43d199825426e96382348f69c4a42402a5b3f06fdd917c18ca",
            },
            "linux_arm64": {
                "bin": "protoc-gen-grpc-gateway",
                "file": "linux-arm64",
                "sha256": "0f74b7795bafc429b6fbae59d8d5d5600aae6dcd9bd25477a728e4bb67c75aaf",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-grpc-gateway",
                "file": "darwin-x86_64",
                "sha256": "595a2943b3da556523f72f574e4752eda4607625514af8ff62d051b281cb2f74",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-grpc-gateway",
                "file": "darwin-arm64",
                "sha256": "4b8204296cfd46d25b23a1929ebb893fe99f00a2b057eef4f63ec794d1274c3a",
            },
            "windows_amd64": {
                "bin": "protoc-gen-grpc-gateway.exe",
                "file": "windows-x86_64.exe",
                "sha256": "520a308b25449fcb5755870b255d27139eaf276b2d9fc575a82941673055c526",
            },
            "windows_arm64": {
                "bin": "protoc-gen-grpc-gateway.exe",
                "file": "windows-arm64.exe",
                "sha256": "e7d13e3c5ddffaf3156f7e44fac3f6060a73d4be982b8dd4b91bf713c67ea679",
            },
        },
    },
}
