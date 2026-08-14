"""Convert Bazel paths from the workspace root to go list patterns."""

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
            out.append(_bazel_dir_pattern(d))
        else:
            out.append(d)
    return out

def _require_abs_label(label, what):
    if label.startswith("@") or label.startswith(":"):
        fail("{} must be an absolute label in the consumer workspace, got {}".format(
            what,
            label,
        ))
    if not label.startswith("//"):
        fail("{} must be an absolute Bazel label, got {}".format(what, label))
    return label[2:]

def _repo_dir(label):
    """Workspace-relative directory: `//go/app/src` → `go/app/src`."""
    rest = _require_abs_label(label, "dirs")
    if rest.startswith(":"):
        return ""
    if ":" in rest:
        pkg, _, _name = rest.partition(":")
        return pkg
    return rest

def _bazel_dir_pattern(d):
    path = _repo_dir(d)
    if not path:
        return "./..."
    return "./" + path + "/..."
