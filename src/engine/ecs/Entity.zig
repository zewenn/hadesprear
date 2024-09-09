const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const rl = @import("raylib");
const z = Import(.z);

// =====================================================

const Allocator = @import("std").mem.Allocator;
const components = @import("./components.zig");

// =====================================================

const Self = @This();

id: []const u8,
components: std.StringHashMap(*anyopaque),

alloc: *Allocator,

pub fn init(
    allocator: *Allocator,
    id: []const u8,
) Self {
    const comps = std.StringHashMap(*anyopaque).init(allocator.*);

    return .{
        .id = id,
        .components = comps,
        .alloc = allocator,
    };
}

pub fn attach(self: *Self, component: *anyopaque, id: []const u8) !void {
    try self.components.put(
        id,
        component,
    );
}

pub fn detach(self: *Self, id: []const u8) void {
    _ = self.components.remove(id);
}

pub fn get(self: *Self, comptime T: type, id: []const u8) ?*T {
    const res = self.components.get(id);
    if (res == null) return null;

    return @as(*T, @ptrCast(@alignCast(res)));
}

pub fn deinit(self: *Self) void {
    self.components.deinit();
}
