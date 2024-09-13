const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);
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
var h0Animator: e.Animator = undefined;

var h1Display: e.ecs.cDisplay = undefined;
var h1Transform: e.ecs.cTransform = undefined;
var h1Animator: e.Animator = undefined;

// ===================== [Others] =====================

var menu_music: e.Sound = undefined;
var allocator = std.heap.page_allocator;

var p_facing: enum { left, right } = .left;

const weapons = struct {
    var gloves: Weapon = undefined;
    var plates: Weapon = undefined;

    var current: ?*Weapon = null;

    pub fn equip(weapon: *Weapon) void {
        current = weapon;
        h0Display.sprite = current.?.sprites.left;
        h1Display.sprite = current.?.sprites.right;
    }

    const types = enum {
        gloves,
        plates,
    };

    const Sprites = struct {
        left: []const u8,
        right: []const u8,
    };

    const Weapon = struct {
        const Self = @This();

        type: types,
        sprites: Sprites,
        damage: f32,
        pojectile_transform: e.ecs.cTransform,

        pub fn init(
            T: types,
            sprites: Sprites,
            damage: f32,
            projectile_transorm: e.ecs.cTransform,
        ) Self {
            return Self{
                .type = T,
                .sprites = sprites,
                .damage = damage,
                .pojectile_transform = projectile_transorm,
            };
        }

        pub fn deinit(self: *Self) void {
            allocator.free(self.sprites.left);
            allocator.free(self.sprites.right);
        }

        pub fn equip(self: *Self) void {
            weapons.equip(self);
        }

        pub fn deequip(self: *Self) void {
            if (!e.z.eql(self, current)) return;
            current = null;
        }
    };

    fn getSideSpecificSprite(
        prefix: []const u8,
        middle: []const u8,
        side: enum { left, right },
        ext: []const u8,
    ) ![]u8 {
        var final_zS = e.zString.init(allocator);
        defer final_zS.deinit();

        try final_zS.concat(prefix);
        try final_zS.concat("_");
        try final_zS.concat(middle);
        try final_zS.concat("_");
        try final_zS.concat(switch (side) {
            .left => "left",
            .right => "right",
        });
        try final_zS.concat(ext);

        return (try final_zS.toOwned()).?;
    }

    /// Returned Sprites object conntains heap allocated
    /// string slices which will be automatically freed
    /// when `Weapon.deinit()` is called
    pub fn getSprites(T: types) !Sprites {
        const middle_string: []const u8 = switch (T) {
            .gloves => "gloves",
            .plates => "plates",
        };

        const prefix = "wpn";
        const fileext = ".png";

        return Sprites{
            .left = try getSideSpecificSprite(
                prefix,
                middle_string,
                .left,
                fileext,
            ),
            .right = try getSideSpecificSprite(
                prefix,
                middle_string,
                .right,
                fileext,
            ),
        };
    }
};

const HAND_DISTANCE: comptime_float = 24;
const HIT_GLOVE_DISTANCE: f32 = 100;
const HIT_PLATES_ROTATION: f32 = 42.5;

fn playAttack(cw: *weapons.Weapon) !void {
    switch (cw.type) {
        .gloves => {
            try h0Animator.play("hit_gloves");
            try e.setTimeout(
                0.125,
                struct {
                    pub fn cb() !void {
                        try h1Animator.play("hit_gloves");
                    }
                }.cb,
            );
        },
        .plates => {
            try h0Animator.play("hit_plates");
            try h1Animator.play("hit_plates");
        },
    }
}

// ===================== [Events] =====================

