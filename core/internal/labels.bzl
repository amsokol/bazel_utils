"""Normalize consumer-workspace labels passed to macros."""

def workspace_file_label(label, what = "file"):
    """Normalize a file path to a file label (`//pkg/file` → `//pkg:file`).

    Macros pass the result as a string so it resolves in the consumer.

    Args:
      label: `//:file`, `//pkg:file`, or `//pkg/file`.
      what: Name used in error messages (`manifest`, `config`, `lock`, …).

    Returns:
      A Bazel file label.
    """
    rest = _require_abs_label(label, what)
    if ":" in rest:
        return label
    if "/" not in rest:
        return "//:" + rest
    pkg, _, name = rest.rpartition("/")
    if not name:
        fail("{} must be a file, got {}".format(what, label))
    return "//{}:{}".format(pkg, name)

def manifest_label(manifest):
    """Normalize a manifest path (`//go/go.mod` → `//go:go.mod`)."""
    return workspace_file_label(manifest, what = "manifest")

def lock_label(lock):
    """Normalize a lock path (`//subdir/uv.lock` → `//subdir:uv.lock`)."""
    return workspace_file_label(lock, what = "lock")

def workspace_rel_dir(label, what = "dirs"):
    """Workspace-relative directory: `//go/app` → `go/app`, `//:file` → `""`.

    Args:
      label: Absolute Bazel package or file label in the consumer workspace.
      what: Name used in error messages (`dirs`, …).

    Returns:
      Path relative to the workspace root, or `""` for the root package.
    """
    rest = _require_abs_label(label, what)
    if rest.startswith(":"):
        return ""
    if ":" in rest:
        pkg, _, _name = rest.partition(":")
        return pkg
    return rest

def _require_abs_label(label, what):
    if label.startswith("@") or label.startswith(":"):
        fail("{} must be an absolute label in the consumer workspace, got {}".format(
            what,
            label,
        ))
    if not label.startswith("//"):
        fail("{} must be an absolute Bazel label, got {}".format(what, label))
    return label[2:]
