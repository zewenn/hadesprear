const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

fn isPointerInBounds(ptr: *u8, begin: *u8, end: *u8) bool {
    const ptrInt = @intFromPtr(ptr);
    const startInt = @intFromPtr(begin);
    const endInt = @intFromPtr(end);
    return ptrInt >= startInt and ptrInt < endInt;
}

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {
    const entities = try e.entities.all();
    defer e.entities.alloc.free(entities);

    for (entities) |entity| {
        if (entity.entity_stats == null) continue;
        if (entity.dash_modifiers == null) continue;

        if (!entity.entity_stats.?.is_dashing) continue;

        if (entity.dash_modifiers.?.dash_end <= e.time.gameTime) {
            entity.entity_stats.?.is_dashing = false;
            entity.entity_stats.?.can_move = true;
            entity.entity_stats.?.is_invalnureable = false;
            continue;
        }

        entity.transform.position.x +=
            entity.dash_modifiers.?.towards.x *
            entity.entity_stats.?.movement_speed *
            entity.dash_modifiers.?.movement_speed_multiplier *
            @as(f32, @floatCast(e.time.deltaTime));

        entity.transform.position.y +=
            entity.dash_modifiers.?.towards.y *
            entity.entity_stats.?.movement_speed *
            entity.dash_modifiers.?.movement_speed_multiplier *
            @as(f32, @floatCast(e.time.deltaTime));
    }
}

pub fn deinit() !void {}

pub fn applyDash(entity: *e.entities.Entity, towards: f32) !void {
    if (entity.entity_stats == null) return;
    if (entity.dash_modifiers == null) return;

    entity.entity_stats.?.is_dashing = true;
    entity.entity_stats.?.can_move = false;
    entity.entity_stats.?.is_invalnureable = true;

    entity.dash_modifiers.?.towards = e.Vec2(1, 0)
        .rotate(std.math.degreesToRadians(towards))
        .normalize();

    entity.dash_modifiers.?.dash_end = e.time.gameTime + entity.dash_modifiers.?.dash_time;
}
