const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

const projectiles = @import("projectiles.zig");

var Player = e.entities.Entity{
    .id = "Player",
    .tags = "player",
    .transform = e.entities.Transform.new(),
    .display = .{
        .scaling = .pixelate,
        .sprite = "player_left_0.png",
    },
    .shooting_stats = .{
        .timeout = 0.25,
    },
};

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    try e.entities.register(&Player);

    e.camera.follow(&Player.transform.position);
}

pub fn init() !void {}

pub fn update() !void {
    const mouse_pos = e.input.mouse_position;
    const mouse_rotation: f32 = std.math.radiansToDegrees(
        std.math.atan2(
            mouse_pos.y - e.window.size.y / 2,
            mouse_pos.x - e.window.size.x / 2,
        ),
    );

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

    const shoot_angle = switch (e.input.input_mode) {
        .KeyboardAndMouse => mouse_rotation,
        .Keyboard => GetRot: {
            var rot_vector = e.Vec2(0, 0);

            if (e.isKeyDown(.key_up)) {
                rot_vector.y -= 1;
            }
            if (e.isKeyDown(.key_down)) {
                rot_vector.y += 1;
            }
            if (e.isKeyDown(.key_left)) {
                rot_vector.x -= 1;
            }
            if (e.isKeyDown(.key_right)) {
                rot_vector.x += 1;
            }

            const norm_rot = rot_vector.normalize();
            break :GetRot std.math.radiansToDegrees(
                std.math.atan2(norm_rot.y, norm_rot.x),
            );
        },
    };

    const shoot = (
    //
        (e.isKeyPressed(.key_up) or
        e.isKeyPressed(.key_down) or
        e.isKeyPressed(.key_left) or
        e.isKeyPressed(.key_right)) and
        e.input.input_mode == .Keyboard
    //
    ) or (
    //
        e.isMouseButtonPressed(.mouse_button_left)
    //
    );

    if (shoot and Player.shooting_stats.?.timeout_end < e.time.currentTime) {
        try projectiles.new(Player.transform.position, .{
            .direction = shoot_angle,
            .lifetime_end = e.time.currentTime + 5,
            .scale = e.Vec2(64, 64),
            .side = .player,
            .speed = 100,
        });

        Player.shooting_stats.?.timeout_end = e.time.currentTime + Player.shooting_stats.?.timeout;
    }
}

pub fn deinit() !void {
    e.entities.delete(Player.id);
    Player.freeRaylibStructs();
}
