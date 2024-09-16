const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const config = @import("../../config.zig");
const e = Import(.engine);

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const ProjectileArrayType = std.ArrayList(e.entities.Entity);
var projectile_array: ProjectileArrayType = undefined;

pub fn awake() !void {
    projectile_array = ProjectileArrayType.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {
    var i: usize = 0;
    while (i < projectile_array.items.len) : (i += 1) {
        const index = i;
        const item = &projectile_array.items[index];

        if (item.projectile_data == null) {
            std.log.err("Projectile without projectile data!", .{});
            std.log.err("Removing...", .{});

            item.freeRaylibStructs();
            _ = e.entities.delete(item.id);

            _ = projectile_array.swapRemove(index);
            break;
        }

        const projectile_data = item.projectile_data.?;

        if (projectile_data.lifetime_end < e.time.currentTime) {
            item.freeRaylibStructs();
            _ = e.entities.delete(item.id);
            e.ALLOCATOR.free(item.id);
            _ = projectile_array.swapRemove(index);
            break;
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
        std.log.debug("index: {d} - {s}", .{ index, item.id });
    }
}

pub fn deinit() !void {
    for (projectile_array.items) |*item| {
        item.freeRaylibStructs();
        _ = e.entities.delete(item.id);

        e.ALLOCATOR.free(item.id);
    }
    projectile_array.deinit();
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
            .sprite = if (data.side == .player) "projectile_player_light.png" else "",
        },
        .projectile_data = data,
    };

    try projectile_array.append(New);

    std.log.debug("Id: {s}", .{New.id});
    std.log.debug("Arr len: {d}", .{projectile_array.items.len});
}
