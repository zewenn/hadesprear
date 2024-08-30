const std = @import("std");
const rl = @import("raylib");
const os = @import("std").os;
const fs = @import("std").fs;

const e = @import("./engine/engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    try e.init(&allocator);
    defer e.deinit() catch null;

    var Player = try e.ecs.newEntity("Player");

    var player_display: e.ecs.components.Display = undefined;
    {
        player_display = e.ecs.components.Display{
            .sprite = "player_left_0.png",
            .scaling = .pixelate,
        };
        try Player.attach(e.ecs.components.Display, &player_display, "display");
    }
    var player_transform: e.ecs.components.Transform = undefined;
    {
        player_transform = e.ecs.components.Transform{
            .position = rl.Vector2.init(100, 0),
            .rotation = rl.Vector3.init(0, 0, 0),
            .scale = rl.Vector2.init(128, 128),
        };
        try Player.attach(e.ecs.components.Transform, &player_transform, "transform");
    }

    // const pd = Player.get(e.ecs.components.Display, "display");
    // const pt = Player.get(e.ecs.components.Transform, "transform");
    // std.debug.print("{any}{any}", .{pd, pt});


    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1280;
    const screenHeight = 720;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var textr = rl.loadImage("/Users/zoltantakacs/_code/zig/testproj/src/assets/player_left_0.png");
    rl.imageResizeNN(&textr, 160, 160);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        e.update();

        // rl.beginDrawing();

        // rl.clearBackground(rl.Color.white);

        // defer rl.endDrawing();
    }
}
