const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.zig");

pub const Transform = struct {
    const Self = @This();

    position: rl.Vector2,
    rotation: rl.Vector3,
    scale: rl.Vector2,
    anchor: ?rl.Vector2 = null,

    pub fn equals(self: *Self, other: Self) bool {
        if (self.position.equals(other.position) > 0) return false;
        if (self.rotation.equals(other.rotation) > 0) return false;
        if (self.scale.equals(other.scale) > 0) return false;

        return true;
    }

    pub fn rotate(self: *Self, by: f32) void {
        const scale = 359 + 360;
        var new_rot: f32 = self.rotation.z + by;

        if (new_rot > 360) {
            const rem: f32 = @rem(new_rot - 360, scale);
            new_rot = @as(f32, -359) + rem;
        }
        if (new_rot < -359) {
            const rem: f32 = @rem(new_rot + 359, scale);
            new_rot = @as(f32, 360) - rem;
        }

        self.rotation.z = new_rot;
    }
};

pub const Display = struct {
    pub const scalings = enum {
        pixelate,
        normal,
    };

    sprite: []const u8,
    scaling: scalings = .normal,
    tint: rl.Color = rl.Color.white,
};

pub const Collider = struct {
    rect: rl.Rectangle,
    weight: f32,
    dynamic: bool,
};
