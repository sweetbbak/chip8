/// massive thanks you to Cowgod: http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#0.0
/// https://github.com/IridescentRose/CHIP-8z
/// I am interpreting everything from their spec guide
const std = @import("std");
const log = std.log;
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const keys = @import("keyboard.zig");
const rl = @import("raylib");

/// the Chip-8 CPU
pub const CPU = @This();

/// the location where ROMs are loaded to
/// 0x600 for ETI 660 computer
const ROM_LOCATION = 0x200;

/// 0-511 reserved for interpreter (sprites, font, etc...)
const RESERVED_MEM = 0x1FF;

/// rows in the Chip-8 display
const DISPLAY_ROWS = 64;

/// cols in the Chip-8 display
const DISPLAY_COLS = 32;

const FONTSET_BYTES_PER_CHAR = 5;

/// the allocator used to load a ROM
alloc: Allocator,

/// the total RAM of the Chip-8
memory: [0xFFF]u8,

/// Chip-8 has 16 general purpose 8-bit registers, usually referred
/// to as Vx, where x is a hexadecimal digit (0 through F).cpu
/// There is also a 16-bit register called I.
/// This register is generally used to store memory addresses,
/// so only the lowest (rightmost) 12 bits are usually used.
/// the VF register should not be used by programs, it is used as a flag
/// for some instructions
registers: [16]u8,

/// maybe needed, used to store memory addresses
register_I: u16,

/// stores the currently executing address
program_counter: u16,

/// current opcode
current_opcode: u16,

/// points to the topmost level of the stack
stack_pointer: u8,

/// special register for delay timing
/// when non-zero, automatically decremented at a rate of 60Hz
/// This timer does nothing more than subtract 1 from the value
/// of DT at a rate of 60Hz. When DT reaches 0, it deactivates.
delay_timer: u8,

/// special register for sound timing
/// when non-zero, automatically decremented at a rate of 60Hz
/// This timer also decrements at a rate of 60Hz, however, as
/// long as ST's value is greater than zero, the Chip-8 buzzer
/// will sound. When ST reaches zero, the sound timer deactivates.
/// the sounds is decided by the author of the interpreter
sound_timer: u8,

/// the stack is an array of 16 16-bit values
/// used to store the address that the interpreter shoud return to when finished with a subroutine
/// Chip-8 allows for up to 16 levels of nested subroutines
stack: [16]u16,

/// this represents the keyboard on/off state
/// of the following keypad
/// [1, 2, 3, C]
/// [4, 5, 6, D]
/// [7, 8, 9, E]
/// [A, 0, B, F]
keyboard: [16]u8,

/// the video memory, Chip-8 has a 64 pixel by 32 pixel screen
/// it is monochrome and can be represented by an on/off state
// display: [0x800]u8 = [64 * 32]u8,
// display: [0x800]u8 = [_]u8{0x00} ** 0x800,
display: [64 * 32]u8,

/// trigger a draw to the screen
draw_flag: bool,

/// Chip-8 draws graphics on screen through the use of sprites. A sprite is a group of bytes which are a binary representation of the desired picture. Chip-8 sprites may be up to 15 bytes, for a possible sprite size of 8x15.
/// Programs may also refer to a group of sprites representing the hexadecimal digits 0 through F. These sprites are 5 bytes long, or 8x5 pixels. The data should be stored in the interpreter area of Chip-8 memory (0x000 to 0x1FF). Below is a listing of each character's bytes, in binary and hexadecimal:
const font = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub fn init(alloc: Allocator) CPU {
    var self = CPU{
        .alloc = alloc,
        .stack = [_]u16{0x00} ** 16,
        .memory = [_]u8{0x00} ** 4095,
        .display = [_]u8{0x00} ** 2048,
        .keyboard = [_]u8{0x00} ** 16,
        .registers = [_]u8{0x00} ** 16,
        .register_I = 0x00,
        .delay_timer = 0x00,
        .sound_timer = 0x00,
        .stack_pointer = 0x00,
        .current_opcode = 0x00,
        .program_counter = 0x200,
        .draw_flag = false,
    };

    // Clear display
    for (&self.display) |*g| {
        g.* = 0x00;
    }

    // Clear stack
    for (&self.stack) |*s| {
        s.* = 0x00;
    }

    // Clear registers
    for (&self.registers) |*r| {
        r.* = 0x00;
    }

    // Clear memory
    for (&self.memory) |*v| {
        v.* = 0x00;
    }

    // Clear key
    for (&self.keyboard) |*k| {
        k.* = 0x00;
    }

    // Set fonts
    for (font, 0..) |c, idx| {
        self.memory[idx] = c;
    }

    self.draw_flag = true;
    self.delay_timer = 0;
    self.sound_timer = 0;
    return self;
}

