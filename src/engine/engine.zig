const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = @import("./z/z.zig");
pub const ecs = @import("./ecs/ecs.zig");
pub const assets = @import("./assets.zig");

const _events = @import("./events.zig");
pub const events = _events.EventHandler(.{});

pub const display = @import("./display.zig");
pub const rl = @import("raylib");

pub fn init(allocator: *Allocator) !void {
    ecs.init(allocator);
    events.init(allocator);

    try assets.compile();
    try assets.init(allocator);

    display.init(allocator);

    try @import("../.temp/script_run.zig").register();

    try events.call(.Awake);
    try events.call(.Init);
}

pub fn deinit() !void {
    try events.call(.Deinit);

    display.deinit();
    assets.deinit();
    events.deinit();
    ecs.deinit();
}

pub fn update() void {
    display.update();
}