const std = @import("std");
const glfw = @import("my-zig-glfw");
const gl = @import("zgl");
const freetype = @import("mach-freetype");
const harfbuzz = @import("mach-harfbuzz");
const fonts = @import("zig-fonts");

const glfw_log = std.log.scoped(.glfw);
const gl_log = std.log.scoped(.gl);
const ft_log = std.log.scoped(.ft);

const screenWidth = 1920;
const screenHeight = 1080;
// const screenSize = Size{
//     .x = 1920,
//     .y = 1080,
// };

const print = std.debug.print;

// CallBack Functions
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

fn getProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

// data types
const Character = struct {
    textureID: c_uint,
    size: Size,
    bearing: Bearing,
    advance: c_long,
};

const Size = struct {
    x: u32,
    y: u32,
};

const Bearing = struct {
    x: i32,
    y: i32,
};

// OpenGL Shaders
const vertex_shader_source: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec4 vertex; // <vec2 pos, vec2 tex>
    \\out vec2 TexCoords;
    \\
    \\uniform mat4 projection;
    \\
    \\void main()
    \\{
    \\    gl_Position = projection * vec4(vertex.xy, 0.0, 1.0);
    \\    TexCoords = vertex.zw;
    \\}
;

const fragment_shader_source: [:0]const u8 =
    \\#version 330 core
    \\in vec2 TexCoords;
    \\out vec4 color;
    \\
    \\uniform sampler2D text;
    \\uniform vec3 textColor;
    \\
    \\void main()
    \\{
    \\    vec4 sampled = vec4(1.0, 1.0, 1.0, texture(text, TexCoords).r);
    \\    color = vec4(textColor, 1.0) * sampled;
    \\}
;

