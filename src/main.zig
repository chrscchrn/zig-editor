const std = @import("std");
const glfw = @import("my-zig-glfw");

const glfw_log = std.log.scoped(.glfw);

fn logGLFWError(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

const print = std.debug.print;

// pub fn main() !void {
//     print("program run\n", .{});
//     glfw.setErrorCallback(logGLFWError);
//     // GLFW setup
//     if (!glfw.init(.{})) {
//         glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
//         return error.GLFWInitFailed;
//     }
//     defer glfw.terminate();
//
//     const window = glfw.Window.create(1920, 1080, "editor made with zig", null, null, .{});
//     defer window.?.destroy();
//
//     glfw.makeContextCurrent(window);
//     defer glfw.makeContextCurrent(null);
//
//     main_loop: while (true) {
//          glfw.waitEvents();
//         if (window.?.shouldClose()) break :main_loop;
//
//         window.?.swapBuffers();
//     }
// }

pub fn main() !void {
    var argIter = std.process.args();
    _ = argIter.next();
    const inputFileName = argIter.next();
    if (inputFileName == null) return error.NoInputFile;
    if (argIter.next()) |arg| {
        _ = arg;
        return error.MultipleInputFileError;
    }
    // at this point the command line arguement is narrowed down to one word.

    // now focus on opening and editing the existing file.
    const file = try std.fs.cwd().openFile(inputFileName.?, .{});
    defer file.close();

    var bufReader = std.io.bufferedReader(file.reader());
    var inStream = bufReader.reader();

    // put all file content into a data structure...
    var buf: [1024]u8 = undefined;
    while (try inStream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        print("{s}\n", .{line});
    }
}
