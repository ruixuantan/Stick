const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "stick",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/unit_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const exe_benchmark_mod = b.createModule(.{
        .root_source_file = b.path("src/benchmarks.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const exe_benchmarks = b.addExecutable(.{
        .name = "benchmarks",
        .root_module = exe_benchmark_mod,
    });

    b.installArtifact(exe_benchmarks);
    const run_benchmark_cmd = b.addRunArtifact(exe_benchmarks);
    run_benchmark_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_benchmark_cmd.addArgs(args);
    }

    const run_benchmark_step = b.step("bench", "Run benchmarks");
    run_benchmark_step.dependOn(&run_benchmark_cmd.step);
}
