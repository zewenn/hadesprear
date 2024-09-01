const std = @import("std");

const tm = std.time;

/// Seconds since UTC 1970-01-01
pub var current: f64 = 0;

/// Time passed since the last `time.update()` call
pub var delta: f64 = 0;

var max: f64 = 0;
var stored_max: u16 = 0;

pub fn start() void {
    setCurrentToNow();
}

fn setCurrentToNow() void {
    current = @floatFromInt(tm.milliTimestamp());
    current = current / @as(f64, 1000.0);
}

pub fn tick() void {
    const _curr = current;
    setCurrentToNow();
    delta = current - _curr;

    // if (stored_max != max_fps) {
    //     updateMax(max_fps);
    // }

    // if (delta >= max) return;
    // tm.sleep(@intFromFloat((max - delta) * @as(f64, 1000) * @as(f64, 1000)));
}
