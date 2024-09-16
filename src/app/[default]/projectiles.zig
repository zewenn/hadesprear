const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const config = @import("../../config.zig");
const e = Import(.engine);

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const heap = struct {
    const ProjectileArrayType = ?e.entities.Entity;

    // 1 MB
    const MaxSize: comptime_int = 8_000_000;
    const EntitySize: comptime_int = @sizeOf(?e.entities.Entity);

    const ProjectileArrayLen: comptime_int = @divFloor(MaxSize, EntitySize);
    var projectile_array: [ProjectileArrayLen]ProjectileArrayType = [_]ProjectileArrayType{
        null,
    } ** ProjectileArrayLen;

    pub fn searchNextIndex(override: bool) usize {
        for (projectile_array, 0..) |value, index| {
            if (index == 0) continue;
            if (value == null) return index;
        }

        // No null, everything is used...

        // This saves your ass 1 time
        if (!override) {
            projectile_array[0] = null;
            return 0;
        }

        const rIndex = std.crypto.random.uintLessThan(usize, ProjectileArrayLen);

        if (projectile_array[rIndex]) |_| {
            free(rIndex);
        }

        projectile_array[rIndex] = null;
        return rIndex;
    }

    pub fn malloc(value: e.entities.Entity) void {
        const index = searchNextIndex(true);
        projectile_array[index] = value;
    }

    pub fn free(index: usize) void {
        var value = projectile_array[index];

        if (value == null) return;

        value.?.freeRaylibStructs();
        if (e.entities.exists(value.?.id)) {
            _ = e.entities.delete(value.?.id);
        }
        e.ALLOCATOR.free(value.?.id);

        projectile_array[index] = null;
    }
};

pub fn awake() !void {
    std.log.info("Maximum projectile count: {d}", .{heap.ProjectileArrayLen});
}

pub fn init() !void {}

pub fn update() !void {
    for (heap.projectile_array, 0..) |value, index| {
        if (value == null) continue;

        const item = &heap.projectile_array[index].?;

        if (item.projectile_data == null) {
            std.log.err("Projectile without projectile data!", .{});
            std.log.err("Removing...", .{});

            heap.free(index);
            continue;
        }

        const projectile_data = item.projectile_data.?;

        if (projectile_data.lifetime_end < e.time.currentTime) {
            heap.free(index);
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
    for (0..heap.projectile_array.len) |index| {
        heap.free(index);
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
            .sprite = if (data.side == .player) "projectile_player_light.png" else "",
        },
        .projectile_data = data,
    };

    heap.malloc(New);

    // std.log.debug("Id: {s}", .{New.id});
}
