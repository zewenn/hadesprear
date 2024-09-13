const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");

const Timeout = struct {
    func: *const fn () anyerror!void,
    ends: f64,
};

var timeouts: std.ArrayList(Timeout) = undefined;
var alloc: *Allocator = undefined;

/// The current time in seconds
pub var currentTime: f64 = 0;

// The delta time in seconds
pub var deltaTime: f64 = 0;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    timeouts = std.ArrayList(Timeout).init(allocator.*);
}

pub fn deinit() void {
    timeouts.deinit();
}

pub fn setTimeout(time_seconds: f64, callback: fn () anyerror!void) !void {
    const obj = Timeout{
        .ends = rl.getTime() + time_seconds,
        .func = callback,
    };

    try timeouts.append(obj);
}

pub fn tick() !void {
    currentTime = rl.getTime();
    deltaTime = @floatCast(rl.getFrameTime());

    for (timeouts.items, 0..) |timeout, i| {
        if (timeout.ends > currentTime) continue;

        timeout.func() catch {
            std.log.err("Failed execution of timeout callback...\nResuming execution...", .{});
        };

        _ = timeouts.orderedRemove(i);
        break;
    }
}
