const std = @import("std");
const e = @import("../../engine/engine.zig");

// ===================== [Entity] =====================

var Player: *e.ecs.Entity = undefined;

// =================== [Components] ===================

var pDisplay: e.ecs.cDisplay = undefined;
var pTransform: e.ecs.cTransform = undefined;

// ===================== [Others] =====================

// TODO: Add other things here

// ===================== [Events] =====================

pub fn awake() void {
    Player = e.ecs.newEntity("Player") catch unreachable;
    {
        pDisplay = e.ecs.components.Display{
            .sprite = "player_left_0.png",
            .scaling = .pixelate,
        };
        Player.attach(&pDisplay, "display") catch unreachable;
    }
    {
        pTransform = .{
            .position = e.rl.Vector2.init(0, 0),
            .rotation = e.rl.Vector3.init(0, 0, 0),
            .scale = e.rl.Vector2.init(128, 128),
        };
        Player.attach(&pTransform, "transform") catch unreachable;
    }
}

pub fn init() void {
    e.z.dprint("Hello again!", .{});
}

pub fn update() void {
    var moveVector = e.rl.Vector2.init(0, 0);

    if (e.rl.isKeyDown(.key_w)) {
        moveVector.y -= 1;
    }
    if (e.rl.isKeyDown(.key_s)) {
        moveVector.y += 1;
    }
    if (e.rl.isKeyDown(.key_a)) {
        moveVector.x -= 1;
    }
    if (e.rl.isKeyDown(.key_d)) {
        moveVector.x += 1;
    }

    const normVec = moveVector.normalize();
    pTransform.position.x += normVec.x;
    pTransform.position.y += normVec.y;
}

pub fn deinit() void {}
