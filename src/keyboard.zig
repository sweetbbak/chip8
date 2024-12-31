const std = @import("std");
const rl = @import("raylib");
const cpu = @import("cpu.zig");

pub const pollInputEvents = rl.pollInputEvents;
pub const isKeyDown = rl.isKeyDown;
pub const isKeyReleased = rl.isKeyReleased;
pub const isKeyUp = rl.isKeyUp;

pub const _keymap: [16]rl.KeyboardKey = [_]rl.KeyboardKey{
    rl.KeyboardKey.x,
    rl.KeyboardKey.one,
    rl.KeyboardKey.two,
    rl.KeyboardKey.three,
    rl.KeyboardKey.q,
    rl.KeyboardKey.w,
    rl.KeyboardKey.e,
    rl.KeyboardKey.a,
    rl.KeyboardKey.s,
    rl.KeyboardKey.d,
    rl.KeyboardKey.z,
    rl.KeyboardKey.c,
    rl.KeyboardKey.four,
    rl.KeyboardKey.r,
    rl.KeyboardKey.f,
    rl.KeyboardKey.v,
};

pub fn getKeyPressed() !rl.KeyboardKey {
    const key = rl.getKeyPressed();
    if (key == .null) {
        return error.NoKey;
    }
    return key;
}

pub fn get_keycode(key: rl.KeyboardKey) !u8 {
    switch (key) {
        .zero => return 0x0,
        .one => return 0x1,
        .two => return 0x2,
        .three => return 0x3,
        .four => return 0x4,
        .five => return 0x5,
        .six => return 0x6,
        .seven => return 0x7,
        .eight => return 0x8,
        .nine => return 0x9,
        .a => return 0xa,
        .b => return 0xb,
        .c => return 0xc,
        .d => return 0xd,
        .e => return 0xe,
        .f => return 0xf,
        else => return error.UnknownKey,
    }
}

pub fn get_raylib_key(key: u8) !rl.KeyboardKey {
    switch (key) {
        0x0 => return .zero,
        0x1 => return .one,
        0x2 => return .two,
        0x3 => return .three,
        0x4 => return .four,
        0x5 => return .five,
        0x6 => return .six,
        0x7 => return .seven,
        0x8 => return .eight,
        0x9 => return .nine,
        0xa => return .a,
        0xb => return .b,
        0xc => return .c,
        0xd => return .d,
        0xe => return .e,
        0xf => return .f,
        else => return error.UnknownKey,
    }
}

pub const keymap = std.EnumMap(rl.KeyboardKey, u8).init(.{
    .zero = 0x0,
    .one = 0x1,
    .two = 0x2,
    .three = 0x3,
    .four = 0x4,
    .five = 0x5,
    .six = 0x6,
    .seven = 0x7,
    .eight = 0x8,
    .nine = 0x9,
    .a = 0xa,
    .b = 0xb,
    .c = 0xc,
    .d = 0xd,
    .e = 0xe,
    .f = 0xf,
});

pub fn read_key(system: *cpu.CPU) void {
    for (&system.keyboard, 0..) |*k, i| {
        if (rl.isKeyDown(_keymap[i])) {
            k.* = 1;
            // system.keyboard[i] = 1;
        }
        // std.debug.print("key {d}: {d}\n", .{ i, system.keyboard[i] });
    }
}

pub fn reset_key(system: *cpu.CPU) void {
    for (&system.keyboard, 0..) |*k, i| {
        if (rl.isKeyUp(_keymap[i])) {
            k.* = 0;
            // system.keyboard[i] = 0;
        }
        // std.debug.print("key {d}: {d}\n", .{ i, system.keyboard[i] });
    }
}