pub fn main() !void {
    // glfw
    glfw.setErrorCallback(logGLFWError);
    if (!glfw.init(.{})) {
        glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLFWInitFailed;
    }
    defer glfw.terminate();

    const window = glfw.Window.create(screenWidth, screenHeight, "Zeditor", null, null, .{
        .context_version_major = 4,
        .context_version_minor = 6,
        .opengl_profile = .opengl_core_profile,
    }) orelse unreachable;
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    const proc: glfw.GLProc = undefined;
    try gl.binding.load(proc, getProcAddress);

    // Process arg input, open file
    const fileName = try processArg();
    const fileAlloc = std.heap.page_allocator;
    const buff = try readFile(fileAlloc, fileName);
    defer fileAlloc.free(buff);
    print("\n        File Contents:\n    ----------------------\n{s}", .{buff});

    // Keyboard input
    window.setKeyCallback(keyCallback);
    window.setCharCallback(characterCallback);

    // Freetype Init
    const ft = try freetype.Library.init();
    defer ft.deinit();
    const face = try ft.createFaceMemory(fonts.jetbrains_mono, 0);
    defer face.deinit();
    try face.setCharSize(0, 16 * 64, 120, 0);

    var charArray = [_]Character{undefined} ** 128;
    // const charAlloc = std.heap.page_allocator;
    // var charMap = std.AutoHashMap(u32, Character).init(charAlloc);
    // defer charAlloc.free(charMap);
    for (0..128) |i| {
        const charCode = @as(u32, @intCast(i));
        try face.loadChar(charCode, .{ .render = true });
        var texture: c_uint = undefined;
        gl.binding.genTextures(
            1,
            @ptrCast(&texture),
        );
        gl.binding.bindTexture(
            gl.binding.TEXTURE_2D,
            texture,
        );
        gl.binding.texImage2D(
            gl.binding.TEXTURE_2D,
            0,
            gl.binding.RED,
            @as(c_int, @intCast(face.glyph().bitmap().width())),
            @as(c_int, @intCast(face.glyph().bitmap().rows())),
            0,
            gl.binding.RED,
            gl.binding.UNSIGNED_BYTE,
            @ptrCast(face.glyph().bitmap().buffer()),
        );
        gl.binding.texParameteri(gl.binding.TEXTURE_2D, gl.binding.TEXTURE_WRAP_S, gl.binding.CLAMP_TO_EDGE);
        gl.binding.texParameteri(gl.binding.TEXTURE_2D, gl.binding.TEXTURE_WRAP_T, gl.binding.CLAMP_TO_EDGE);
        gl.binding.texParameteri(gl.binding.TEXTURE_2D, gl.binding.TEXTURE_MIN_FILTER, gl.binding.LINEAR);
        gl.binding.texParameteri(gl.binding.TEXTURE_2D, gl.binding.TEXTURE_MAG_FILTER, gl.binding.LINEAR);

        // try charMap.put(charCode, Character{
        //     .textureID = texture,
        //     .size = .{ .x = face.glyph().bitmap().width(), .y = face.glyph().bitmap().rows() },
        //     .bearing = .{ .x = face.glyph().bitmapLeft(), .y = face.glyph().bitmapTop() },
        //     .advance = face.glyph().advance().x,
        // });
        charArray[i] = Character{
            .textureID = texture,
            .size = .{ .x = face.glyph().bitmap().width(), .y = face.glyph().bitmap().rows() },
            .bearing = .{ .x = face.glyph().bitmapLeft(), .y = face.glyph().bitmapTop() },
            .advance = face.glyph().advance().x,
        };
    }
    gl.binding.pixelStorei(gl.binding.UNPACK_ALIGNMENT, 1);

    gl.binding.enable(gl.binding.BLEND);
    gl.binding.blendFunc(gl.binding.SRC_ALPHA, gl.binding.ONE_MINUS_SRC_ALPHA);

    // Create GL Program
    const program = create_program: {
        var success: c_uint = undefined;
        var info_log_buf: [512:0]u8 = undefined;

        const vertex_shader = gl.binding.createShader(gl.binding.VERTEX_SHADER);
        if (vertex_shader == 0) return error.CreateVertexShaderFailed;
        defer gl.binding.deleteShader(vertex_shader);

        gl.binding.shaderSource(
            vertex_shader,
            1,
            (&vertex_shader_source.ptr)[0..1],
            &@as(c_int, @intCast(vertex_shader_source.len)),
        );
        gl.binding.compileShader(vertex_shader);
        gl.binding.getShaderiv(vertex_shader, gl.binding.COMPILE_STATUS, @ptrCast(&success));
        if (success == gl.binding.FALSE) {
            gl.binding.getShaderInfoLog(vertex_shader, info_log_buf.len, null, &info_log_buf);
            gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
            return error.CompileVertexShaderFailed;
        }

        const fragment_shader = gl.binding.createShader(gl.binding.FRAGMENT_SHADER);
        if (fragment_shader == gl.binding.FALSE) return error.CreateFragmentShaderFailed;
        defer gl.binding.deleteShader(fragment_shader);

        gl.binding.shaderSource(
            fragment_shader,
            1,
            (&fragment_shader_source.ptr)[0..1],
            &@as(c_int, @intCast(fragment_shader_source.len)),
        );
        gl.binding.compileShader(fragment_shader);
        gl.binding.getShaderiv(fragment_shader, gl.binding.COMPILE_STATUS, @ptrCast(&success));
        if (success == gl.binding.FALSE) {
            gl.binding.getShaderInfoLog(fragment_shader, info_log_buf.len, null, &info_log_buf);
            gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
            return error.CompileFragmentShaderFailed;
        }

        const program = gl.binding.createProgram();
        if (program == 0) return error.CreateProgramFailed;
        errdefer gl.binding.deleteProgram(program);

        gl.binding.attachShader(program, vertex_shader);
        gl.binding.attachShader(program, fragment_shader);
        gl.binding.linkProgram(program);
        gl.binding.getProgramiv(program, gl.binding.LINK_STATUS, @ptrCast(&success));
        if (success == gl.binding.FALSE) {
            gl.binding.getProgramInfoLog(program, info_log_buf.len, null, &info_log_buf);
            gl_log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
            return error.LinkProgramFailed;
        }

        break :create_program program;
    };
    defer gl.binding.deleteProgram(program);

    main_loop: while (true) {
        glfw.waitEvents();
        if (window.shouldClose()) break :main_loop;

        gl.binding.clearColor(1, 0, 1, 1);
        gl.binding.clear(gl.binding.COLOR_BUFFER_BIT);

        window.swapBuffers();
    }
}

// Helper Functions
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
