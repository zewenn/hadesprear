const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

const Manager = e.entities.Manager(.{ .max_entities = 1024 });

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
        }

        if (entity_ptr.entity_stats.?.health <= 0) {
            e.entities.delete(entity_ptr.id);
            e.ALLOCATOR.free(entity_ptr.id);
            Manager.free(index);
        }

        if (!e.entities.exists(entity_ptr.id)) {
            try e.entities.register(entity_ptr);
        }

        entity_ptr.transform.position.x += 1;
    }
}

pub fn deinit() !void {
    for (0..Manager.array.len, &Manager.array) |index, *item| {
        if (item.*) |value| {
            e.ALLOCATOR.free(value.id);
        }

        Manager.free(index);
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
