
const std = @import("std");
const e = @import("../engine/engine.zig");


pub fn init() void {
    e.z.println("Hello again!", .{});
}


pub fn main() !void {
    try e.events.on(.Load, init);
    std.debug.print("Hello world!", .{});
}