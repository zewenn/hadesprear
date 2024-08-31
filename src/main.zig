const std = @import("std");
const rl = @import("raylib");
const os = @import("std").os;
const fs = @import("std").fs;

const e = @import("./engine/engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1280;
    const screenHeight = 720;

    rl.initWindow(
        screenWidth,
        screenHeight,
        "HADESPEAR",
    );
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    if (!rl.isAudioDeviceReady()) {
        e.z.dprint("Error initalising audio devide", .{});
    }

    try e.compile();
    try e.init(&allocator);
    defer e.deinit() catch void;

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        e.update();
    }
}
