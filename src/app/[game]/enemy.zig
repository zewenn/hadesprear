const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);
const entity = @import("../entity.zig");

// ===================== [Entity] =====================

var enemy: *e.ecs.Entity = undefined;
var health_display: *e.GUI.GUIElement = undefined;

// =================== [Components] ===================

var display: e.ecs.cDisplay = undefined;
var transform: e.ecs.cTransform = undefined;
var stats: entity.EntityStats = undefined;
var collider: e.ecs.cCollider = undefined;
var text: []u8 = undefined;

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    enemy = try e.ecs.newEntity("box");
    {
        display = e.ecs.components.Display{
            .sprite = "empty_icon.png",
            .scaling = .pixelate,
        };
        try enemy.attach(&display, "display");
    }

    {
        transform = .{
            .position = e.Vector2.init(64, 0),
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = e.Vector2.init(64, 64),
        };
        try enemy.attach(&transform, "transform");
    }

    {
        stats = .{
            .movement_speed = 10,
        };
        try enemy.attach(&stats, "stats");
    }

    {
        collider = .{
            .rect = e.Rectangle.init(0, 0, 64, 64),
            .weight = 1,
            .dynamic = true,
        };
        try enemy.attach(&collider, "collider");
    }

    {
        health_display = try e.GUI.Text(
            .{
                .id = "EnemyHealth",
                .style = .{
                    .font = .{
                        .size = 32,
                    },
                    .color = e.Color.white,
                    .translate = .{
                        .x = .center,
                        .y = .center,
                    },
                },
            },
            "",
        );
        health_display.contents = null;
    }
}

pub fn update() !void {
    var pos: e.Vector2 = undefined;
    pos = e.camera.worldPositionToScreenPosition(transform.position);
    health_display.options.style.top = e.GUI.toUnit(pos.y - transform.scale.y);
    health_display.options.style.left = e.GUI.toUnit(pos.x);

    std.heap.page_allocator.free(text);
    text = try e.z.arrays.NumberToString(std.heap.page_allocator, stats.health);

    health_display.options.style.width = e.GUI.toUnit(
        @as(f32, @floatFromInt(text.len)) * health_display.options.style.font.size,
    );

    if (health_display.contents) |contents|
        e.z.arrays.freeManyItemPointerSentinel(
            std.heap.page_allocator,
            contents,
        );

    health_display.contents = try e.z.arrays.toManyItemPointerSentinel(
        std.heap.page_allocator,
        text,
    );
}

pub fn deinit() !void {
    if (health_display.contents) |contents|
        e.z.arrays.freeManyItemPointerSentinel(
            std.heap.page_allocator,
            contents,
        );

    std.heap.page_allocator.free(text);
}
