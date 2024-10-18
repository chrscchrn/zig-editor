const std = @import("std");
const glfw = @import("my-zig-glfw");

const glfw_log = std.log.scoped(.glfw);

fn logGLFWError(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

const print = std.debug.print;

pub fn main() !void {
    // glfw
    glfw.setErrorCallback(logGLFWError);
    if (!glfw.init(.{})) {
        glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLFWInitFailed;
    }
    defer glfw.terminate();
    const window = glfw.Window.create(1920, 1080, "editor made with zig", null, null, .{});
    defer window.?.destroy();
    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // arg input and open file to buff
    const fileName = try processArg();
    const allocator = std.heap.page_allocator;
    const buff = try readFile(allocator, fileName);
    defer allocator.free(buff);
    print("{s}", .{buff});

    main_loop: while (true) {
        glfw.waitEvents();
        if (window.?.shouldClose()) break :main_loop;

        window.?.swapBuffers();
    }
}

fn processArg() ![]const u8 {
    var argIter = std.process.args();
    _ = argIter.next();
    const inputFileName = argIter.next();
    if (inputFileName == null) return error.NoInputFile;
    if (argIter.next()) |arg| {
        _ = arg;
        return error.MultipleInputFileError;
    }
    return inputFileName.?;
}

fn readFile(allocator: std.mem.Allocator, fileName: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(
        fileName,
        .{},
    );
    defer file.close();
    const stat = try file.stat();
    return try file.readToEndAlloc(allocator, stat.size);
}
