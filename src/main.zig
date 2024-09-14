const std = @import("std");

const Import = @import(".temp/imports.zig").Import;

const os = @import("std").os;
const fs = @import("std").fs;

const e = Import(.engine);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    // Initialization
    //--------------------------------------------------------------------------------------
    e.window.init(
        "HadeSpear",
        e.Vec2(
            1280,
            720,
        ),
    );
    defer e.window.deinit();

    try e.compile();
    try e.init(&allocator);
    defer e.deinit() catch {};

    e.setTargetFPS(144); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!e.windowShouldClose()) { // Detect window close button or ESC key
        e.update(&allocator) catch {};
    }

    const str = try e.z.arrays.NumberToString(allocator, 123);
    defer allocator.free(str);

    std.log.debug("123 to string: {s}", .{str});
}
