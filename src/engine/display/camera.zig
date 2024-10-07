const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");
const window = @import("./window.zig");

pub var position = rl.Vector2.init(0, 0);
pub var zoom: f32 = 0.1;
pub var last_zoom: f32 = 0.1;

pub var following: ?*rl.Vector2 = null;

pub fn follow(vec: *rl.Vector2) void {
    following = vec;
}

pub fn update() void {
    if (following) |v| {
        position = v.*;
    }
}

pub fn worldPositionToScreenPosition(world_position: rl.Vector2) rl.Vector2 {
    const x = GetX: {
        var _x: f32 = window.size.x / 2;
        _x += world_position.x;
        _x -= position.x;
        break :GetX _x;
    };

    const y = GetX: {
        var _y: f32 = window.size.y / 2;
        _y += world_position.y;
        _y -= position.y;
        break :GetX _y;
    };

    return rl.Vector2.init(x, y);
}
