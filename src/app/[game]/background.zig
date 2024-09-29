const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

// ===================== [Entity] =====================

var Background = e.entities.Entity{
    .id = "background",
    .tags = "wallpaper",
    .transform = .{
        .position = e.Vec2(0, 0),
        .rotation = e.Vec3(0, 0, 0),
        .scale = e.Vec2(2304, 1536),
    },
    .display = .{
        .scaling = .pixelate,
        .sprite = "sprites/backgrounds/background4.png",
    },
};

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    try e.entities.register(&Background);
}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {
    Background.freeRaylibStructs();
}
