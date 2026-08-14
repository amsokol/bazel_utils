"""Locate the source workspace for lint wrappers.

`bazel run` sets BUILD_WORKSPACE_DIRECTORY. `bazel test` does not. Runfiles
may contain a copy of MODULE.bazel (processwrapper) rather than a symlink, so
dirname(realpath(marker)) is not the checkout. execroot/_main is Bazel's source
overlay.

These snippets are concatenated into scripts (not str.format'd): bash ${var}
is written as-is.
"""

RUNFILES_BASH = """\
_rf() {
  local path=$1
  if [[ -n "${RUNFILES_DIR:-}" && -e "${RUNFILES_DIR}/${path}" ]]; then
    realpath -- "${RUNFILES_DIR}/${path}"
    return
  fi
  if [[ -e "$0.runfiles/${path}" ]]; then
    realpath -- "$0.runfiles/${path}"
    return
  fi
  echo "unable to locate runfile: ${path}" >&2
  exit 1
}
"""

WORKSPACE_BASH = RUNFILES_BASH + """
_workspace_dir() {
  local marker=$1
  if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    printf '%s\\n' "${BUILD_WORKSPACE_DIRECTORY}"
    return
  fi
  local dir
  dir=$(dirname "$marker")
  if [[ "$dir" != *".runfiles"* && "$dir" != *"/bazel-out/"* && -f "$dir/MODULE.bazel" ]]; then
    printf '%s\\n' "$dir"
    return
  fi
  local p="${TEST_SRCDIR:-}"
  while [[ -n "$p" && "$p" != "/" ]]; do
    if [[ "$(basename "$p")" == "bazel-out" ]]; then
      dir=$(dirname "$p")
      if [[ -f "$dir/MODULE.bazel" ]]; then
        printf '%s\\n' "$dir"
        return
      fi
    fi
    p=$(dirname "$p")
  done
  echo "unable to locate workspace root (MODULE.bazel). marker=$marker TEST_SRCDIR=${TEST_SRCDIR:-}" >&2
  exit 1
}
"""
