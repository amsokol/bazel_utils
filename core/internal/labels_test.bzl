"""Starlark unit tests for consumer label helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//internal:labels.bzl", "lock_label", "workspace_file_label", "workspace_rel_dir")

def _workspace_rel_dir_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "go", workspace_rel_dir("//go"))
    asserts.equals(env, "go/app", workspace_rel_dir("//go/app"))
    asserts.equals(env, "go", workspace_rel_dir("//go:lint"))
    asserts.equals(env, "", workspace_rel_dir("//:go.mod"))
    asserts.equals(env, "", workspace_rel_dir("//:MODULE.bazel"))
    return unittest.end(env)

def _workspace_file_label_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "//:uv.lock", workspace_file_label("//:uv.lock"))
    asserts.equals(env, "//:uv.lock", lock_label("//uv.lock"))
    asserts.equals(env, "//go:go.mod", workspace_file_label("//go/go.mod", what = "manifest"))
    asserts.equals(env, "//subdir:uv.lock", lock_label("//subdir/uv.lock"))
    return unittest.end(env)

workspace_rel_dir_test = unittest.make(_workspace_rel_dir_test_impl)
workspace_file_label_test = unittest.make(_workspace_file_label_test_impl)
