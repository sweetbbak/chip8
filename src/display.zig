const std = @import("std");
const rl = @import("raylib");
// const rg = @import("raygui");
const cpu = @import("cpu.zig");
const keyboard = @import("keyboard.zig");

const grid_size = 20;

pub fn run(system: *cpu.CPU) !void {
    const screenWidth = 64 * grid_size;
    const screenHeight = 32 * grid_size;

    rl.initWindow(screenWidth, screenHeight, "chip-8");
    defer rl.closeWindow();

    // why does this fuck everything up?
    // const shader = rl.loadShader(null, "output.fs");
    // shader.activate();

    rl.setTargetFPS(60);
    const raylib_zig = rl.Color.init(247, 164, 29, 255);

    while (!rl.windowShouldClose()) {
        try system.step();
        // std.time.sleep(1 * std.time.ns_per_ms);
        keyboard.pollInputEvents();
        keyboard.reset_key(system);
        keyboard.read_key(system);

        if (system.draw_flag) {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(raylib_zig);

            for (0..32) |_row| {
                for (0..64) |_col| {
                    const row: i32 = @intCast(_row);
                    const col: i32 = @intCast(_col);

                    if (system.display[_row * 64 + _col] == 1) {
                        rl.drawRectangle(col * grid_size, row * grid_size, grid_size - 2, grid_size - 2, rl.Color.ray_white);
                    } else {
                        rl.drawRectangle(col * grid_size, row * grid_size, grid_size - 2, grid_size - 2, raylib_zig);
                    }
                }
            }

            system.draw_flag = false;
        }
    }
}

pub fn testwindow() !void {
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
