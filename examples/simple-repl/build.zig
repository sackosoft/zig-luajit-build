const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = normalBuildStepsFromZigInit(b, target, optimize);
    installZigLuajitBuild(b, target, optimize, exe);
}

fn normalBuildStepsFromZigInit(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "simple-repl",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    return exe;
}

fn installZigLuajitBuild(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    exe: *std.Build.Step.Compile,
) void {
    const luajit_build_dep = b.dependency("luajit_build", .{
        .target = target,
        .optimize = optimize,
    });
    const luajit_build = luajit_build_dep.module("luajit-build");
    exe.root_module.addImport("c", luajit_build);
}
