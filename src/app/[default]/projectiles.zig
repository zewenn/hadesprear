const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const config = @import("../../config.zig");
const e = Import(.engine);

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const ProjectileManager = e.entities.Manager(.{ .max_entities = 2048 });
const PLAYER_PROJECTILE_LIGHT_SPRITE = "projectile_player_light.png";
const PLAYER_PROJECTILE_HEAVY_SPRITE = "projectile_player_heavy.png";
const ENEMY_PROJECTILE_LIGHT_SPRITE = "projectile_enemy_light.png";
const ENEMY_PROJECTILE_HEAVY_SPRITE = "projectile_enemy_heavy.png";

pub fn awake() !void {
    std.log.info("Maximum projectile count: {d}", .{ProjectileManager.ArraySize});
}

pub fn init() !void {}

pub fn update() !void {
    for (ProjectileManager.array, 0..) |value, index| {
        if (value == null) continue;

        const item = &ProjectileManager.array[index].?;

        if (item.projectile_data == null) {
            std.log.err("Projectile without projectile data!", .{});
            std.log.err("Removing...", .{});

            ProjectileManager.free(index);
            continue;
        }

        const projectile_data = item.projectile_data.?;

        if (projectile_data.lifetime_end < e.time.currentTime) {
            e.ALLOCATOR.free(item.id);
            ProjectileManager.free(index);
            continue;
        }

        if (!e.entities.exists(item.id)) {
            try e.entities.register(item);
        }

        const direction_vector = e.Vec2(1, 0)
            .rotate(std.math.degreesToRadians(projectile_data.direction))
            .normalize();

        item.transform.rotation.z = projectile_data.direction - 90;

        item.transform.position.x += direction_vector.x * projectile_data.speed * @as(f32, @floatCast(e.time.deltaTime));
        item.transform.position.y += direction_vector.y * projectile_data.speed * @as(f32, @floatCast(e.time.deltaTime));
        // std.log.debug("index: {d} - {s}", .{ index, item.id });
    }
}

pub fn deinit() !void {
    for (0..ProjectileManager.array.len) |index| {
        const item = &ProjectileManager.array[index];
        if (item.*) |value| {
            e.ALLOCATOR.free(value.id);
        }

        ProjectileManager.free(index);
    }
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
            .sprite = switch (data.side) {
                .player => switch (data.weight) {
                    .light => PLAYER_PROJECTILE_LIGHT_SPRITE,
                    .heavy => PLAYER_PROJECTILE_HEAVY_SPRITE,
                },
                .enemy => switch (data.weight) {
                    .light => ENEMY_PROJECTILE_LIGHT_SPRITE,
                    .heavy => ENEMY_PROJECTILE_HEAVY_SPRITE,
                },
            },
        },
        .projectile_data = data,
    };

    ProjectileManager.malloc(New);
}
