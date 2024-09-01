const std = @import("std");
const e = @import("../../engine/engine.zig");
const entity = @import("../entity.zig");

// ===================== [Entity] =====================

var Player: *e.ecs.Entity = undefined;
var Hand0: *e.ecs.Entity = undefined;
var Hand1: *e.ecs.Entity = undefined;

// =================== [Components] ===================

var pDisplay: e.ecs.cDisplay = undefined;
var pTransform: e.ecs.cTransform = undefined;
var pEntityStats: entity.EntityStats = undefined;
var pCollider: e.ecs.cCollider = undefined;
var pAnimator: e.Animator = undefined;

var h0Display: e.ecs.cDisplay = undefined;
var h0Transform: e.ecs.cTransform = undefined;

var h1Display: e.ecs.cDisplay = undefined;
var h1Transform: e.ecs.cTransform = undefined;

// ===================== [Others] =====================

var menu_music: e.Sound = undefined;
var allocator = std.heap.page_allocator;

const HAND_DISTANCE: comptime_float = 32;

// ===================== [Events] =====================

pub fn awake() void {

    // Player
    {
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
                .movement_speed = 350,
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
    }

    // Hand0
    {
        Hand0 = e.ecs.newEntity("player_hand_a") catch {
            e.z.panic("Player hand a was unable to load");
        };

        // Display
        {
            h0Display = .{
                .sprite = "gloves_0.png",
                .scaling = .pixelate,
                .tint = e.Color.white,
            };
            Hand0.attach(&h0Display, "display") catch {
                e.z.panic("Hand0 display couldn't be attached!");
            };
        }

        // Transform
        {
            h0Transform = .{
                .position = e.Vector2.init(0, 0),
                .rotation = e.Vector3.init(0, 0, 0),
                .scale = e.Vector2.init(48, 48),
                .anchor = e.Vector2.init(-16, -16),
            };
            Hand0.attach(&h0Transform, "transform") catch {
                e.z.panic("Hand0 transform couldn't be attached");
            };
        }
    }
    // Hand1
    {
        Hand1 = e.ecs.newEntity("player_hand_1") catch {
            e.z.panic("Player hand 1 was unable to load");
        };

        // Display
        {
            h1Display = .{
                .sprite = "gloves_1.png",
                .scaling = .pixelate,
                .tint = e.Color.white,
            };
            Hand1.attach(&h1Display, "display") catch {
                e.z.panic("Hand1 display couldn't be attached!");
            };
        }

        // Transform
        {
            h1Transform = .{
                .position = e.Vector2.init(0, 0),
                .rotation = e.Vector3.init(0, 0, 0),
                .scale = e.Vector2.init(48, 48),
                .anchor = e.Vector2.init(-16, -16),
            };
            Hand1.attach(&h1Transform, "transform") catch {
                e.z.panic("Hand1 transform couldn't be attached");
            };
        }
    }

    menu_music = e.assets.get(e.Sound, "menu.mp3").?;
    e.camera.follow(&(pTransform.position));
}

pub fn init() void {
    e.playSound(menu_music);
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
    pTransform.position.x += normVec.x * pEntityStats.movement_speed * e.getFrameTime();
    pTransform.position.y += normVec.y * pEntityStats.movement_speed * e.getFrameTime();

    // Hands
    {
        const mouse_pos = e.getMousePosition();
        const mouse_relative_pos = e.Vector2.init(
            mouse_pos.x - e.window.size.x / 2,
            mouse_pos.y - e.window.size.y / 2,
        );

        var rotator_vector0 = e.Vector2.init(HAND_DISTANCE, h0Transform.scale.x);
        const finished0 = rotator_vector0.rotate(std.math.degreesToRadians(90)).negate();

        var rotator_vector1 = e.Vector2.init(HAND_DISTANCE, 0);
        const finished1 = rotator_vector1.rotate(std.math.degreesToRadians(90)).negate();

        h0Transform.anchor = finished0;
        h1Transform.anchor = finished1;

        const rotation: f32 = std.math.radiansToDegrees(std.math.atan2(mouse_relative_pos.y, mouse_relative_pos.x)) - 90;

        h0Transform.position = .{
            .x = pTransform.position.x + 24,
            .y = pTransform.position.y + 24,
        };
        h0Transform.rotation.z = rotation;
        h1Transform.position = .{
            .x = pTransform.position.x + 24,
            .y = pTransform.position.y + 24,
        };
        h1Transform.rotation.z = rotation;
    }
}

pub fn deinit() void {
    e.stopSound(menu_music);
    e.unloadSound(menu_music);

    pAnimator.deinit();
}
