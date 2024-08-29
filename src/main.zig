
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
    defer e.deinit();

    var Player = e.ecs.Entity.init(&allocator, "Player");
    var player_display: e.ecs.components.Display = undefined;
    {
        player_display = e.ecs.components.Display{
            .sprite = " ",
            .scaling = .normal,
        };
        try Player.attach(e.ecs.components.Display, &player_display, "display");
    }

    const pd = Player.get(e.ecs.components.Display, "display");
    std.debug.print("{any}", .{pd});

    Player.deinit();

    // // Initialization
    // //--------------------------------------------------------------------------------------
    // const screenWidth = 800;
    // const screenHeight = 450;

    // rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    // defer rl.closeWindow(); // Close window and OpenGL context

    // rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    // //--------------------------------------------------------------------------------------

    // var textr = rl.loadImage("/Users/zoltantakacs/_code/zig/testproj/src/assets/player_left_0.png");
    // rl.imageResizeNN(&textr, 160, 160);

    // // Main game loop
    // while (!rl.windowShouldClose()) { // Detect window close button or ESC key
    //     // Update
    //     //----------------------------------------------------------------------------------
    //     // TODO: Update your variables here
    //     //----------------------------------------------------------------------------------

    //     const x = rl.loadTextureFromImage(textr);

    //     // Draw
    //     //----------------------------------------------------------------------------------
    //     rl.beginDrawing();
    //     defer rl.endDrawing();

    //     rl.clearBackground(rl.Color.white);

    //     // rl.drawRectangle(0, 0, 100, 100, rl.Color.black);

    //     rl.drawTexture(x, 0, 0, rl.Color.white);

    //     rl.drawText("Congrats! You created your first window!", 190, 200, 20, rl.Color.light_gray);
    //     //----------------------------------------------------------------------------------
    // }
}
