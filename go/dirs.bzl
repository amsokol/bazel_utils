"""Convert Bazel paths from the workspace root to go list patterns."""

load("@bazel_utils_core//internal:labels.bzl", "workspace_rel_dir")

def go_list_patterns(dirs):
    """Return go list patterns for `dirs` from the workspace root.

    Bazel paths (`//go/app/src`) are `<root>/go/app/src`, not relative to
    go.mod. They become recursive patterns (`./go/app/src/...`). Other strings
    are passed through (e.g. `./go/...`).

    Args:
      dirs: Bazel packages from repo root (`//go`) and/or go list patterns.

    Returns:
      go list patterns relative to the workspace root.
    """
    out = []
    for d in dirs:
        if d.startswith("//") or d.startswith(":") or d.startswith("@"):
            path = workspace_rel_dir(d)
            out.append("./..." if not path else "./" + path + "/...")
        else:
            out.append(d)
    return out
