const std = @import("std");
const e = @import("../engine/engine.zig");

pub fn awake() void {}

pub fn init() void {
    e.z.dprint("Hello again!", .{});
}

pub fn update() void {}

pub fn deinit() void {}