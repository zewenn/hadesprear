const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.zig");

pub const Transofrm = struct {
    position: rl.Vector2,
    rotation: rl.Vector3,
    scale: rl.Vector2,
};

pub const Display = struct {
    pub const scalings = enum {
        pixelate,
        normal,
    };

    sprite: []const u8,
    scaling: scalings,
};
