const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const conf = @import("../../config.zig");
const e = @import("../../engine/engine.m.zig");

const weapons = @import("weapons.zig");
const prefabs = @import("items.zig").prefabs;

const dashing = @import("dashing.zig");
const projectiles = @import("projectiles.zig");

const HAND_DISTANCE = 24;

var Player: ?*e.entities.Entity = null;

const EnemyStruct = struct {
    entity: e.entities.Entity,
    animator: ?e.Animator = null,
    hand0: e.entities.Entity,
    hand1: e.entities.Entity,
    hands: ?weapons.Hands = null,
    // current_weapon: conf.Item = prefabs.legendaries.weapons.claymore,
    current_weapon: conf.Item = prefabs.epics.weapons.piercing_sword,
};

const manager = e.zlib.HeapManager(EnemyStruct, (struct {
    pub fn callback(alloc: Allocator, item: *EnemyStruct) !void {
        if (item.hands) |*hands| {
            hands.deinit();
        }

        e.entities.delete(item.hand0.id);
        alloc.free(item.hand0.id);

        e.entities.delete(item.hand1.id);
        alloc.free(item.hand1.id);

        const onhis_items = try weapons.manager.items();
        defer weapons.manager.alloc.free(onhis_items);

        var removed: usize = 0;
        for (onhis_items) |onhit| {
            if (@intFromPtr(onhit.entity) != @intFromPtr(&item.entity)) continue;

            removed += 1;

            weapons.manager.remove(onhit);
        }

        const porj_items = try projectiles.manager.items();
        defer projectiles.manager.alloc.free(porj_items);

        for (porj_items) |projectile| {
            if (projectile.projectile_data.?.owner) |owner| {
                if (!e.zlib.eql(owner.*, item.entity)) continue;
                projectile.projectile_data.?.owner = null;
            }
        }

        e.entities.delete(item.entity.id);
        alloc.free(item.entity.id);

        if (item.animator) |*animator| {
            animator.deinit();
        }
    }
}).callback);

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

            item.hands = try weapons.Hands.init(
                &e.ALLOCATOR,
                &item.hand0,
                &item.hand1,
            );

            try e.entities.register(&item.hand0);
            try e.entities.register(&item.hand1);

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

        item.hands.?.equip(&(item.current_weapon));
        item.hands.?.update();

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

        if (entity_ptr.entity_stats.?.can_move and distance >= item.entity.entity_stats.?.range * 0.75) {
            entity_ptr.transform.position.x += move_vec.x * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
            entity_ptr.transform.position.y += move_vec.y * entity_ptr.entity_stats.?.movement_speed * e.time.DeltaTime();
        }

        if (entity_ptr.shooting_stats.?.timeout_end < e.time.gameTime and
            distance < entity_ptr.entity_stats.?.range)
        {
            try projectiles.summonMultiple(
                .light,
                &item.entity,
                item.current_weapon,
                0,
                angle,
                .enemy,
            );

            try item.hands.?.play(.light);
        }

        if (item.hands) |*hands| {
            const Hand0 = &item.hand0;
            const Hand1 = &item.hand1;

            const This = item.entity;

            var rotator_vector0 = e.Vector2.init(HAND_DISTANCE, Hand0.transform.scale.x);
            if (hands.playing_left) {
                rotator_vector0.x += Hand0.transform.rotation.y;
                rotator_vector0.y += Hand0.transform.rotation.x;
            }

            const finished0 = rotator_vector0.rotate(std.math.degreesToRadians(-90));

            var rotator_vector1 = e.Vector2.init(HAND_DISTANCE, 0);
            if (hands.playing_right) {
                rotator_vector1.x += Hand1.transform.rotation.y;
                rotator_vector1.y += Hand1.transform.rotation.x;
            }

            const finished1 = rotator_vector1.rotate(std.math.degreesToRadians(-90));

            Hand0.transform.anchor = finished0;
            Hand1.transform.anchor = finished1;

            const rotation: f32 = angle - 90;

            Hand0.transform.position = .{
                .x = This.transform.position.x,
                .y = This.transform.position.y,
            };
            Hand0.transform.rotation.z = GetRotation: {
                if (!hands.playing_left) break :GetRotation rotation + hands.left_base_rotation;

                break :GetRotation rotation + Hand0.transform.rotation.z + hands.left_base_rotation;
            };
            Hand1.transform.position = .{
                .x = This.transform.position.x + 0,
                .y = This.transform.position.y + 0,
            };
            Hand1.transform.rotation.z = GetRotation: {
                if (!hands.playing_right) break :GetRotation rotation + hands.right_base_rotation;

                break :GetRotation rotation + Hand1.transform.rotation.z + hands.right_base_rotation;
            };
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

    const hand0_id = try std.fmt.allocPrint(
        e.ALLOCATOR,
        "hand0-{s}",
        .{id},
    );
    const hand1_id = try std.fmt.allocPrint(
        e.ALLOCATOR,
        "hand1-{s}",
        .{id},
    );

    const Hand0 = e.entities.Entity{
        .id = hand0_id,
        .tags = "hand",
        .transform = e.entities.Transform{
            .scale = e.Vec2(48, 48),
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = e.MISSINGNO,
        },
    };

    const Hand1 = e.entities.Entity{
        .id = hand1_id,
        .tags = "hand",
        .transform = e.entities.Transform{
            .scale = e.Vec2(96, 256),
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = e.MISSINGNO,
        },
    };

    // const random = std.crypto.random.intRangeLessThanBiased(
    //     u32,
    //     0,
    //     10,
    // );

    try manager.append(
        .{
            .entity = New,
            .hand0 = Hand0,
            .hand1 = Hand1,
            .current_weapon = prefabs.legendaries.weapons.trident,
            // if (random > 8)
            //     prefabs.legendaries.weapons.trident
            // else if (random > 2)
            //     prefabs.epics.weapons.piercing_sword
            // else
            //     prefabs.hands,
        },
    );
}
