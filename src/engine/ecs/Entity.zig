const std = @import("std");
const rl = @import("raylib");
const z = @import("../z/z.zig");

// =====================================================

const Allocator = @import("std").mem.Allocator;
const components = @import("./components.zig");

// =====================================================

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
});

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
        @as(*anyopaque, @ptrCast(component)),
    );
}
// pub fn attach(self: *Self, comptime T: type, component: *T, id: []const u8) !void {
//     try self.components.put(
//         id,
//         @as(*anyopaque, @ptrCast(component)),
//     );
// }

pub fn get(self: *Self, comptime T: type, id: []const u8) ?*T {
    const res = self.components.get(id);
    if (res == null) return null;

    return @as(*T, @ptrCast(@alignCast(res)));
}

pub fn deinit(self: *Self) void {
    self.components.deinit();
}
