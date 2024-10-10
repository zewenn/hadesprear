const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.m.zig");

pub const Transform = struct {
    const Self = @This();

    position: rl.Vector2 = rl.Vector2.init(0, 0),
    rotation: rl.Vector3 = rl.Vector3.init(0, 0, 0),
    scale: rl.Vector2 = rl.Vector2.init(64, 64),
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
    trigger: bool = false,
    rect: rl.Rectangle,
    weight: f32,
    dynamic: bool,
};

pub const CachedDisplay = struct {
    const Self = @This();

    display: Display,
    transform: Transform,
    img: ?rl.Image,
    texture: ?rl.Texture,

    pub fn init(display: Display, transform: Transform, img: rl.Image, texture: rl.Texture) Self {
        return Self{
            .display = display,
            .transform = transform,
            .img = img,
            .texture = texture,
        };
    }
};

pub const RectangleVertices = struct {
    const Self = @This();

    transform: *Transform,

    PC: rl.Vector2,
    P0: rl.Vector2,
    P1: rl.Vector2,
    P2: rl.Vector2,
    P3: rl.Vector2,
    delta_P0: rl.Vector2,
    delta_P1: rl.Vector2,
    delta_P2: rl.Vector2,
    delta_P3: rl.Vector2,

    x_min: f32 = 0,
    x_max: f32 = 0,

    y_min: f32 = 0,
    y_max: f32 = 0,

    pub fn init(transform: *Transform, collider: *Collider) Self {
        const PC = rl.Vector2.init(
            transform.position.x + transform.scale.x / 2 - collider.rect.width / 2,
            transform.position.y + transform.scale.y / 2 - collider.rect.height / 2,
        );
        const delta_P0 = rl.Vector2
            .init(-collider.rect.width / 2, -collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const delta_P1 = rl.Vector2
            .init(collider.rect.width / 2, -collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const delta_P2 = rl.Vector2
            .init(-collider.rect.width / 2, collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const delta_P3 = rl.Vector2
            .init(collider.rect.width / 2, collider.rect.height / 2)
            .rotate(std.math.degreesToRadians(transform.rotation.z));

        const P0 = PC.add(delta_P0);
        const P1 = PC.add(delta_P1);
        const P2 = PC.add(delta_P2);
        const P3 = PC.add(delta_P3);

        const x_min: f32 = @min(@min(P0.x, P1.x), @min(P2.x, P3.x));
        const x_max: f32 = @max(@max(P0.x, P1.x), @max(P2.x, P3.x));

        const y_min: f32 = @min(@min(P0.y, P1.y), @min(P2.y, P3.y));
        const y_max: f32 = @max(@max(P0.y, P1.y), @max(P2.y, P3.y));

        return Self{
            .transform = transform,
            .PC = PC,
            .P0 = P0,
            .P1 = P1,
            .P2 = P2,
            .P3 = P3,
            .delta_P0 = delta_P0,
            .delta_P1 = delta_P1,
            .delta_P2 = delta_P2,
            .delta_P3 = delta_P3,
            .x_min = x_min,
            .x_max = x_max,
            .y_min = y_min,
            .y_max = y_max,
        };
    }

    pub fn recalculateXYMinMax(self: *Self) void {
        self.x_min = @min(@min(self.P0.x, self.P1.x), @min(self.P2.x, self.P3.x));
        self.x_max = @max(@max(self.P0.x, self.P1.x), @max(self.P2.x, self.P3.x));
        self.y_min = @min(@min(self.P0.y, self.P1.y), @min(self.P2.y, self.P3.y));
        self.y_max = @max(@max(self.P0.y, self.P1.y), @max(self.P2.y, self.P3.y));
    }

    pub fn recalculatePoints(self: *Self) void {
        self.P0 = self.PC.add(self.delta_P0);
        self.P1 = self.PC.add(self.delta_P1);
        self.P2 = self.PC.add(self.delta_P2);
        self.P3 = self.PC.add(self.delta_P3);
    }

    pub fn overlaps(self: *Self, other: Self) bool {
        if ((self.x_max > other.x_min and self.x_min < other.x_max) and
            (self.y_max > other.y_min and self.y_min < other.y_max))
            return true;
        return false;
    }

    pub fn pushback(a: *Self, b: Self, weight: f32) void {
        const overlap_x = @min(a.x_max - b.x_min, b.x_max - a.x_min);
        const overlap_y = @min(a.y_max - b.y_min, b.y_max - a.y_min);

        switch (overlap_x < overlap_y) {
            true => PushBack_X: {
                if (a.x_max > b.x_min and a.x_max < b.x_max) {
                    a.transform.position.x -= overlap_x * weight;
                    break :PushBack_X;
                }

                a.transform.position.x += overlap_x * weight;
                break :PushBack_X;
            },
            false => PushBack_Y: {
                if (a.y_max > b.y_min and a.y_max < b.y_max) {
                    a.transform.position.y -= overlap_y * weight;
                    break :PushBack_Y;
                }

                a.transform.position.y += overlap_y * weight;
                break :PushBack_Y;
            },
        }
    }
};
