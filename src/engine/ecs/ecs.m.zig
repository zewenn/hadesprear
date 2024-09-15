const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const rl = @import("raylib");
const z = Import(.z);
const Allocator = @import("std").mem.Allocator;

// =====================================================

pub const components = @import("./components.zig");
pub const cDisplay = components.Display;
pub const cTransform = components.Transform;
pub const cCollider = components.Collider;

pub const Entity = @import("./Entity.zig");

// =====================================================

pub var alloc: *Allocator = undefined;
pub var entities: std.StringHashMap(Entity) = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    entities = std.StringHashMap(Entity).init(alloc.*);
}

pub fn deinit() void {
    defer entities.deinit();
    {
        var kIt = entities.keyIterator();
        while (kIt.next()) |key| {
            var entity = entities.get(key.*).?;
            entity.deinit();
        }
    }
}

pub fn clear() void {
    entities.clearAndFree();
}

pub fn newEntity(id: []const u8) !*Entity {
    try entities.put(id, Entity.init(alloc, id));
    return entities.getPtr(id).?;
}

pub fn getEntity(id: []const u8) ?*Entity {
    return entities.getPtr(id);
}

pub fn removeEntity(id: []const u8) void {
    _ = entities.remove(id);
}

/// Caller owns the returned memory
pub fn getEntities(component_id: []const u8) ![]*Entity {
    var eList = std.ArrayList(*Entity).init(alloc.*);
    defer eList.deinit();

    var it = entities.keyIterator();
    while (it.next()) |key| {
        var value = entities.getPtr(key.*).?;

        if (value.components.contains(component_id)) {
            try eList.append(value);
        }
    }

    return eList.toOwnedSlice();
}
