const std = @import("std");

const os = @import("std").os;
const fs = @import("std").fs;

const e = @import("./engine/engine.m.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    e.setTraceLogLevel(.log_error);

    e.window.init(
        "HadeSpear",
        e.Vec2(
            1440,
            720,
        ),
    );
    defer e.window.deinit();

    e.window.makeResizable();

    try e.compile();
    try e.init(allocator);
    defer e.deinit();

    e.setTargetFPS(256);
    e.setExitKey(.key_kp_7);

    while (!e.windowShouldClose()) {
        if (e.isKeyPressed(.key_f11)) {
            e.window.toggleBorderless();
        }
        e.update() catch {};
    }
}
