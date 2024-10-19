const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "text-editor",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const glfw_dep = b.dependency("my-zig-glfw", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("my-zig-glfw", glfw_dep.module("my-zig-glfw"));

    const gl = b.dependency("zgl", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zgl", gl.module("zgl"));

    b.installArtifact(exe);

    const freeType = b.dependency("mach_freetype", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("mach-freetype", freeType.module("mach-freetype"));
    exe.root_module.addImport("mach-harfbuzz", freeType.module("mach-harfbuzz"));
    if (b.lazyDependency("zig-fonts", .{})) |fonts| {
        exe.root_module.addImport("zig-fonts", fonts.module("zig-fonts"));
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
