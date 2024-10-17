const std = @import("std");
const glfw = @import("zig-glfw");

const glfw_log = std.log.scoped(.glfw);

fn logGLFWError(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

const print = std.debug.print;

pub fn main() !void {
    print("program run\n", .{});
    glfw.setErrorCallback(logGLFWError);
    // GLFW setup
    if (!glfw.init(.{})) {
        glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLFWInitFailed;
    }
    defer glfw.terminate();
}
