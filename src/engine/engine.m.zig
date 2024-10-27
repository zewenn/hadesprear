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
pub const Colour = display.Colour;

pub const GUI = @import("./gui/gui.m.zig");
pub const Animator = @import("./animator/Animator.zig");

pub const time = @import("./time.m.zig");
pub const setTimeout = time.setTimeout;

pub const rl = @import("raylib");
pub usingnamespace rl;

pub const uuid = @import("uuid");

pub var ALLOCATOR: Allocator = undefined;
pub var ARENA: Allocator = undefined;
var arena_alloc: std.heap.ArenaAllocator = undefined;

pub const entities = @import("../config.zig").entities;
pub const components = @import("./entities/components.zig");
pub const Entity = entities.Entity;

pub inline fn compile() !void {
    try assets.compile();
}

pub const window = display.window;
pub const camera = display.camera;

pub const MISSINGNO = "sprites/missingno.png";

pub const saveloader = @import("./saveloader.zig");

pub fn loadf32(v: anytype) f32 {
    return switch (@typeInfo(@TypeOf(v))) {
        .Int, .ComptimeInt => @floatFromInt(v),
        .Float, .ComptimeFloat => @floatCast(v),
        .Bool => @floatFromInt(@intFromBool(v)),
        else => 0,
    };
}

pub fn loadusize(v: anytype) usize {
    return switch (@typeInfo(@TypeOf(v))) {
        .Int, .ComptimeInt => @intCast(v),
        .Float, .ComptimeFloat => @intFromFloat(@round(v)),
        .Bool => @intFromBool(v),
        else => 0,
    };
}

pub fn Vec2(x: anytype, y: anytype) rl.Vector2 {
    return rl.Vector2.init(loadf32(x), loadf32(y));
}

pub fn Vec3(x: anytype, y: anytype, z: anytype) rl.Vector3 {
    return rl.Vector3.init(loadf32(x), loadf32(y), loadf32(z));
}

pub fn Rect(x: anytype, y: anytype, w: anytype, h: anytype) rl.Rectangle {
    return rl.Rectangle.init(
        loadf32(x),
        loadf32(y),
        loadf32(w),
        loadf32(h),
    );
}

pub fn UUIDV7() ![]u8 {
    const id_o = uuid.urn.serialize(uuid.v7.new());

    const id = try ALLOCATOR.alloc(u8, 36);
    std.mem.copyForwards(u8, id, &id_o);

    return id;
}

pub fn init(allocator: *Allocator) !void {
    ALLOCATOR = allocator.*;

    arena_alloc = std.heap.ArenaAllocator.init(allocator.*);
    ARENA = arena_alloc.allocator();

    time.init(allocator);
    Colour.init(ALLOCATOR);

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

    try GUI.deinit();

    assets.deinit();

    scenes.deinit();
    events.deinit();

    entities.deinit();
    Colour.deinit();

    time.deinit();

    arena_alloc.deinit();
}

pub fn update() !void {
    // var last_farme_at = time.currentTime;
    try time.tick();
    std.debug.print("FPS: {d:.3}\r", .{1 / time.deltaTime});

    // last_farme_at = rl.getTime();
    input.update();
    // std.log.info("INPUT: {d:.3}%", .{(rl.getTime() - last_farme_at) / time.deltaTime * 100});

    // last_farme_at = rl.getTime();
    GUI.update();
    // std.log.info("GUI: {d:.3}%", .{(rl.getTime() - last_farme_at) / time.deltaTime * 100});

    // last_farme_at = rl.getTime();
    try events.call(.Update);

    // std.log.info("EVENTS: {d:.3}%", .{(rl.getTime() - last_farme_at) / time.deltaTime * 100});

    // last_farme_at = rl.getTime();
    try collision.update(&ALLOCATOR);

    // std.log.info("COLLISION: {d:.3}%", .{(rl.getTime() - last_farme_at) / time.deltaTime * 100});

    // last_farme_at = rl.getTime();
    camera.update();
    // std.log.info("CAMERA: {d:.3}%", .{(rl.getTime() - last_farme_at) / time.deltaTime * 100});

    // last_farme_at = rl.getTime();
    window.update();
    try display.update();
    // std.log.info("DISPLAY: {d:.3}%", .{(rl.getTime() - last_farme_at) / time.deltaTime * 100});

    // std.debug.print("\n\n\n" ** 10, .{});
}
