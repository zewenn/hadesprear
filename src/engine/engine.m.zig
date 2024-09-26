const Import = @import("../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const zlib = @import("./z/z.m.zig");

pub const assets = @import("./assets.m.zig");

pub const events = @import("./events.m.zig");
pub const scenes = @import("./scenes.m.zig");
pub const input = @import("./input.m.zig");
pub const zString = @import("./strings.m.zig").String;

pub const collision = @import("./collision.m.zig");

pub const display = @import("./display/display.m.zig");

pub const GUI = @import("./gui/gui.m.zig");
pub const Animator = @import("./animator/Animator.zig");

pub const time = @import("./time.m.zig");
pub const setTimeout = time.setTimeout;

pub const rl = @import("raylib");
pub usingnamespace rl;

pub const uuid = @import("uuid");

pub var ALLOCATOR: Allocator = undefined;

pub const entities = @import("../config.zig").entities;
pub const components = @import("./entities/components.zig");

pub inline fn compile() !void {
    try assets.compile();
}

pub const window = display.window;
pub const camera = display.camera;

pub fn loadf32(v: anytype) f32 {
    return switch (@typeInfo(@TypeOf(v))) {
        .Int, .ComptimeInt => @floatFromInt(v),
        .Float, .ComptimeFloat => @floatCast(v),
        .Bool => @floatFromInt(@intFromBool(v)),
        else => 0,
    };
}

pub fn Vec2(x: anytype, y: anytype) rl.Vector2 {
    return rl.Vector2.init(loadf32(x), loadf32(y));
}

pub fn Vec3(x: anytype, y: anytype, z: anytype) rl.Vector3 {
    return rl.Vector3.init(loadf32(x), loadf32(y), loadf32(z));
}

pub fn init(allocator: *Allocator) !void {
    ALLOCATOR = allocator.*;
    time.init(allocator);

    entities.init(allocator);

    events.init(allocator);
    scenes.init(allocator);

    try assets.init(allocator);

    GUI.init(allocator);

    try @import("../.temp/script_run.zig").register();

    std.log.info("Initalised with Entity size: {d}", .{@sizeOf(entities.Entity)});

    try scenes.load("default");
}

pub fn deinit() !void {
    try events.call(.Deinit);

    GUI.deinit();

    assets.deinit();

    scenes.deinit();
    events.deinit();

    entities.deinit();
    time.deinit();
}

pub fn update() !void {
    try time.tick();
    std.debug.print("FPS: {d:.3}\r", .{1 / time.deltaTime});

    input.update();

    GUI.update();

    try events.call(.Update);

    try collision.update(&ALLOCATOR);
    camera.update();
    try display.update();
}
