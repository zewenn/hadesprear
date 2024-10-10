const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const config = @import("../../config.zig");
const e = @import("../../engine/engine.m.zig");

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const weapons = @import("weapons.zig");

const projectile_manager = e.zlib.HeapManager(e.entities.Entity, (struct {
    pub fn callback(alloc: Allocator, item: *e.entities.Entity) !void {
        e.entities.delete(item.id);
        alloc.free(item.id);
    }
}).callback);
const PLAYER_PROJECTILE_LIGHT_SPRITE = "sprites/projectiles/projectile_player_light.png";
const PLAYER_PROJECTILE_HEAVY_SPRITE = "sprites/projectiles/projectile_player_heavy.png";
const ENEMY_PROJECTILE_LIGHT_SPRITE = "sprites/projectiles/projectile_enemy_light.png";
const ENEMY_PROJECTILE_HEAVY_SPRITE = "sprites/projectiles/projectile_enemy_heavy.png";

pub fn awake() !void {
    try projectile_manager.init(e.ALLOCATOR);
    // std.log.info("Maximum projectile count: {d}", .{ProjectileManager.ArraySize});
}

pub fn init() !void {}

pub fn update() !void {
    const others = try e.entities.searchExclude("projectile");
    defer e.ALLOCATOR.free(others);

    const items = try projectile_manager.items();
    defer projectile_manager.alloc.free(items);

    projectile_loop: for (items) |entity_ptr| {
        if (entity_ptr.projectile_data == null) {
            std.log.err("Projectile without projectile data!", .{});
            std.log.err("Removing...", .{});

            projectile_manager.remove(entity_ptr);
            continue;
        }

        const projectile_data = &(entity_ptr.projectile_data.?);

        if (projectile_data.lifetime_end < e.time.gameTime) {
            projectile_manager.removeFreeId(entity_ptr);
            continue;
        }

        if (!e.entities.exists(entity_ptr.id)) {
            try e.entities.register(entity_ptr);
        }

        const direction_vector = e.Vec2(1, 0)
            .rotate(std.math.degreesToRadians(projectile_data.direction))
            .normalize();

        entity_ptr.transform.rotation.z = projectile_data.direction - 90;

        entity_ptr.transform.position.x += direction_vector.x * projectile_data.speed * @as(f32, @floatCast(e.time.deltaTime));
        entity_ptr.transform.position.y += direction_vector.y * projectile_data.speed * @as(f32, @floatCast(e.time.deltaTime));

        // std.log.debug("index: {d} - {s}", .{ index, item.id });

        for (others) |other| {
            if (other.entity_stats == null) continue;

            if (projectile_data.side == .player and std.mem.eql(u8, other.id, "Player"))
                continue;

            if (projectile_data.side == .enemy and std.mem.containsAtLeast(
                u8,
                other.tags,
                1,
                "enemy",
            ))
                continue;

            if (!e.collision.collides(entity_ptr, other)) {
                continue;
            }

            projectile_data.health -= projectile_data.bleed_per_second * e.time.DeltaTime();

            if (projectile_data.health > 1) {
                other.entity_stats.?.health -= projectile_data.damage * 5 * e.time.DeltaTime();
            } else {
                other.entity_stats.?.health -= projectile_data.damage;
            }

            if ((projectile_data.health <= 0 and other.entity_stats.?.health <= 0) or
                other.entity_stats.?.health <= 0)
            {
                if (projectile_data.owner) |owner| {
                    weapons.applyOnHitEffect(
                        @ptrCast(owner),
                        projectile_data.on_hit_effect,
                        projectile_data.on_hit_effect_strength,
                    );
                }
            }

            if (projectile_data.health <= 0) {
                projectile_manager.removeFreeId(entity_ptr);
                continue :projectile_loop;
            }
        }
    }
}

pub fn deinit() !void {
    const items = try projectile_manager.items();
    defer projectile_manager.alloc.free(items);

    for (items) |item| {
        projectile_manager.removeFreeId(item);
    }
    projectile_manager.deinit();
}

pub fn new(at: e.Vector2, data: config.ProjectileData) !void {
    const id_o = e.uuid.urn.serialize(e.uuid.v7.new());
    // std.log.debug("id: {s}", .{id});

    const id = try e.ALLOCATOR.alloc(u8, 36);
    std.mem.copyForwards(u8, id, &id_o);

    const New = e.entities.Entity{
        .id = id,
        .tags = "projectile",
        .transform = .{
            .position = at,
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = data.scale,
        },
        .display = .{
            .scaling = .pixelate,
            .sprite = data.sprite,
        },
        .projectile_data = data,
        .collider = .{
            .trigger = true,
            .dynamic = false,
            .weight = 0,
            .rect = e.Rect(
                0,
                0,
                data.scale.x,
                data.scale.y,
            ),
        },
    };

    try projectile_manager.append(New);
}
