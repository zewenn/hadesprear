const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

var Player = e.entities.Entity{
    .id = "Player",
    .tags = "player",
    .transform = e.entities.Transform.new(),
    .display = .{
        .scaling = .pixelate,
        .sprite = "player_left_0.png",
    },
    .collider = null,
};

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    try e.entities.register(&Player);
}

pub fn init() !void {}

pub fn update() !void {
    var move_vector = e.Vec2(0, 0);

    if (e.isKeyDown(.key_w)) {
        move_vector.y -= 1;
    }
    if (e.isKeyDown(.key_s)) {
        move_vector.y += 1;
    }
    if (e.isKeyDown(.key_a)) {
        move_vector.x -= 1;
    }
    if (e.isKeyDown(.key_d)) {
        move_vector.x += 1;
    }

    const norm_vector = move_vector.normalize();
    Player.transform.position.x += norm_vector.x * 350 * @as(f32, @floatCast(e.time.deltaTime));
    Player.transform.position.y += norm_vector.y * 350 * @as(f32, @floatCast(e.time.deltaTime));
}

pub fn deinit() !void {}
