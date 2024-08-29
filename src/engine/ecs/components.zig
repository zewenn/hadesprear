const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.zig");

pub const Transform = struct {
    const Self = @This();

    position: rl.Vector2,
    rotation: rl.Vector3,
    scale: rl.Vector2,

    pub fn equals(self: *Self, other: Self) bool {
        if (self.position.equals(other.position) > 0) return false;
        if (self.rotation.equals(other.rotation) > 0) return false;
        if (self.scale.equals(other.scale) > 0) return false;

        return true;
    }
};

pub const Display = struct {
    pub const scalings = enum {
        pixelate,
        normal,
    };

    sprite: []const u8,
    scaling: scalings,
};
