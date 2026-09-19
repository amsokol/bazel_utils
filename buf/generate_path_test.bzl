"""Starlark unit tests for buf_module import path helpers."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":generate.bzl", "dep_import_path", "repo_rel_from_short_path")

def _repo_rel_from_short_path_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "api/v1/lesson.proto", repo_rel_from_short_path("api/v1/lesson.proto"))
    asserts.equals(
        env,
        "proto/markdown/options.proto",
        repo_rel_from_short_path("../serde_markdown+/proto/markdown/options.proto"),
    )
    asserts.equals(
        env,
        "does/not/matter.proto",
        repo_rel_from_short_path("../cargo__serde_markdown-0.1.0+/does/not/matter.proto"),
    )
    return unittest.end(env)

def _dep_import_path_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "markdown/options.proto", dep_import_path("proto/markdown/options.proto", "/proto"))
    asserts.equals(env, "markdown/options.proto", dep_import_path("proto/markdown/options.proto", "proto"))
    asserts.equals(env, "markdown/options.proto", dep_import_path("proto/markdown/options.proto", "proto/"))
    asserts.equals(
        env,
        "markdown/extra/helper.proto",
        dep_import_path("proto/markdown/extra/helper.proto", "/proto"),
    )
    asserts.equals(env, "proto/markdown/options.proto", dep_import_path("proto/markdown/options.proto", ""))
    return unittest.end(env)

repo_rel_from_short_path_test = unittest.make(_repo_rel_from_short_path_test_impl)
dep_import_path_test = unittest.make(_dep_import_path_test_impl)
