const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

const projectiles = @import("projectiles.zig");
const enemies = @import("enemies.zig");
const dashing = @import("dashing.zig");

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
        .scale = e.Vec2(48, 48),
    },
    .display = .{
        .scaling = .pixelate,
        .sprite = "sprites/icons/empty.png",
    },
};

var player_animator: e.Animator = undefined;
var hand0_animator: e.Animator = undefined;
var hand1_animator: e.Animator = undefined;

const weapons = struct {
    var gloves: Weapon = undefined;
    var plates: Weapon = undefined;

    var current: ?*Weapon = null;

    pub fn equip(weapon: *Weapon) void {
        current = weapon;
        Hand0.display.sprite = current.?.sprites.left;
        Hand1.display.sprite = current.?.sprites.right;
    }

    const types = enum {
        gloves,
        plates,
    };

    const Sprites = struct {
        left: []const u8,
        right: []const u8,
    };

    const Weapon = struct {
        const Self = @This();

        type: types,
        sprites: Sprites,
        damage: f32,
        heavy_damage_multiplier: f32 = 1.5,
        speed: f32 = 100,
        scale: e.Vector2,

        pub fn init(
            T: types,
            sprites: Sprites,
            damage: f32,
            scale: e.Vector2,
        ) Self {
            return Self{
                .type = T,
                .sprites = sprites,
                .damage = damage,
                .scale = scale,
            };
        }

        pub fn deinit(self: *Self) void {
            e.ALLOCATOR.free(self.sprites.left);
            e.ALLOCATOR.free(self.sprites.right);
        }

        pub fn equip(self: *Self) void {
            weapons.equip(self);
        }

        pub fn deequip(self: *Self) void {
            if (!e.z.eql(self, current)) return;
            current = null;
        }
    };

    fn getSideSpecificSprite(
        middle: []const u8,
        side: enum { left, right },
        ext: []const u8,
    ) ![]u8 {
        var final_zS = e.zString.init(e.ALLOCATOR);
        defer final_zS.deinit();

        try final_zS.concat("sprites/entity/player/weapons/");
        try final_zS.concat(middle);
        try final_zS.concat("/");
        try final_zS.concat(switch (side) {
            .left => "left",
            .right => "right",
        });
        try final_zS.concat(ext);

        return (try final_zS.toOwned()).?;
    }

    /// Returned Sprites object conntains heap allocated
    /// string slices which will be automatically freed
    /// when `Weapon.deinit()` is called
    pub fn getSprites(T: types) !Sprites {
        const middle_string: []const u8 = switch (T) {
            .gloves => "gloves",
            .plates => "plates",
        };
        const fileext = ".png";

        return Sprites{
            .left = try getSideSpecificSprite(
                middle_string,
                .left,
                fileext,
            ),
            .right = try getSideSpecificSprite(
                middle_string,
                .right,
                fileext,
            ),
        };
    }
};

fn playAttackAnimation(cw: *weapons.Weapon) !void {
    switch (cw.type) {
        .gloves => {
            hand0_animator.stop("hit_plates");
            hand1_animator.stop("hit_plates");
            try hand0_animator.play("hit_gloves");
            try e.setTimeout(
                0.075,
                struct {
                    pub fn cb() !void {
                        try hand1_animator.play("hit_gloves");
                    }
                }.cb,
            );
        },
        .plates => {
            hand0_animator.stop("hit_gloves");
            hand1_animator.stop("hit_gloves");
            try hand0_animator.play("hit_plates");
            try hand1_animator.play("hit_plates");
        },
    }
}

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

