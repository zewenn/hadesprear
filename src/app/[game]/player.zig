const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

const projectiles = @import("projectiles.zig");
const enemies = @import("enemies.zig");
const dashing = @import("dashing.zig");
const inventory = @import("inventory.zig");
const weapons = @import("weapons.zig");

const HAND_DISTANCE: comptime_float = 24;
const HIT_GLOVE_DISTANCE: f32 = 45;
const HIT_PLATES_ROTATION: f32 = 42.5;
const PROJECTILE_LIFETIME: comptime_float = 2;

const WALK_LEFT_0 = "sprites/entity/player/left_0.png";
const WALK_LEFT_1 = "sprites/entity/player/left_1.png";
const WALK_RIGHT_0 = "sprites/entity/player/right_0.png";
const WALK_RIGHT_1 = "sprites/entity/player/right_1.png";

pub var Player = e.entities.Entity{
    .id = "Player",
    .tags = "player",
    .transform = e.entities.Transform.new(),
    .display = .{
        .scaling = .pixelate,
        .sprite = WALK_LEFT_0,
    },
    .shooting_stats = .{
        .timeout = 0.2,
    },
    .collider = .{
        .dynamic = true,
        .rect = e.Rectangle.init(0, 0, 64, 64),
        .weight = 1,
    },

    .entity_stats = .{
        .can_move = true,
    },
    .dash_modifiers = .{
        .dash_time = 0.25,
    },
};

pub var Hand0 = e.entities.Entity{
    .id = "Hand0",
    .tags = "hand",
    .transform = e.entities.Transform{
        .scale = e.Vec2(48, 48),
    },
    .display = .{
        .scaling = .pixelate,
        .sprite = "sprites/icons/empty.png",
    },
};

pub var Hand1 = e.entities.Entity{
    .id = "Hand1",
    .tags = "hand",
    .transform = e.entities.Transform{
        .position = e.Vec2(0, 64),
        .scale = e.Vec2(96, 256),
    },
    .display = .{
        .scaling = .pixelate,
        .sprite = "sprites/icons/empty.png",
    },
};

var player_animator: e.Animator = undefined;
var hands: weapons.Hands = undefined;

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

var mouse_rotation: f32 = 0;

fn summonProjectiles(
    T: enum {
        light,
        heavy,
        dash,
    },
    shoot_angle: f32,
) !void {
    if (Player.shooting_stats.?.timeout_end >= e.time.gameTime) return;
    const strct = switch (T) {
        .dash => inventory.equippedbar.current_weapon.weapon_dash,
        .heavy => inventory.equippedbar.current_weapon.weapon_heavy,

        else => inventory.equippedbar.current_weapon.weapon_light,
    };

    for (strct.projectile_array) |pa| {
        const plus_angle: f32 = if (pa) |p| p else continue;

        try projectiles.new(Player.transform.position, .{
            .direction = shoot_angle + plus_angle,
            .lifetime_end = e.time.gameTime +
                strct.projectile_lifetime,
            .scale = strct.projectile_scale,
            .side = .player,
            .weight = .heavy,
            .speed = strct.projectile_speed,
            .damage = Player.entity_stats.?.damage +
                inventory.equippedbar.get(.damage) *
                strct.multiplier,
            .health = strct.projectile_health,
            .bleed_per_second = strct.projectile_bps,
            .sprite = strct.sprite,
        });
    }

    Player.shooting_stats.?.timeout_end = e.time.gameTime + (inventory.equippedbar.current_weapon.attack_speed * strct.attack_speed_modifier);
}

// ===================== [Events] =====================

pub fn awake() !void {
    try e.entities.register(&Player);

    player_animator = e.Animator.init(&e.ALLOCATOR, &Player);
    {
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
                    .sprite = WALK_LEFT_0,
                },
            );
            walk_left_anim.chain(
                50,
                .{
                    .rotation = -5,
                    .sprite = WALK_LEFT_1,
                },
            );
            walk_left_anim.chain(
                100,
                .{
                    .rotation = 0,
                    .sprite = WALK_LEFT_0,
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
                    .sprite = WALK_RIGHT_0,
                },
            );
            walk_right_anim.chain(
                50,
                .{
                    .rotation = 5,
                    .sprite = WALK_RIGHT_1,
                },
            );
            walk_right_anim.chain(
                100,
                .{
                    .rotation = 0,
                    .sprite = WALK_RIGHT_0,
                },
            );

            try player_animator.chain(walk_right_anim);
        }
    }

    try e.entities.register(&Hand0);
    try e.entities.register(&Hand1);

    hands = try weapons.Hands.init(
        &e.ALLOCATOR,
        &Hand0,
        &Hand1,
    );

    e.camera.follow(&Player.transform.position);
}