/// load a rom from the given file path
/// uses the CPU allocator
pub fn load_rom_alloc(self: *CPU, filepath: []const u8) !void {
    const file = try fs.cwd().openFile(filepath, .{ .read_only = true });
    const rom = try file.readToEndAlloc(self.alloc);
    @memcpy(self.memory[ROM_LOCATION..], rom);
}

/// load a rom from raw bytes
pub fn load_rom_bytes(self: *CPU, bytes: []const u8) !void {
    @memcpy(self.memory[ROM_LOCATION..], bytes);
}

pub fn load_rom(self: *CPU, filename: []const u8) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const size = try file.getEndPos();
    std.debug.print("ROM File Size {d}\n", .{size});
    var reader = file.reader();

    var i: usize = 0;
    while (i < size) : (i += 1) {
        self.memory[i + 0x200] = try reader.readByte();
    }
}

pub fn dump_mem(self: *CPU) void {
    std.debug.print("{s}{x:0>7}:{s} ", .{ "\x1b[90m", 0, "\x1b[0m" });

    for (self.memory[0..], 0..) |value, i| {
        if (value == 0 or (value >= 16 and value <= 20) or (i >= 232 and i <= 242)) {
            std.debug.print("\x1b[38;5;255m\x1b[48;5;{d}m{x:0>2}\x1b[0m", .{ value, value });
        } else {
            std.debug.print("\x1b[38;5;{d}m{x:0>2}\x1b[0m", .{ value, value });
        }

        if (i % 2 == 0) {
            std.debug.print(" ", .{});
        }

        if (i % 16 == 0) {
            std.debug.print("\n", .{});
            std.debug.print("{s}{x:0>7}:{s} ", .{ "\x1b[90m", i, "\x1b[0m" });
        }
    }
    std.debug.print("\n", .{});
}

// advance by two bytes (u8) since an opcode is made up of
// two bytes
pub inline fn increment_pc(self: *CPU) void {
    self.program_counter += 2;
}

pub fn draw_sprite2(self: *CPU, x: u8, y: u8, n: u8) void {
    const row = y;
    const col = x;

    // set collision to 0
    self.registers[0xF] = 0;

    var byte_index: usize = 0;
    while (byte_index < n) : (byte_index += 1) {
        const spr = self.memory[self.register_I + byte_index];

        var bit_index: usize = 0;
        while (bit_index < 8) : (bit_index += 1) {
            // the value of the bit in the sprite
            const bit: u8 = (spr >> @intCast(bit_index)) & 0x1;
            // const pix: *u8 = &self.display[((row + byte_index) % DISPLAY_COLS) + ((col + (7 - bit_index)) % DISPLAY_ROWS)];
            const pix: *u8 = &self.display[((row + byte_index) % DISPLAY_ROWS) + ((col + (7 - bit_index)) % DISPLAY_COLS)];

            if (bit == 1 and pix.* == 1) {
                self.registers[0xF] = 1;
            }
            pix.* ^= bit;
            // self.display[((row + byte_index) % DISPLAY_COLS) + ((col + (7 - bit_index)) % DISPLAY_ROWS)] ^= bit;
        }
    }
}

