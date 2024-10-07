const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = @import("../../engine/engine.m.zig");

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

var Box = e.entities.Entity{
    .id = "box",
    .tags = "box",
    .transform = .{
        .position = e.Vec2(128, 0),
        .rotation = e.Vector3.init(0, 0, 0),
        .scale = e.Vec2(64, 64),
    },
    .display = .{
        .sprite = "sprites/icons/empty.png",
        .scaling = .pixelate,
    },
    .collider = .{
        .dynamic = false,
        .rect = e.Rectangle.init(0, 0, 64, 64),
        .weight = 1,
    },
};

pub fn awake() !void {
    try e.entities.register(&Box);
}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {
    Box.freeRaylibStructs();
}
