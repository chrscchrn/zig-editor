const std = @import("std");
const glfw = @import("my-zig-glfw");
const gl = @import("gl");
const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");
const fonts = @import("zig-fonts");

const glfw_log = std.log.scoped(.glfw);

const screenWidth = 1920;
const screenHeight = 1080;

const gl_procs: gl.ProcTable = undefined;

fn logGLFWError(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}

fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
    if (key == glfw.Key.escape and action == glfw.Action.press) {
        print("\n", .{});
        window.setShouldClose(true);
    }
    _ = scancode;
    _ = mods;
}

fn characterCallback(window: glfw.Window, codepoint: u21) void {
    _ = window;
    print("{u}", .{codepoint});
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

    const window = glfw.Window.create(screenWidth, screenHeight, "Zeditor", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
        // .opengl_forward_compat = gl.info.api == .gl,
    }) orelse unreachable;
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // if (!gl_procs.init(@constCast(glfw.getProcAddress))) return error.InitFailed;
    if (!gl_procs.init(@as(?gl.PROC, glfw.getProcAddress))) return error.InitFailed;

    // arg input and open file to buff
    const fileName = try processArg();
    const allocator = std.heap.page_allocator;
    const buff = try readFile(allocator, fileName);
    defer allocator.free(buff);
    print("\n        File Contents:\n    ----------------------\n{s}", .{buff});

    // Keyboard input
    window.setKeyCallback(keyCallback);
    window.setCharCallback(characterCallback);

    // Freetype init
    const ft = try freetype.Library.init();
    defer ft.deinit();

    const face = try ft.createFaceMemory(fonts.jetbrains_mono, 0);
    try face.setCharSize(0, 16 * 64, 120, 0);
    try face.loadChar('R', .{ .render = true });
    _ = face.glyph().bitmap();

    // for (0..129) |i| {
    //     try face.loadChar(@as(u32, @intCast(i)), .{ .render = true });
    //     var texture: c_uint = undefined;
    //     gl.GenTextures(1, @ptrCast(&texture));
    //     gl.BindTexture(gl.TEXTURE_2D, texture);
    //     gl.TexImage2D(
    //         gl.TEXTURE_2D,
    //         0,
    //         gl.RED,
    //         @as(c_int, @intCast(face.glyph().bitmap().width())),
    //         @as(c_int, @intCast(face.glyph().bitmap().rows())),
    //         0,
    //         gl.RED,
    //         gl.UNSIGNED_BYTE,
    //         @ptrCast(face.glyph().bitmap().buffer()),
    //     );
    // }

    main_loop: while (true) {
        glfw.waitEvents();
        if (window.shouldClose()) break :main_loop;

        window.swapBuffers();
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
