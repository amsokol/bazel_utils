"""GitHub-release catalog for protoc-gen-openapiv2.

Selected by `protoc.plugin(name = "protoc-gen-openapiv2", version = …)`.
This file is the fetch catalog (URL template + sha256), not the pin.
Unknown version → fail() in plugin_platforms.
"""

NAME = "protoc-gen-openapiv2"

# kind `file`: raw GitHub release binary.
PLUGIN = {
    "kind": "file",
    "name": NAME,
    "url": "https://github.com/grpc-ecosystem/grpc-gateway/releases/download/{version}/protoc-gen-openapiv2-{version}-{file}",
    "versions": {
        "v2.30.0": {
            "linux_amd64": {
                "bin": "protoc-gen-openapiv2",
                "file": "linux-x86_64",
                "sha256": "79fc245bcaf02d75a85934cf11035688de11191110e3b30b7a1859cc9492ca13",
            },
            "linux_arm64": {
                "bin": "protoc-gen-openapiv2",
                "file": "linux-arm64",
                "sha256": "9e96450bed8db2d1c98e93eb745e5d31b4fe9474549e4ab8cb598b239f2e18b1",
            },
            "darwin_amd64": {
                "bin": "protoc-gen-openapiv2",
                "file": "darwin-x86_64",
                "sha256": "2e769cd25a3a245dc3316035034561dce4f18500452c33ee2da364295777fab3",
            },
            "darwin_arm64": {
                "bin": "protoc-gen-openapiv2",
                "file": "darwin-arm64",
                "sha256": "72ad8630aa700d05362dcf0f078f0d8b6b0a366d449fd183b49a8d56555340f2",
            },
            "windows_amd64": {
                "bin": "protoc-gen-openapiv2.exe",
                "file": "windows-x86_64.exe",
                "sha256": "1fc47475877f898a82ccaffad448d4ce09bf215a5584dadf40fa0dcd200e7dbd",
            },
            "windows_arm64": {
                "bin": "protoc-gen-openapiv2.exe",
                "file": "windows-arm64.exe",
                "sha256": "94cd2b115ad4ebdd37442c0685df5901c8b217dfc0746c19865ff03687376bc7",
            },
        },
    },
}
