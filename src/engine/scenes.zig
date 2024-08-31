const std = @import("std");
const z = @import("./z/z.zig");
const ecs = @import("./ecs/ecs.zig");
const rl = @import("raylib");
const events = @import("./events.zig");
const Allocator = @import("std").mem.Allocator;

pub const Script = struct {
    const fn_type: type = *const fn () void;
    const Self = @This();

    eAwake: ?fn_type = null,
    eInit: ?fn_type = null,
    eUpdate: ?fn_type = null,
    eDeinit: ?fn_type = null,
};

const map_fn_type = *const fn () void;
const String = []const u8;
const map_type = std.StringHashMap(std.ArrayList(Script));

var script_map: map_type = undefined;
var allocator_ptr: *std.mem.Allocator = undefined;

pub fn init(allocator: *std.mem.Allocator) void {
    script_map = map_type.init(allocator.*);
    allocator_ptr = allocator;
}

pub fn deinit() void {
    var iterator = script_map.keyIterator();

    while (iterator.next()) |item| {
        const arr = script_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = script_map.remove(item.*);
    }
    script_map.deinit();
}

pub fn clear() void {
    var kIt = script_map.keyIterator();

    while (kIt.next()) |item| {
        const arr = script_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = script_map.remove(item.*);
    }
    script_map.clearAndFree();
}

pub fn register(comptime id: String, script: Script) !void {
    const data = script_map.getPtr(id);

    if (data) |_data| {
        try _data.append(script);
        return;
    }

    var new_array = std.ArrayList(Script).init(allocator_ptr.*);
    try new_array.append(script);
    try script_map.put(id, new_array);
}

pub fn load(comptime id: String) !void {
    events.clear();
    const data = script_map.get(id);

    if (data == null) {
        return;
    }

    for (data.?.items) |script| {
        if (script.eAwake) |e| {
            try events.on(.Awake, e);
        }
        if (script.eInit) |e| {
            try events.on(.Init, e);
        }
        if (script.eUpdate) |e| {
            try events.on(.Update, e);
        }
        if (script.eDeinit) |e| {
            try events.on(.Deinit, e);
        }
    }

    try events.call(.Awake);
    try events.call(.Init);
}

pub fn delete(comptime id: String) !void {
    _ = script_map.remove(id);
}
