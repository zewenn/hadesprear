const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

// ===================== [Entity] =====================

var background: *e.ecs.Entity = undefined;

// =================== [Components] ===================

var display: e.ecs.cDisplay = undefined;
var transform: e.ecs.cTransform = undefined;

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    background = try e.ecs.newEntity("background");
    {
        display = e.ecs.components.Display{
            .sprite = "background4.png",
            .scaling = .pixelate,
        };
        try background.attach(&display, "display");
    }
    {
        transform = .{
            .position = e.Vector2.init(0, 0),
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = e.Vector2.init(2304, 1536),
        };
        try background.attach(&transform, "transform");
    }
}
