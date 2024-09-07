const Import = @import("../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = Import(.z);
pub const ecs = Import(.ecs);
pub const assets = Import(.assets);

pub const events = Import(.events);
pub const scenes = Import(.scenes);

pub const time = Import(.time);

pub const display = Import(.display);
pub const collision = Import(.collision);
pub const GUI = Import(.gui);
pub const Animator = Import(.animator);

pub const rl = @import("raylib");
pub usingnamespace rl;

pub inline fn compile() !void {
    try assets.compile();
}

pub const window = display.window;
pub const camera = display.camera;
pub const Entity = ecs.Entity;

pub fn init(allocator: *Allocator) !void {
    time.start();

    ecs.init(allocator);
    events.init(allocator);
    scenes.init(allocator);

    try assets.init(allocator);

    GUI.init(allocator);

    display.init(allocator);

    try @import("../.temp/script_run.zig").register();

    try scenes.load("default");
}

pub fn deinit() !void {
    try events.call(.Deinit);

    display.deinit();

    GUI.deinit();

    assets.deinit();

    scenes.deinit();
    events.deinit();
    ecs.deinit();
}

pub fn update(allocator: *Allocator) !void {
    time.tick();

    try events.call(.Update);
    try collision.update(allocator);
    camera.update();
    try display.update();

    // std.log.debug("FPS: {d:.5}", .{rl.getFPS()});
}