pub fn awake() !void {
    e.z.debug.disable();

    // Player
    {
        Player = try e.ecs.newEntity("Player");

        // Display
        {
            pDisplay = e.ecs.components.Display{
                .sprite = "player_left_0.png",
                .scaling = .pixelate,
            };
            try Player.attach(&pDisplay, "display");
        }

        // Transform
        {
            pTransform = .{
                .position = e.Vector2.init(0, 0),
                .rotation = e.Vector3.init(0, 0, 0),
                .scale = e.Vector2.init(64, 64),
            };
            try Player.attach(&pTransform, "transform");
        }

        // Stats
        {
            pEntityStats = .{
                .movement_speed = 350,
            };
            try Player.attach(&pEntityStats, "stats");
        }

        // Collider
        {
            pCollider = .{
                .rect = e.Rectangle.init(0, 0, 64, 64),
                .dynamic = true,
                .weight = 1,
            };
            try Player.attach(&pCollider, "collider");
        }

        // Animator
        {
            pAnimator = try e.Animator.init(&allocator, Player);
            try Player.attach(&pAnimator, "animator");

            // Walk left anim
            {
                var walk_left_anim = e.Animator.Animation.init(
                    &allocator,
                    "walk_left",
                    e.Animator.interpolation.ease_in,
                    0.25,
                );
                {
                    walk_left_anim.chain(
                        1,
                        .{
                            .sprite = "player_left_0.png",
                            .rotation = 0,
                        },
                    );
                    walk_left_anim.chain(
                        2,
                        .{
                            .sprite = "player_left_1.png",
                            .rotation = -2.5,
                        },
                    );
                    walk_left_anim.chain(
                        3,
                        .{
                            .sprite = "player_left_0.png",
                            .rotation = 0,
                        },
                    );
                }
                try pAnimator.chain(walk_left_anim);
            }

            // Walk right anim
            {
                var walk_right_anim = e.Animator.Animation.init(
                    &allocator,
                    "walk_right",
                    e.Animator.interpolation.ease_in,
                    0.25,
                );
                // rotateAnim.loop = true;
                {
                    walk_right_anim.chain(
                        1,
                        .{
                            .sprite = "player_right_0.png",
                            .rotation = 0,
                        },
                    );
                    walk_right_anim.chain(
                        2,
                        .{
                            .sprite = "player_right_1.png",
                            .rotation = 2.5,
                        },
                    );
                    walk_right_anim.chain(
                        3,
                        .{
                            .sprite = "player_right_0.png",
                            .rotation = 0,
                        },
                    );
                }
                try pAnimator.chain(walk_right_anim);
            }
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

        // Animator
        {
            h0Animator = try e.Animator.init(&allocator, Hand0);
            try Hand0.attach(&h0Animator, "animator");

            {
                var hit_gloves = e.Animator.Animation.init(
                    &allocator,
                    "hit_gloves",
                    e.Animator.interpolation.ease_out,
                    0.25,
                );
                {
                    hit_gloves.chain(
                        1,
                        .{
                            .y = 0,
                        },
                    );
                    hit_gloves.chain(
                        2,
                        .{
                            .y = HIT_GLOVE_DISTANCE,
                        },
                    );
                    hit_gloves.chain(
                        3,
                        .{
                            .y = 0,
                        },
                    );
                }
                try h0Animator.chain(hit_gloves);
            }
            {
                var hit_plates = e.Animator.Animation.init(
                    &allocator,
                    "hit_plates",
                    e.Animator.interpolation.ease_out,
                    0.25,
                );
                {
                    hit_plates.chain(
                        1,
                        .{
                            .rotation = 0,
                        },
                    );
                    hit_plates.chain(
                        2,
                        .{
                            .rotation = -HIT_PLATES_ROTATION,
                        },
                    );
                    hit_plates.chain(
                        3,
                        .{
                            .rotation = 0,
                        },
                    );
                }
                try h0Animator.chain(hit_plates);
            }
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

        // Animator
        {
            h1Animator = try e.Animator.init(&allocator, Hand1);
            try Hand1.attach(&h1Animator, "animator");

            {
                var hit_gloves = e.Animator.Animation.init(
                    &allocator,
                    "hit_gloves",
                    e.Animator.interpolation.ease_out,
                    0.25,
                );
                {
                    hit_gloves.chain(
                        1,
                        .{
                            .y = 0,
                        },
                    );
                    hit_gloves.chain(
                        2,
                        .{
                            .y = HIT_GLOVE_DISTANCE,
                        },
                    );
                    hit_gloves.chain(
                        3,
                        .{
                            .y = 0,
                        },
                    );
                }
                try h1Animator.chain(hit_gloves);
            }
            {
                var hit_plates = e.Animator.Animation.init(
                    &allocator,
                    "hit_plates",
                    e.Animator.interpolation.ease_out,
                    0.25,
                );
                {
                    hit_plates.chain(
                        1,
                        .{
                            .rotation = 0,
                        },
                    );
                    hit_plates.chain(
                        2,
                        .{
                            .rotation = HIT_PLATES_ROTATION,
                        },
                    );
                    hit_plates.chain(
                        3,
                        .{
                            .rotation = 0,
                        },
                    );
                }
                try h1Animator.chain(hit_plates);
            }
        }
    }

    weapons.gloves = weapons.Weapon.init(
        .gloves,
        try weapons.getSprites(.gloves),
        20,
        e.ecs.cTransform.new(),
    );
    weapons.plates = weapons.Weapon.init(
        .plates,
        try weapons.getSprites(.plates),
        20,
        e.ecs.cTransform.new(),
    );

    e.camera.follow(&pTransform.position);
}

pub fn init() !void {
    weapons.plates.equip();
    // weapons.gloves.equip();
}

pub fn update() !void {
    var moveVector = e.Vector2.init(0, 0);

    // Movement
    {
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

        if (weapons.current) |cw| {
            if (e.isKeyPressed(.key_tab)) {
                switch (cw.type) {
                    .gloves => weapons.plates.equip(),
                    .plates => weapons.gloves.equip(),
                }

                try playAttack(weapons.current.?);
            }
            if (e.isMouseButtonPressed(.mouse_button_left)) {
                try playAttack(cw);
            }
        }

        const normVec = moveVector.normalize();
        pTransform.position.x += normVec.x * pEntityStats.movement_speed * e.getFrameTime();
        pTransform.position.y += normVec.y * pEntityStats.movement_speed * e.getFrameTime();
    }

    // Animator
    Animator: {
        pAnimator.update();
        h0Animator.update();
        h1Animator.update();

        if (moveVector.x < 0 and !pAnimator.isPlaying("walk_left")) {
            pAnimator.stop("walk_right");
            try pAnimator.play("walk_left");

            p_facing = .left;
        }
        if (moveVector.x > 0 and !pAnimator.isPlaying("walk_right")) {
            pAnimator.stop("walk_left");
            try pAnimator.play("walk_right");

            p_facing = .right;
        }

        if (moveVector.y == 0) break :Animator;

        if (pAnimator.isPlaying("walk_left") or pAnimator.isPlaying("walk_right")) break :Animator;

        try pAnimator.play(
            switch (p_facing) {
                .left => "walk_left",
                .right => "walk_right",
            },
        );
    }

    // Hands
    {
        const mouse_pos = e.getMousePosition();
        const mouse_relative_pos = e.Vector2.init(
            mouse_pos.x - e.window.size.x / 2,
            mouse_pos.y - e.window.size.y / 2,
        );

        var rotator_vector0 = e.Vector2.init(HAND_DISTANCE, h0Transform.scale.x);
        if (h0Animator.isPlaying("hit_gloves")) {
            rotator_vector0.x += h0Transform.position.y;
        }

        const finished0 = rotator_vector0.rotate(std.math.degreesToRadians(90)).negate();

        var rotator_vector1 = e.Vector2.init(HAND_DISTANCE, 0);
        if (h1Animator.isPlaying("hit_gloves")) {
            rotator_vector1.x += h1Transform.position.y;
        }

        const finished1 = rotator_vector1.rotate(std.math.degreesToRadians(90)).negate();

        h0Transform.anchor = finished0;
        h1Transform.anchor = finished1;

        const rotation: f32 = std.math.radiansToDegrees(std.math.atan2(mouse_relative_pos.y, mouse_relative_pos.x)) - 90;

        h0Transform.position = .{
            .x = pTransform.position.x,
            .y = pTransform.position.y,
        };
        h0Transform.rotation.z = GetRotation: {
            var rot = rotation;
            if (weapons.current) |cw| {
                if (cw.type == .plates) rot += 20;
            }

            if (!h0Animator.isPlaying("hit_plates")) break :GetRotation rot;

            break :GetRotation rot + h0Transform.rotation.z;
        };
        h1Transform.position = .{
            .x = pTransform.position.x + 0,
            .y = pTransform.position.y + 0,
        };
        h1Transform.rotation.z = GetRotation: {
            var rot = rotation;
            if (weapons.current) |cw| {
                if (cw.type == .plates) rot -= 20;
            }

            if (!h1Animator.isPlaying("hit_plates")) break :GetRotation rot;

            break :GetRotation rot + h1Transform.rotation.z;
        };
    }
}

pub fn deinit() !void {
    pAnimator.deinit();
    h0Animator.deinit();
    h1Animator.deinit();

    weapons.gloves.deinit();
    weapons.plates.deinit();
}
