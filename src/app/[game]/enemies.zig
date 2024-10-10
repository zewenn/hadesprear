const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const e = @import("../../engine/engine.m.zig");

var Player: ?*e.entities.Entity = null;

const EnemyStruct = struct {
    entity: e.entities.Entity,
    animator: ?e.Animator = null,
};

const manager = e.zlib.HeapManager(EnemyStruct, (struct {
    pub fn callback(alloc: Allocator, item: *EnemyStruct) !void {
        e.entities.delete(item.entity.id);
        alloc.free(item.entity.id);

        if (item.animator) |*animator| {
            animator.deinit();
        }
    }
}).callback);

const dashing = @import("dashing.zig");
const projectiles = @import("projectiles.zig");

const MELEE_WALK_LEFT_SPRITE_0 = "sprites/entity/enemies/melee/left_0.png";
const MELEE_WALK_LEFT_SPRITE_1 = "sprites/entity/enemies/melee/left_1.png";
const MELEE_WALK_RIGHT_SPRITE_0 = "sprites/entity/enemies/melee/right_0.png";
const MELEE_WALK_RIGHT_SPRITE_1 = "sprites/entity/enemies/melee/right_1.png";

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
}

pub fn init() !void {
    Player = e.entities.get("Player").?;
}

pub fn update() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        var entity_ptr = &(item.entity);

        const entity_flag: bool = Get: {
            if (entity_ptr.entity_stats == null) break :Get false;
            if (!entity_ptr.entity_stats.?.is_enemy) break :Get false;
            break :Get true;
        };

        if (!entity_flag) {
            std.log.err("Enemy without projectile data!", .{});
            std.log.err("Removing...", .{});

            manager.remove(item);
            continue;
        }

        if (entity_ptr.entity_stats.?.health <= 0) {
            manager.removeFreeId(item);
            continue;
        }

        if (!e.entities.exists(entity_ptr.id)) {
            try e.entities.register(entity_ptr);

            item.animator = e.Animator.init(
                &e.ALLOCATOR,
                entity_ptr,
            );

            var animator = &(item.animator.?);
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
                        .sprite = MELEE_WALK_LEFT_SPRITE_0,
                    },
                );
                walk_left_anim.chain(
                    50,
                    .{
                        .rotation = -5,
                        .sprite = MELEE_WALK_LEFT_SPRITE_1,
                    },
                );
                walk_left_anim.chain(
                    100,
                    .{
                        .rotation = 0,
                        .sprite = MELEE_WALK_LEFT_SPRITE_0,
                    },
                );

                try animator.chain(walk_left_anim);
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
                        .sprite = MELEE_WALK_RIGHT_SPRITE_0,
                    },
                );
                walk_right_anim.chain(
                    50,
                    .{
                        .rotation = 5,
                        .sprite = MELEE_WALK_RIGHT_SPRITE_1,
                    },
                );
                walk_right_anim.chain(
                    100,
                    .{
                        .rotation = 0,
                        .sprite = MELEE_WALK_RIGHT_SPRITE_0,
                    },
                );

                try animator.chain(walk_right_anim);
            }
        }

        var animator = &(item.animator.?);
        animator.update();

        if (!animator.isPlaying("walk_right"))
            try animator.play("walk_right");

        const action = std.crypto.random.intRangeLessThanBiased(
            u32,
            0,
            @intFromFloat(200_000 * e.time.deltaTime),
        );

        const distance_vec = Player.?.transform.position
            .subtract(entity_ptr.transform.position);

        const distance: f32 = distance_vec.length();

        const move_vec = distance_vec
            .normalize();

        const angle = std.math.radiansToDegrees(
            std.math.atan2(
                move_vec.y,
                move_vec.x,
            ),
        );

        switch (action) {
            // Apply dash
            1 => {
                const direction: f32 = angle + @as(
                    f32,
                    @floatFromInt(
                        std.crypto.random.intRangeLessThanBiased(
                            i32,
                            -90,
                            90,
                        ),
                    ),
                );
                try dashing.applyDash(
                    entity_ptr,
                    (direction),
                );
            },
            else => {},
        }

        if (entity_ptr.entity_stats.?.can_move) {
            entity_ptr.transform.position.x += move_vec.x * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
            entity_ptr.transform.position.y += move_vec.y * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
        }

        if (entity_ptr.shooting_stats.?.timeout_end >= e.time.gameTime) continue;

        if (distance < entity_ptr.entity_stats.?.range) {
            try projectiles.new(entity_ptr.transform.position, .{
                .direction = angle,
                .lifetime_end = e.time.gameTime + entity_ptr.shooting_stats.?.projectile_lifetime,
                .scale = e.Vec2(64, 64),
                .side = .enemy,
                .weight = .light,
                .speed = 350,
                .damage = entity_ptr.entity_stats.?.damage,
                .sprite = "sprites/projectiles/enemy/generic/light.png",
            });

            entity_ptr.shooting_stats.?.timeout_end = e.time.gameTime + entity_ptr.shooting_stats.?.timeout;
        }
        // entity_ptr.entity_stats.?.health -= 0.1;
    }
}

pub fn deinit() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        manager.removeFreeId(item);
    }
    manager.deinit();
}

pub fn spawn() !void {
    const id_o = e.uuid.urn.serialize(e.uuid.v7.new());
    // std.log.debug("id: {s}", .{id});

    const id = try e.ALLOCATOR.alloc(u8, 36);
    std.mem.copyForwards(u8, id, &id_o);

    const New = e.entities.Entity{
        .id = id,
        .tags = "enemy",
        .transform = .{
            .rotation = e.Vector3.init(0, 0, 0),
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = MELEE_WALK_LEFT_SPRITE_0,
        },
        .entity_stats = .{
            .is_enemy = true,
            .can_move = true,
        },
        .dash_modifiers = .{
            .dash_time = 0.25,
        },
        .collider = .{
            .dynamic = true,
            .rect = e.Rectangle.init(
                0,
                0,
                64,
                64,
            ),
            .weight = 0.95,
        },
        .shooting_stats = .{
            .damage = 10,
            .timeout = 0.55,
        },
    };

    try manager.append(
        .{
            .entity = New,
        },
    );
}