pub fn init() !void {}

pub fn update() !void {
    if (e.isKeyDown(.key_seven)) e.display.camera.zoom -= 0.01;
    if (e.isKeyDown(.key_eight)) e.display.camera.zoom += 0.01;


    if (e.input.ui_mode) return;
    hands.equip(inventory.equippedbar.current_weapon);

    const mouse_pos = e.input.mouse_position;
    const mouse_relative_pos = e.Vec2(
        mouse_pos.x - e.window.size.x / 2,
        mouse_pos.y - e.window.size.y / 2,
    );

    if (e.input.input_mode == .KeyboardAndMouse) {
        mouse_rotation = std.math.radiansToDegrees(
            std.math.atan2(
                mouse_relative_pos.y,
                mouse_relative_pos.x,
            ),
        );
    }

    var move_vector = e.Vec2(0, 0);
    Input: {
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

        if (Player.entity_stats.?.can_move) {
            Player.transform.position.x += norm_vector.x * 350 * @as(f32, @floatCast(e.time.deltaTime));
            Player.transform.position.y += norm_vector.y * 350 * @as(f32, @floatCast(e.time.deltaTime));
        }

        if (e.isKeyPressed(.key_space)) {
            try dashing.applyDash(
                &Player,
                std.math.radiansToDegrees(
                    std.math.atan2(
                        move_vector.y,
                        move_vector.x,
                    ),
                ),
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

        if (shoot and e.input.input_mode == .Keyboard) {
            mouse_rotation = shoot_angle;
        }

        const shoot_heavy = ((shoot and e.isKeyDown(.key_left_shift)) or
            e.isMouseButtonPressed(.mouse_button_right));

        if (Player.shooting_stats.?.timeout_end >= e.time.gameTime) break :Input;

        if (shoot_heavy) {
            try summonProjectiles(.heavy, shoot_angle);
            try hands.play(.heavy);

            break :Input;
        }

        if (Player.dash_modifiers.?.dash_end + 0.1 >= e.time.gameTime and shoot) {
            try summonProjectiles(.dash, shoot_angle);
            try hands.play(.dash);

            break :Input;
        }

        if (shoot) {
            try summonProjectiles(.light, shoot_angle);
            try hands.play(.light);
        }

        break :Input;
    }

    Animator: {
        player_animator.update();
        hands.update();

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

    var rotator_vector0 = e.Vector2.init(HAND_DISTANCE, Hand0.transform.scale.x);
    if (hands.playing_left) {
        rotator_vector0.x += Hand0.transform.rotation.y;
        rotator_vector0.y += Hand0.transform.rotation.x;
    }

    const finished0 = rotator_vector0.rotate(std.math.degreesToRadians(90)).negate();

    var rotator_vector1 = e.Vector2.init(HAND_DISTANCE, 0);
    if (hands.playing_right) {
        rotator_vector1.x += Hand1.transform.rotation.y;
        rotator_vector1.y += Hand1.transform.rotation.x;
    }

    const finished1 = rotator_vector1.rotate(std.math.degreesToRadians(90)).negate();

    Hand0.transform.anchor = finished0;
    Hand1.transform.anchor = finished1;

    const rotation: f32 = mouse_rotation - 90;

    Hand0.transform.position = .{
        .x = Player.transform.position.x,
        .y = Player.transform.position.y,
    };
    Hand0.transform.rotation.z = GetRotation: {
        if (!hands.playing_left) break :GetRotation rotation + hands.left_base_rotation;

        break :GetRotation rotation + Hand0.transform.rotation.z + hands.left_base_rotation;
    };
    Hand1.transform.position = .{
        .x = Player.transform.position.x + 0,
        .y = Player.transform.position.y + 0,
    };
    Hand1.transform.rotation.z = GetRotation: {
        if (!hands.playing_right) break :GetRotation rotation + hands.right_base_rotation;

        break :GetRotation rotation + Hand1.transform.rotation.z + hands.right_base_rotation;
    };
}

pub fn deinit() !void {
    player_animator.deinit();
    hands.deinit();

    e.entities.delete(Player.id);
    Player.freeRaylibStructs();
}
