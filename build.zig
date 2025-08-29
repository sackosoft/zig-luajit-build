const std = @import("std");

const LibraryKind = enum {
    /// Link as a static library, embedded in the application at compile time.
    static,

    /// Link as a shared library, loaded at runtime.
    dynamic,
};

const luajit_setup = @import("build/luajit.zig");

pub fn build(b: *std.Build) void {
    b.top_level_steps = .{};
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const link_as = b.option(LibraryKind, "link_as", "Used to enable shared (dynamic) linking; defaults to linking as a static library.") orelse .static;

    const upstream = b.dependency("upstream", .{});
    const lib = luajit_setup.configure(b, target, optimize, upstream, link_as == .dynamic);

    const install_lib = b.addInstallArtifact(lib, .{});
    b.getInstallStep().dependOn(&install_lib.step);

    // Create single module with C translations
    const c_headers = b.addTranslateC(.{
        .root_source_file = b.path("include/luajit_all.h"),
        .target = target,
        .optimize = optimize,
    });
    c_headers.addIncludePath(lib.getEmittedIncludeTree());
    c_headers.step.dependOn(&install_lib.step);

    // Single module that includes both C API and linking
    const luajit_build = b.addModule("luajit-build", .{
        .root_source_file = c_headers.getOutput(),
        .target = c_headers.target,
        .optimize = c_headers.optimize,
        .link_libc = c_headers.link_libc,
        .unwind_tables = .sync,
    });
    luajit_build.linkLibrary(lib);

    const config = b.addOptions();
    config.addOption(LibraryKind, "link_as", link_as);
    luajit_build.addOptions("config", config);
}
