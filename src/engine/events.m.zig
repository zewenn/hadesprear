const Import = @import("../.temp/imports.zig").Import;

const std = @import("std");
const z = Import(.z);

pub const EngineEvents = enum {
    Awake,
    Init,
    Update,
    Deinit,
};

const map_fn_type = *const fn () anyerror!void;
const map_fn_struct_type = struct { func: map_fn_type };
const map_type = std.AutoHashMap(EngineEvents, std.ArrayListAligned(map_fn_struct_type, null));

var event_map: map_type = undefined;
var allocator_ptr: *std.mem.Allocator = undefined;

pub fn init(allocator: *std.mem.Allocator) void {
    event_map = map_type.init(allocator.*);
    allocator_ptr = allocator;
}

pub fn deinit() void {
    var iterator = event_map.keyIterator();

    while (iterator.next()) |item| {
        const arr = event_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = event_map.remove(item.*);
    }
    event_map.deinit();
}

pub fn clear() void {
    var kIt = event_map.keyIterator();

    while (kIt.next()) |item| {
        const arr = event_map.get(item.*);
        if (arr != null) arr.?.deinit();

        _ = event_map.remove(item.*);
    }
    event_map.clearAndFree();
}

pub fn on(comptime id: EngineEvents, func: map_fn_type) !void {
    const data = event_map.getPtr(id);

    if (data) |d| {
        try d.append(map_fn_struct_type{ .func = func });
        return;
    }

    var new_array = std.ArrayList(map_fn_struct_type).init(allocator_ptr.*);
    try new_array.append(map_fn_struct_type{ .func = func });
    try event_map.put(id, new_array);
}

pub fn call(comptime id: EngineEvents) !void {
    const data = event_map.get(id);

    if (data == null) {
        return;
    }

    for (data.?.items) |func_struct| {
        try func_struct.func();
    }
}

pub fn delete(comptime id: EngineEvents) !void {
    _ = event_map.remove(id);
}
