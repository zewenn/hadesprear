const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

const Manager = e.entities.Manager(.{ .max_entities = 1024 });
var Animators: [Manager.ArraySize]?e.Animator = [_]?e.Animator{null} ** Manager.ArraySize;

const MELEE_WALK_LEFT_SPRITE_0 = "enemy_melee_left_0.png";
const MELEE_WALK_LEFT_SPRITE_1 = "enemy_melee_left_1.png";
const MELEE_WALK_RIGHT_SPRITE_0 = "enemy_melee_right_0.png";
const MELEE_WALK_RIGHT_SPRITE_1 = "enemy_melee_right_1.png";

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {
    for (Manager.array, 0..) |item, index| {
        if (item == null) continue;

        var entity_ptr: *e.entities.Entity = &Manager.array[index].?;

        const entity_flag: bool = Get: {
            if (entity_ptr.entity_stats == null) break :Get false;
            if (!entity_ptr.entity_stats.?.is_enemy) break :Get false;
            break :Get true;
        };

        if (!entity_flag) {
            std.log.err("Enemy without projectile data!", .{});
            std.log.err("Removing...", .{});

            Manager.free(index);
            continue;
        }

        if (entity_ptr.entity_stats.?.health <= 0) {
            e.entities.delete(entity_ptr.id);
            // e.ALLOCATOR.free(entity_ptr.id);
            Manager.free(index);

            if (Animators[index] == null) continue;

            (&Animators[index].?).deinit();
            Animators[index] = null;
            continue;
        }

        if (!e.entities.exists(entity_ptr.id)) {
            if (Animators[index]) |*old| {
                old.deinit();
                Animators[index] = null;
            }

            try e.entities.register(entity_ptr);
            Animators[index] = e.Animator.init(
                &e.ALLOCATOR,
                entity_ptr,
            );

            var animator = &Animators[index].?;
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

        var animator = &Animators[index].?;
        animator.update();

        if (!animator.isPlaying("walk_right"))
            try animator.play("walk_right");

        entity_ptr.transform.position.x += 0.25;
        entity_ptr.entity_stats.?.health -= 0.1;
    }
}

pub fn deinit() !void {
    for (0..Manager.array.len) |index| {
        // if (item.*) |value| {
        //     e.ALLOCATOR.free(value.id);
        // }

        Manager.free(index);
    }

    for (&Animators, 0..) |*obj, index| {
        if (obj.* == null) continue;

        obj.*.?.deinit();

        Animators[index] = null;
    }
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
            .sprite = "enemy_melee_left_0.png",
        },
        .entity_stats = .{
            .is_enemy = true,
        },
    };

    Manager.malloc(New);
}
