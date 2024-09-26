const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

const projectiles = @import("projectiles.zig");
const enemies = @import("enemies.zig");

var Player = e.entities.Entity{
    .id = "Player",
    .tags = "player",
    .transform = e.entities.Transform.new(),
    .display = .{
        .scaling = .pixelate,
        .sprite = "player_left_0.png",
    },
    .shooting_stats = .{
        .timeout = 0.2,
    },
    .collider = .{
        .dynamic = true,
        .rect = e.Rectangle.init(0, 0, 64, 64),
        .weight = 1,
    },
};

var player_animator: e.Animator = undefined;

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    try e.entities.register(&Player);

    player_animator = e.Animator.init(&e.ALLOCATOR, &Player);
    {
        var walk_left_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "walk_left",
            e.Animator.interpolation.ease_in_out,
            0.25,
        );

        walk_left_anim.chain(
            0,
            .{
                .rotation = 0,
                .sprite = "player_left_0.png",
            },
        );
        walk_left_anim.chain(
            50,
            .{
                .rotation = -5,
                .sprite = "player_left_1.png",
            },
        );
        walk_left_anim.chain(
            100,
            .{
                .rotation = 0,
                .sprite = "player_left_0.png",
            },
        );

        try player_animator.chain(walk_left_anim);
    }
    {
        var walk_right_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "walk_right",
            e.Animator.interpolation.ease_in_out,
            0.25,
        );

        walk_right_anim.chain(
            0,
            .{
                .rotation = 0,
                .sprite = "player_right_0.png",
            },
        );
        walk_right_anim.chain(
            50,
            .{
                .rotation = 5,
                .sprite = "player_right_1.png",
            },
        );
        walk_right_anim.chain(
            100,
            .{
                .rotation = 0,
                .sprite = "player_right_0.png",
            },
        );

        try player_animator.chain(walk_right_anim);
    }

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
    if (e.isKeyPressed(.key_f)) {
        try enemies.spawn();
    }

    const norm_vector = move_vector.normalize();
    Player.transform.position.x += norm_vector.x * 350 * @as(f32, @floatCast(e.time.deltaTime));
    Player.transform.position.y += norm_vector.y * 350 * @as(f32, @floatCast(e.time.deltaTime));

    Animator: {
        player_animator.update();

        if (move_vector.x < 0 and !player_animator.isPlaying("walk_left")) {
            player_animator.stop("walk_right");
            try player_animator.play("walk_left");

            Player.facing = .left;
        }
        if (move_vector.x > 0 and !player_animator.isPlaying("walk_right")) {
            player_animator.stop("walk_left");
            try player_animator.play("walk_right");

            Player.facing = .right;
        }

        if (move_vector.y == 0) break :Animator;

        if (player_animator.isPlaying("walk_left") or player_animator.isPlaying("walk_right")) break :Animator;

        try player_animator.play(
            switch (Player.facing) {
                .left => "walk_left",
                .right => "walk_right",
            },
        );
    }

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

    const shoot_heavy = ((shoot and e.isKeyDown(.key_left_shift)) or
        e.isMouseButtonPressed(.mouse_button_right));

    if (Player.shooting_stats.?.timeout_end >= e.time.currentTime) return;

    if (shoot_heavy) {
        try projectiles.new(Player.transform.position, .{
            .direction = shoot_angle,
            .lifetime_end = e.time.currentTime + 5,
            .scale = e.Vec2(64, 64),
            .side = .player,
            .weight = .heavy,
            .speed = 100,
        });

        Player.shooting_stats.?.timeout_end = e.time.currentTime + (Player.shooting_stats.?.timeout * 2);
    } else if (shoot) {
        try projectiles.new(Player.transform.position, .{
            .direction = shoot_angle,
            .lifetime_end = e.time.currentTime + 5,
            .scale = e.Vec2(64, 64),
            .side = .player,
            .weight = .light,
            .speed = 100,
        });

        Player.shooting_stats.?.timeout_end = e.time.currentTime + Player.shooting_stats.?.timeout;
    }
}

pub fn deinit() !void {
    player_animator.deinit();
    e.entities.delete(Player.id);
    Player.freeRaylibStructs();
}
