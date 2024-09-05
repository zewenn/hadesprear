const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = @import("./z/z.zig");
pub const ecs = @import("./ecs/ecs.zig");
pub const assets = @import("./assets.zig");

pub const events = @import("./events.zig");
pub const scenes = @import("./scenes.zig");

pub const time = @import("./time.zig");

pub const display = @import("./display.zig");
pub const collision = @import("./collision.zig");
pub const rl = @import("raylib");
pub const GUI = @import("./gui/gui.zig");

pub const Animator = @import("./animator/Animator.zig");

pub inline fn compile() !void {
    try assets.compile();
}

pub const window = display.window;
pub const camera = display.camera;
pub const Entity = ecs.Entity;

pub usingnamespace rl;

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
    display.update();
}
