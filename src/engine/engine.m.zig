const Import = @import("../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = @import("./z/z.m.zig");
pub const ecs = @import("./ecs/ecs.m.zig");
pub const assets = @import("./assets.m.zig");

pub const events = @import("./events.m.zig");
pub const scenes = @import("./scenes.m.zig");
pub const input = @import("./input.m.zig");
pub const zString = @import("./strings.m.zig").String;

pub const display = @import("./display/display.m.zig");
pub const collision = @import("./collision.m.zig");
pub const GUI = @import("./gui/gui.m.zig");
pub const Animator = @import("./animator/animator.m.zig");

pub const time = @import("./time.m.zig");
pub const setTimeout = time.setTimeout;

pub const rl = @import("raylib");
pub usingnamespace rl;

pub inline fn compile() !void {
    try assets.compile();
}

pub const window = display.window;
pub const camera = display.camera;
pub const Entity = ecs.Entity;

pub fn init(allocator: *Allocator) !void {
    time.init(allocator);

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

    time.deinit();
}

pub fn update(allocator: *Allocator) !void {
    try time.tick();

    input.update();

    GUI.update();

    try events.call(.Update);
    try collision.update(allocator);
    camera.update();
    try display.update();
}
