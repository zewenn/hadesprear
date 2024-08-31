const std = @import("std");
const e = @import("../../engine/engine.zig");
const entity = @import("../entity.zig");

// ===================== [Entity] =====================

var Player: *e.ecs.Entity = undefined;

// =================== [Components] ===================

var pDisplay: e.ecs.cDisplay = undefined;
var pTransform: e.ecs.cTransform = undefined;
var pEntityStats: entity.EntityStats = undefined;

// ===================== [Others] =====================

var menu_music: e.Sound = undefined;

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
            .position = e.Vector2.init(0, 0),
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = e.Vector2.init(64, 64),
        };
        Player.attach(&pTransform, "transform") catch unreachable;
    }
    {
        pEntityStats = .{
            .movement_speed = 10,
        };
        Player.attach(&pEntityStats, "stats") catch unreachable;
    }

    menu_music = e.assets.get(e.Sound, "menu.mp3").?;
}

pub fn init() void {
    e.z.dprint("Hello again!", .{});
    e.playSound(menu_music);
}

pub fn update() void {
    var moveVector = e.Vector2.init(0, 0);

    if (e.isKeyDown(.key_w)) {
        moveVector.y -= 1;
    }
    if (e.isKeyDown(.key_s)) {
        moveVector.y += 1;
    }
    if (e.isKeyDown(.key_a)) {
        moveVector.x -= 1;
    }
    if (e.isKeyDown(.key_d)) {
        moveVector.x += 1;
    }

    const normVec = moveVector.normalize();
    pTransform.position.x += normVec.x * pEntityStats.movement_speed;
    pTransform.position.y += normVec.y * pEntityStats.movement_speed;
}

pub fn deinit() void {
    e.stopSound(menu_music);
    e.unloadSound(menu_music);
}
