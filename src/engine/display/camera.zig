const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");
const window = @import("./window.zig");

const zlib = @import("../z/z.m.zig");
const time = @import("../time.m.zig");

const loadf32 = @import("../engine.m.zig").loadf32;

pub var position = rl.Vector2.init(0, 0);
pub var zoom: f32 = 0.75;
pub var last_zoom: f32 = 0.1;

pub var following: ?*rl.Vector2 = null;

pub var apply_shake = false;
pub var shake_freq: f32 = 15;
pub var shake_strength: f32 = 8;

pub fn follow(vec: *rl.Vector2) void {
    following = vec;
}

pub fn update() void {
    const shake_vec = if (apply_shake) Shake: {
        const perlin_noise = zlib.perlin.noise(f32, .{
            .x = loadf32(time.gameTime) * loadf32(shake_freq),
            .y = loadf32(time.gameTime) * loadf32(shake_freq),
        }) * shake_strength - 1;

        break :Shake rl.Vector2.init(perlin_noise, perlin_noise);
    } else rl.Vector2.init(0, 0);

    if (following) |v| {
        position = v.*.add(shake_vec);
    }
}

pub fn worldPositionToScreenPosition(world_position: rl.Vector2) rl.Vector2 {
    const x = GetX: {
        var _x: f32 = window.size.x / 2;
        _x += world_position.x * zoom;
        _x -= position.x * zoom;
        break :GetX _x;
    };

    const y = GetX: {
        var _y: f32 = window.size.y / 2;
        _y += world_position.y * zoom;
        _y -= position.y * zoom;
        break :GetX _y;
    };

    return rl.Vector2.init(x, y);
}
