const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.zig");
const Allocator = @import("std").mem.Allocator;

// =====================================================

pub const components = @import("./components.zig");
pub const Entity = @import("./Entity.zig");

// =====================================================

var alloc: *Allocator = undefined;
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

pub fn newEntity(id: []const u8) !Entity {
    try entities.put(id, Entity.init(alloc, id));
    return entities.get(id).?;
}

pub fn getEntity(id: []const u8) ?Entity {
    return entities.get(id);
}
