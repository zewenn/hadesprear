const std = @import("std");
const e = @import("../../engine/engine.zig");
const entity = @import("../entity.zig");

// ===================== [Entity] =====================

var Player: *e.ecs.Entity = undefined;

// =================== [Components] ===================

var pDisplay: e.ecs.cDisplay = undefined;
var pTransform: e.ecs.cTransform = undefined;
var pEntityStats: entity.EntityStats = undefined;
var pCollider: e.ecs.cCollider = undefined;
var pAnimator: e.Animator = undefined;

// ===================== [Others] =====================

var menu_music: e.Sound = undefined;
var allocator = std.heap.page_allocator;

// ===================== [Events] =====================

pub fn awake() void {
    Player = e.ecs.newEntity("Player") catch {
        e.z.panic("Player entity couldn't be created :O");
    };

    // Display
    {
        pDisplay = e.ecs.components.Display{
            .sprite = "player_left_0.png",
            .scaling = .pixelate,
        };
        Player.attach(&pDisplay, "display") catch {
            e.z.panic("Player's display couldn't be attached");
        };
    }

    // Transform
    {
        pTransform = .{
            .position = e.Vector2.init(0, 0),
            .rotation = e.Vector3.init(0, 0, 0),
            .scale = e.Vector2.init(64, 64),
        };
        Player.attach(&pTransform, "transform") catch {
            e.z.panic("Player's transform couldn't be attached");
        };
    }

    // Stats
    {
        pEntityStats = .{
            .movement_speed = 10,
        };
        Player.attach(&pEntityStats, "stats") catch {
            e.z.panic("Player's stats couldn't be attache");
        };
    }

    // Collider
    {
        pCollider = .{
            .rect = e.Rectangle.init(0, 0, 64, 64),
            .dynamic = true,
            .weight = 1,
        };
        Player.attach(&pCollider, "collider") catch {
            e.z.panic("Player's collider couldn't be attache");
        };
    }

    // Animator
    {
        pAnimator = e.Animator.init(&allocator, Player) catch {
            e.z.panic("Couldn't create animator");
        };
        {
            var rotateAnim = e.Animator.Animation.init(
                &allocator,
                "rot",
                e.Animator.interpolation.ease_in,
                1,
            );
            // rotateAnim.loop = true;
            {
                rotateAnim.chain(
                    1,
                    .{
                        .rotation = 0,
                        .tint = e.Color.red,
                    },
                );
                rotateAnim.chain(
                    100,
                    .{
                        .rotation = 130,
                        .tint = e.Color.white,
                    },
                );
            }
            pAnimator.chain(rotateAnim) catch e.z.panic("Couldn't chain rotateAnim :()");
        }
        Player.attach(&pAnimator, "animator") catch {
            e.z.panic("Couldn't attach animator to Player");
        };
    }

    menu_music = e.assets.get(e.Sound, "menu.mp3").?;
    e.camera.follow(&(pTransform.position));
}

pub fn init() void {
    e.playSound(menu_music);
    pAnimator.play("rot") catch unreachable;
}

pub fn update() void {
    pAnimator.update();
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
    if (e.isKeyDown(.key_q)) {
        pTransform.rotate(-10);
    }
    if (e.isKeyDown(.key_e)) {
        pTransform.rotate(10);
    }

    const normVec = moveVector.normalize();
    pTransform.position.x += normVec.x * pEntityStats.movement_speed;
    pTransform.position.y += normVec.y * pEntityStats.movement_speed;
}

pub fn deinit() void {
    e.stopSound(menu_music);
    e.unloadSound(menu_music);

    pAnimator.deinit();
}