pub fn draw_sprite(self: *CPU) void {
    self.registers[0xF] = 0;

    const registerX = self.registers[(self.current_opcode & 0x0F00) >> 8];
    const registerY = self.registers[(self.current_opcode & 0x00F0) >> 4];
    const height = self.current_opcode & 0x000F;

    var y: usize = 0;
    while (y < height) : (y += 1) {
        const spr = self.memory[self.register_I + y];

        var x: usize = 0;
        while (x < 8) : (x += 1) {
            const v: u8 = 0x80;
            if ((spr & (v >> @intCast(x))) != 0) {
                const tX = (registerX + x) % 64;
                const tY = (registerY + y) % 32;

                const idx = tX + tY * 64;

                self.display[idx] ^= 1;

                if (self.display[idx] == 0) {
                    self.registers[0x0F] = 1;
                }
            }
        }
    }
}

pub fn random_byte(self: *CPU) u8 {
    _ = self;
    const rand_gen = std.Random.DefaultPrng;
    var rand = rand_gen.init(33);
    return @mod(rand.random().int(u8), 255);
}

pub fn step(self: *CPU) !void {
    if (self.program_counter > self.memory.len) {
        return error.ProgramCounterOverflow;
    }

    // combine the high and low bytes
    // |15            8|7         bit 0|
    // +---------------+---------------+
    // |0 0 0 0 0 0 0 0|0 1 1 1 1 0 0 0|
    // +---------------+---------------+
    // SHIFT RIGHT by 8 bits
    // +---------------+---------------+
    // |0 1 1 1 1 0 0 0|0 0 0 0 0 0 0 0|
    // +---------------+---------------+
    // OR with the next instruction
    // +---------------+---------------+
    // |0 0 0 0 0 0 0 0|1 1 1 1 0 0 0 1|
    // +---------------+---------------+
    // which becomes:
    // +---------------+---------------+
    // |0 1 1 1 1 0 0 0|1 1 1 1 0 0 0 1|
    // +---------------+---------------+
    // ^instr   ^      ^        ^
    // where each byte is called a "nibble"
    self.current_opcode = @as(u16, @intCast(self.memory[self.program_counter])) << 8 | self.memory[self.program_counter + 1];

    // if this looks insane to you, read up on bitwise/binary operations
    // and check out this SO post: https://stackoverflow.com/questions/4058339/what-is-0xff-and-why-is-it-shifted-24-times
    // we use the highest byte to indicate the instruction/operation and different sequnces of the
    // following bytes as arguments to those operations.
    const x = (self.current_opcode >> 8) & 0x000F; // the lower 4 bits of the byte
    const y = (self.current_opcode >> 4) & 0x000F; // the upper 4 bits of the byte
    const n: u8 = @truncate(self.current_opcode & 0x000F); // the lowest 4 bits
    const kk: u8 = @truncate(self.current_opcode & 0x00FF); // the lowest 8 bits
    const nnn: u16 = self.current_opcode & 0x0FFF; // the lowest 12 bits

    // switch on the highest order bit (the prefix)
    switch (self.current_opcode & 0xF000) {
        0x0000 => {
            switch (kk) {
                0x0000 => {
                    log.debug("NO-OP", .{});
                    // self.increment_pc();
                },
                0x00E0 => {
                    log.debug("clear display", .{});
                    for (&self.display) |*g| {
                        g.* = 0;
                    }
                    self.increment_pc();
                },
                0x00EE => {
                    // The interpreter sets the program counter to the address at the top of the stack,
                    // then subtracts 1 from the stack pointer. check order of subtract
                    self.stack_pointer -= 1;
                    self.program_counter = self.stack[self.stack_pointer];
                    log.debug("return [{x}]", .{self.program_counter});
                    self.increment_pc();
                },
                else => {},
            }
        },
        0x1000 => {
            // 1nnn jump to address nnn
            log.debug("jump to address: 0x{x}", .{nnn});
            self.program_counter = nnn;
        },
        0x2000 => {
            // 2nnn call sub-routine (function) at 0xNNN adding PC to the stack so we can return here
            log.debug("save PC [0x{x}] to stack addr [0x{x}] and call sub-routine at: 0x{x}", .{
                self.program_counter,
                self.stack[self.stack_pointer],
                nnn,
            });

            self.stack[self.stack_pointer] = self.program_counter;
            self.stack_pointer += 1;
            self.program_counter = nnn;
        },
        0x3000 => {
            // 3xnn skip if Vx == 0xNN
            log.debug("skip opcode if register X is equal to KK: 0x{x} == 0x{x}", .{ self.registers[x], kk });
            if (self.registers[x] == kk) {
                self.increment_pc();
            }

            self.increment_pc();
        },
        0x4000 => {
            // 3xnn skip if Vx != 0xNN
            log.debug("skip opcode if register X is NOT equal to KK: 0x{x} == 0x{x}", .{ self.registers[x], kk });
            if (self.registers[x] != kk) {
                self.increment_pc();
            }

            self.increment_pc();
        },
        0x5000 => {
            // 3xnn skip if Vx == Vy
            log.debug("skip opcode if register X is equal to register Y: 0x{x} == 0x{x}", .{ self.registers[x], self.registers[y] });
            if (self.registers[x] == self.registers[y]) {
                self.increment_pc();
            }

            self.increment_pc();
        },
        0x6000 => {
            // 6xnn load Vx with immediate value
            log.debug("Set V[0x{x}] to 0x{x}", .{ x, kk });
            self.registers[x] = kk;
            self.increment_pc();
        },
        0x7000 => {
            // 7xkk: set V[x] = V[x] + kk
            log.debug("**** set V[0x{x}] to V[0x{x}] + 0x{x}", .{
                self.registers[x],
                self.registers[x],
                kk,
            });
            @setRuntimeSafety(false);
            // self.registers[x] = @truncate(self.registers[x] + kk);
            self.registers[x] += @truncate(kk);
            self.increment_pc();
        },
        0x8000 => {
            log.debug("LETS DO MATH :3", .{});
            // math operations
            switch (n) {
                0x0 => {
                    self.registers[x] = self.registers[y];
                },
                0x1 => {
                    self.registers[x] |= self.registers[y];
                },
                0x2 => {
                    self.registers[x] &= self.registers[y];
                },
                0x3 => {
                    self.registers[x] ^= self.registers[y];
                },
                0x4 => {
                    var sum: u16 = self.registers[x];
                    sum += self.registers[y];
                    // set the Vf register if carry
                    self.registers[0xF] = if (sum > 255) 1 else 0;
                    self.registers[x] = @as(u8, @truncate(sum & 0x00FF));
                },
                0x5 => {
                    @setRuntimeSafety(false);
                    self.registers[0xF] = if (self.registers[x] > self.registers[y]) 1 else 0;
                    self.registers[x] -= self.registers[y];
                },
                0x6 => {
                    self.registers[0xF] = self.registers[x] & 0x1;
                    self.registers[x] >>= 1;
                },
                0x7 => {
                    @setRuntimeSafety(false);
                    self.registers[0xF] = if (self.registers[y] > self.registers[x]) 1 else 0;
                    self.registers[x] = self.registers[y] - self.registers[x];
                },
                0xE => {
                    self.registers[0xF] = if (self.registers[x] & 0x1 != 0) 1 else 0;
                    self.registers[x] <<= 1;
                },
                else => {
                    log.debug("bad math opcode: 0x{x}", .{self.current_opcode});
                    return error.MathOpOutOfRange;
                },
            }

            self.increment_pc();
        },
        0x9000 => {
            // 9xy0: skip instruction if Vx != Vy
            switch (n) {
                0x00 => {
                    log.debug("set V[0x{x}] to V[0x{x}] + 0x{x}", .{ self.registers[x], self.registers[x], kk });
                    self.program_counter += if (self.registers[x] != self.registers[y]) 4 else 2;
                },
                else => {
                    log.debug("bad opcode for instruction 0x9000, opcode: 0x{x} n: 0x{x}", .{ self.current_opcode, n });
                    return error.BadOpcode;
                },
            }
        },
        0xA000 => {
            // Annn set I to address nnn
            log.debug("set register I to 0x{x} ", .{nnn});
            self.register_I = nnn;
            self.increment_pc();
        },
        0xB000 => {
            // Bnnn jump to location nnn + V[0]
            log.debug("jump to 0x{x} + V[0] (0x{x})", .{ nnn, self.registers[0] });
            self.program_counter = nnn + self.registers[0];
        },
        0xC000 => {
            // Cxkk V[x] = random byte AND kk
            log.debug("V[0x{x}] = random byte AND kk", .{x});
            self.registers[x] = self.random_byte() & kk;
            self.increment_pc();
        },
        0xD000 => {
            // draw sprite at Vx Vy, sprite is 0xN pixels tall, on/off value based on I, Vf set if any
            // pixels are flipped
            log.debug("draw sprite at (V[{d}], V[{d}]) = (0x{x}, 0x{x}) of height {d}", .{ x, y, self.registers[x], self.registers[y], n });
            self.draw_sprite();
            // self.draw_sprite2(@truncate(x), @truncate(y), n);
            self.increment_pc();
            self.draw_flag = true;
        },
        0xE000 => {
            // key press events
            // log.debug("draw sprite at (V[{d}], V[{d}]) = (0x{x}, 0x{x}) of height {d}", .{ x, y, self.registers[x], self.registers[y], n });
            switch (kk) {
                0x9E => {
                    log.debug("skip the next instruction if key[{d}] is pressed", .{x});
                    // const reg_key = self.registers[x];
                    // const ray_key = keys.get_raylib_key(reg_key) catch unreachable;
                    //
                    // log.debug("key not pressed: {s}", .{@tagName(ray_key)});
                    // if (keys.isKeyDown(ray_key)) {
                    //     log.debug("key is DOWN", .{});
                    //     self.increment_pc();
                    // }

                    // self.increment_pc();
                    self.program_counter += if (self.keyboard[self.registers[x]] == 1) 4 else 2;
                },
                0xA1 => {
                    log.debug("skip the next instruction if key[{d}] is NOT pressed", .{x});
                    // const reg_key = self.registers[x];
                    // const ray_key = keys.get_raylib_key(reg_key) catch unreachable;
                    //
                    // log.debug("key not pressed: {s}", .{@tagName(ray_key)});
                    //
                    // if (keys.isKeyUp(ray_key)) {
                    //     log.debug("key is UP", .{});
                    //     self.increment_pc();
                    // }
                    //
                    // self.increment_pc();

                    // self.program_counter += if (self.keyboard[self.registers[x]] != 1) 4 else 2;
                    if (self.keyboard[self.registers[x]] != 1) {
                        log.debug("key is up", .{});
                        self.program_counter += 4;
                    } else {
                        log.debug("key is down", .{});
                        self.increment_pc();
                    }
                },
                else => {
                    // self.increment_pc();
                    log.debug("bad opcode for instruction 0xE000, opcode: 0x{x} key: {d}", .{ self.current_opcode, self.keyboard[self.registers[x]] });
                    return error.BadOpcode;
                },
            }
        },
        0xF000 => {
            // misc
            switch (kk) {
                0x07 => {
                    // Vy = delay timer
                    self.registers[x] = self.delay_timer;
                    self.increment_pc();
                },
                0x0A => {
                    log.debug("waiting for keypress", .{});
                    // waits for key press, stores index in VX
                    const key = keys.getKeyPressed() catch {
                        log.debug("setting PC back by 2 to read key", .{});
                        self.program_counter -|= 2;
                        return;
                    };

                    // const code = keys.keymap.get(key) orelse unreachable;
                    const code = keys.get_keycode(key) catch unreachable;
                    self.registers[x] = code;
                    self.increment_pc();

                    // keys.read_key(self);

                    // var key_pressed: bool = false;

                    // var i: usize = 0;
                    // while (i < 16) : (i += 1) {
                    //     self.keyboard[i] = if (rl.isKeyDown(keys.keymap[i])) 1 else 0;
                    //     if (rl.isKeyDown(keys.keymap[i])) {
                    //         std.debug.print("KEY DOWN {s}\n", .{@tagName(keys.keymap[i])});
                    //         self.keyboard[i] = 1;
                    //     }
                    // }

                    // keys.read_key(self);

                    // std.debug.print("keyboard {}\n", .{self.keyboard[i]});
                    // if (self.keyboard[i] != 0) {
                    //     self.registers[x] = @truncate(i);
                    //     key_pressed = true;
                    // }

                    // keys.reset_key(self);
                    // }

                    // for (0.., 16) |i, _| {
                    //     self.keyboard[i] = if (rl.isKeyDown(keys.keymap[i])) 1 else 0;
                    //
                    //     if (self.keyboard[i] != 0) {
                    //         self.registers[x] = @truncate(i);
                    //         key_pressed = true;
                    //     }
                    // }

                    // if (!key_pressed) {
                    //     return;
                    // }
                    // self.increment_pc();
                },
                0x15 => {
                    // delay timer = Vx
                    self.delay_timer = self.registers[x];
                    self.increment_pc();
                },
                0x18 => {
                    // sound timer = Vx
                    self.sound_timer = self.registers[x];
                    self.increment_pc();
                },
                0x1E => {
                    // I += Vx
                    self.registers[0xF] = if (self.register_I + self.registers[x] > 0xFFF) 1 else 0;
                    self.register_I += self.registers[x];
                    self.increment_pc();
                },
                0x29 => {
                    // set I to address of font character in VX
                    self.register_I += self.registers[x] * FONTSET_BYTES_PER_CHAR;
                    self.increment_pc();
                },
                0x33 => {
                    // stores BCD (binary encoded decimal) encoding of VX into I
                    log.debug("store BCD encoded value into Vx", .{});
                    // self.memory[self.register_I] = @mod((self.registers[x]), 1000) / 100; // hundreds digit
                    self.memory[self.register_I] = (self.registers[x]) / 100; // hundreds digit
                    self.memory[self.register_I + 1] = (self.registers[x] / 10) % 10; // tens digit
                    self.memory[self.register_I + 2] = (self.registers[x] % 10); // ones digit
                    self.increment_pc();
                },
                0x55 => {
                    // stores V0 thru VX into RAM address starting at I
                    log.debug("store V0 through VX into RAM starting at I: 0x{x}", .{x});
                    // for (x, 0..) |_, i| {
                    //     self.memory[self.register_I + i] = self.registers[i];
                    // }
                    // self.register_I += x + 1;

                    var i: usize = 0;
                    while (i <= x) : (i += 1) {
                        self.memory[self.register_I + i] = self.registers[i];
                    }
                    self.increment_pc();
                },
                0x65 => {
                    // fills V0 thru VX with RAM values starting at address in I
                    log.debug("fills V0 through VX with RAM values starting at address in I: 0x{x}", .{x});
                    // for (x, 0..) |_, i| {
                    //     self.registers[i] = self.memory[self.register_I + i];
                    // }
                    // self.register_I += x + 1;

                    var i: usize = 0;
                    while (i <= x) : (i += 1) {
                        self.registers[i] = self.memory[self.register_I + i];
                    }
                    self.increment_pc();
                },
                else => {
                    log.debug("bad opcode for instruction 0xF000, opcode: 0x{x}", .{self.current_opcode});
                    return error.BadOpcode;
                },
            }
        },
        0xFF00 => {
            // return error.UnknownOpcode;
        },
        else => {
            // return error.UnknownOpcode;
        },
    }

    // self.tick();
}

pub inline fn tick(self: *CPU) void {
    if (self.delay_timer > 0) self.delay_timer -= 1;
    if (self.sound_timer > 0) self.sound_timer -= 1;
    if (self.sound_timer == 0) {
        std.debug.print("BEEP\n", .{});
    }
}

test "load a rom" {
    var cpu: CPU = init(std.testing.allocator);
    // try cpu.load_rom("./bin/5-quirks.ch8");
    try cpu.load_rom("./bin/1-chip8-logo.ch8");
    cpu.dump_mem();
}