var mouse_rotation: f32 = 0;

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

    hand0_animator = e.Animator.init(&e.ALLOCATOR, &Hand0);
    {
        {
            var hit_gloves = e.Animator.Animation.init(
                &e.ALLOCATOR,
                "hit_gloves",
                e.Animator.interpolation.ease_out,
                0.25,
            );
            {
                hit_gloves.chain(
                    1,
                    .{
                        .y = 0,
                    },
                );
                hit_gloves.chain(
                    2,
                    .{
                        .y = HIT_GLOVE_DISTANCE,
                    },
                );
                hit_gloves.chain(
                    3,
                    .{
                        .y = 0,
                    },
                );
            }
            try hand0_animator.chain(hit_gloves);
        }
        {
            var hit_plates = e.Animator.Animation.init(
                &e.ALLOCATOR,
                "hit_plates",
                e.Animator.interpolation.ease_out,
                0.25,
            );
            {
                hit_plates.chain(
                    1,
                    .{
                        .rotation = 0,
                    },
                );
                hit_plates.chain(
                    2,
                    .{
                        .rotation = -HIT_PLATES_ROTATION,
                    },
                );
                hit_plates.chain(
                    3,
                    .{
                        .rotation = 0,
                    },
                );
            }
            try hand0_animator.chain(hit_plates);
        }
    }

    hand1_animator = e.Animator.init(&e.ALLOCATOR, &Hand1);
    {
        {
            var hit_gloves = e.Animator.Animation.init(
                &e.ALLOCATOR,
                "hit_gloves",
                e.Animator.interpolation.ease_out,
                0.25,
            );
            {
                hit_gloves.chain(
                    1,
                    .{
                        .y = 0,
                    },
                );
                hit_gloves.chain(
                    2,
                    .{
                        .y = HIT_GLOVE_DISTANCE,
                    },
                );
                hit_gloves.chain(
                    3,
                    .{
                        .y = 0,
                    },
                );
            }
            try hand1_animator.chain(hit_gloves);
        }
        {
            var hit_plates = e.Animator.Animation.init(
                &e.ALLOCATOR,
                "hit_plates",
                e.Animator.interpolation.ease_out,
                0.25,
            );
            {
                hit_plates.chain(
                    1,
                    .{
                        .rotation = 0,
                    },
                );
                hit_plates.chain(
                    2,
                    .{
                        .rotation = HIT_PLATES_ROTATION,
                    },
                );
                hit_plates.chain(
                    3,
                    .{
                        .rotation = 0,
                    },
                );
            }
            try hand1_animator.chain(hit_plates);
        }
    }

    weapons.gloves = weapons.Weapon{
        .type = .gloves,
        .sprites = try weapons.getSprites(.gloves),
        .damage = 20,
        .scale = e.Vec2(32, 64),
        .speed = 275,
    };
    weapons.plates = weapons.Weapon{
        .type = .plates,
        .sprites = try weapons.getSprites(.plates),
        .damage = 20,
        .scale = e.Vec2(64, 64),
        .speed = 200,
    };

    e.camera.follow(&Player.transform.position);
}

pub fn init() !void {
    weapons.plates.equip();
}

pub fn update() !void {
    if (e.input.ui_mode) return;

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

        if (weapons.current == null) break :Input;
        const cw = weapons.current.?;
        if (e.isKeyPressed(.key_tab)) {
            switch (cw.type) {
                .gloves => weapons.plates.equip(),
                .plates => weapons.gloves.equip(),
            }

            try playAttackAnimation(weapons.current.?);
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

        if (Player.shooting_stats.?.timeout_end >= e.time.currentTime) break :Input;

        if (shoot_heavy) {
            try projectiles.new(Player.transform.position, .{
                .direction = shoot_angle,
                .lifetime_end = e.time.currentTime + PROJECTILE_LIFETIME,
                .scale = cw.scale,
                .side = .player,
                .weight = .heavy,
                .speed = cw.speed,
                .damage = Player.entity_stats.?.damage +
                    cw.damage *
                    cw.heavy_damage_multiplier,
            });

            Player.shooting_stats.?.timeout_end = e.time.currentTime + (Player.shooting_stats.?.timeout * 2);
        } else if (shoot) {
            try projectiles.new(Player.transform.position, .{
                .direction = shoot_angle,
                .lifetime_end = e.time.currentTime + PROJECTILE_LIFETIME,
                .scale = cw.scale,
                .side = .player,
                .weight = .light,
                .speed = cw.speed,
                .damage = Player.entity_stats.?.damage + cw.damage,
            });

            Player.shooting_stats.?.timeout_end = e.time.currentTime + Player.shooting_stats.?.timeout;
        }

        if (shoot or shoot_heavy) {
            try playAttackAnimation(weapons.current.?);
        }

        break :Input;
    }

    Animator: {
        player_animator.update();
        hand0_animator.update();
        hand1_animator.update();

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
    if (hand0_animator.isPlaying("hit_gloves")) {
        rotator_vector0.x += Hand0.transform.position.y;
    }

    const finished0 = rotator_vector0.rotate(std.math.degreesToRadians(90)).negate();

    var rotator_vector1 = e.Vector2.init(HAND_DISTANCE, 0);
    if (hand1_animator.isPlaying("hit_gloves")) {
        rotator_vector1.x += Hand1.transform.position.y;
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
        var rot = rotation;
        if (weapons.current) |cw| {
            if (cw.type == .plates) rot += 20;
        }

        if (!hand0_animator.isPlaying("hit_plates")) break :GetRotation rot;

        break :GetRotation rot + Hand0.transform.rotation.z;
    };
    Hand1.transform.position = .{
        .x = Player.transform.position.x + 0,
        .y = Player.transform.position.y + 0,
    };
    Hand1.transform.rotation.z = GetRotation: {
        var rot = rotation;
        if (weapons.current) |cw| {
            if (cw.type == .plates) rot -= 20;
        }

        if (!hand1_animator.isPlaying("hit_plates")) break :GetRotation rot;

        break :GetRotation rot + Hand1.transform.rotation.z;
    };
}

pub fn deinit() !void {
    player_animator.deinit();
    hand0_animator.deinit();
    hand1_animator.deinit();

    e.entities.delete(Player.id);
    Player.freeRaylibStructs();

    weapons.plates.deinit();
    weapons.gloves.deinit();
}
