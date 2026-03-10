const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_opts = .{ .target = target, .optimize = optimize };
    const httpz_module = b.dependency("httpz", dep_opts).module("httpz");
    const pg_module = b.dependency("pg", dep_opts).module("pg");

    const imports: []const std.Build.Module.Import = &.{
        .{ .name = "httpz", .module = httpz_module },
        .{ .name = "pg", .module = pg_module },
    };

    // Main executable (embed assets in release mode)
    const options = b.addOptions();
    options.addOption(bool, "embed_assets", optimize != .Debug);

    const exe = b.addExecutable(.{
        .name = "buildlight",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    exe.root_module.addOptions("build_options", options);
    exe.linkLibC();
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    b.step("run", "Run the server").dependOn(&run_cmd.step);

    // Test step (never embed assets in tests)
    const test_options = b.addOptions();
    test_options.addOption(bool, "embed_assets", false);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    tests.root_module.addOptions("build_options", test_options);
    tests.linkLibC();

    const run_tests = b.addRunArtifact(tests);
    run_tests.has_side_effects = true;
    b.step("test", "Run tests").dependOn(&run_tests.step);
}
