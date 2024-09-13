const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const rl = @import("raylib");
const z = Import(.z);

pub const Transform = struct {
    const Self = @This();

    position: rl.Vector2,
    rotation: rl.Vector3,
    scale: rl.Vector2,
    anchor: ?rl.Vector2 = null,

    /// Creates a new transform with 64x64 `scale` and everything else set to 0.
    pub fn new() Self {
        return Self{
            .position = rl.Vector2.init(0, 0),
            .rotation = rl.Vector3.init(0, 0, 0),
            .scale = rl.Vector2.init(64, 64),
            .anchor = null,
        };
    }

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

    pub fn getRect(self: *Self) rl.Rectangle {
        return rl.Rectangle.init(
            if (self.anchor) |anchor| self.position.x - anchor.x else self.position.x,
            if (self.anchor) |anchor| self.position.y - anchor.y else self.position.y,
            self.scale.x,
            self.scale.y,
        );
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
    ignore_world_pos: bool = false,
};

pub const Collider = struct {
    rect: rl.Rectangle,
    weight: f32,
    dynamic: bool,
};
