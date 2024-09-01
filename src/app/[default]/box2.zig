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

pub fn awake() void {
    box = e.ecs.newEntity("box2") catch {
        e.z.panic("box entity couldn't be created :O");
    };
    {
        display = e.ecs.components.Display{
            .sprite = "empty_icon.png",
            .scaling = .pixelate,
            .tint = e.Color.red,
        };
        box.attach(&display, "display") catch {
            e.z.panic("Player's display couldn't be attached");
        };
    }
    {
        transform = .{
            .position = e.Vector2.init(-64, 0),
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = e.Vector2.init(64, 64),
        };
        box.attach(&transform, "transform") catch {
            e.z.panic("Player's transform couldn't be attached");
        };
    }
    {
        stats = .{
            .movement_speed = 10,
        };
        box.attach(&stats, "stats") catch {
            e.z.panic("Player's stats couldn't be attache");
        };
    }
    {
        collider = .{
            .rect = e.Rectangle.init(0, 0, 64, 64),
            .weight = 6,
            .dynamic = false,
        };
        box.attach(&collider, "collider") catch {
            e.z.panic("box's collider couldn't be attache");
        };
    }
}
