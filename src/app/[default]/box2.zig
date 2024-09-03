const std = @import("std");
const e = @import("../../engine/engine.zig");
const entity = @import("../entity.zig");

// ===================== [Entity] =====================

var box: *e.ecs.Entity = undefined;

// =================== [Components] ===================

var display: e.ecs.cDisplay = undefined;
var transform: e.ecs.cTransform = undefined;
var stats: entity.EntityStats = undefined;
var collider: e.ecs.cCollider = undefined;

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    box = try e.ecs.newEntity("box2");
    {
        display = e.ecs.components.Display{
            .sprite = "empty_icon.png",
            .scaling = .pixelate,
            .tint = e.Color.red,
        };
        try box.attach(&display, "display");
    }
    {
        transform = .{
            .position = e.Vector2.init(-64, 0),
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = e.Vector2.init(64, 64),
        };
        try box.attach(&transform, "transform");
    }
    {
        stats = .{
            .movement_speed = 10,
        };
        try box.attach(&stats, "stats");
    }
    {
        collider = .{
            .rect = e.Rectangle.init(0, 0, 64, 64),
            .weight = 6,
            .dynamic = false,
        };
        try box.attach(&collider, "collider");
    }
}
