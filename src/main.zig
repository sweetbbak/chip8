const std = @import("std");
const cpu = @import("cpu.zig");
const display = @import("./display.zig");
const rl = @import("raylib");

const FG = "33";
const BG = "33";

pub const std_options: std.Options = .{
    .logFn = logFn,
    .log_level = .debug,
};

var log_level = std.log.default_level;

fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(message_level) <= @intFromEnum(log_level)) {
        std.log.defaultLog(message_level, scope, format, args);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("usage: chip8 <rom>\n", .{});
        std.os.linux.exit(0);
    }

    var rom = args[1];
    if (std.mem.eql(u8, args[1], "-v")) {
        rom = args[2];
        log_level = .debug;
    } else {
        log_level = .warn;
    }

    var emu = cpu.init(allocator);
    try emu.load_rom(rom);

    try display.run(&emu);
}

pub fn testwindow() void {
    const screenWidth = 64 * 20;
    const screenHeight = 32 * 20;
    rl.initWindow(screenWidth, screenHeight, "chip-8");
    defer rl.closeWindow();

    rl.setTargetFPS(60);
    const raylib_zig = rl.Color.init(247, 164, 29, 255);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------
        const key = rl.getKeyPressed();
        if (key != .null) {
            std.debug.print("{s}\n", .{@tagName(key)});
        }
        if (key == .space) {
            break;
        }

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.lime);

        rl.drawRectangle(screenWidth / 2 - 128, screenHeight / 2 - 128, 256, 256, raylib_zig);
        rl.drawRectangle(screenWidth / 2 - 112, screenHeight / 2 - 112, 224, 224, rl.Color.ray_white);
        rl.drawText("raylib-zig", screenWidth / 2 - 96, screenHeight / 2 + 57, 41, raylib_zig);

        rl.drawText("this is NOT a texture!", 350, 370, 10, rl.Color.gray);
        //----------------------------------------------------------------------------------
    }
}
