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

/// The delta time in seconds
pub var deltaTime: f64 = 0;

/// The currentTime minus
/// the time the game was paused, in seconds.
pub var gameTime: f64 = 0;
var paused = false;

pub fn pause() void {
    paused = true;
}
pub fn start() void {
    paused = false;
}
pub fn isPaused() bool {
    return paused;
}

pub fn DeltaTime() f32 {
    return @as(f32, @floatCast(deltaTime));
}

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    timeouts = std.ArrayList(Timeout).init(allocator.*);
    gameTime = rl.getTime();
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
    if (!paused) gameTime += deltaTime;

    for (timeouts.items, 0..) |timeout, i| {
        if (timeout.ends > currentTime) continue;

        timeout.func() catch {
            std.log.err("Failed execution of timeout callback...\nResuming execution...", .{});
        };

        _ = timeouts.orderedRemove(i);
        break;
    }
}
