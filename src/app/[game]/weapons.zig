const std = @import("std");
const conf = @import("../../config.zig");
const Allocator = @import("std").mem.Allocator;

const e = @import("../../engine/engine.m.zig");

pub const OnHit = struct {
    entity: *e.entities.Entity,
    T: conf.on_hit_effects,
    delta: f32,
    end_time: f64,
};

pub const on_hits = struct {
    const T = OnHit;
    const options: struct {
        max_size: usize = 8_000_000,
        max_entities: ?usize = null,
    } = .{
        .max_size = 8_000_000,
        .max_entities = 128,
    };

    pub const TSize: comptime_int = @sizeOf(T);
    pub const MaxArraySize: comptime_int = @divTrunc(options.max_size, TSize);
    pub const ArraySize: comptime_int = if (options.max_entities) |max| @min(max, MaxArraySize) else MaxArraySize;
    pub var array: [ArraySize]?T = [_]?T{null} ** ArraySize;

    /// This will search for the next free *(value == null)*
    /// index in the array and return it.
    /// If there are no available indexes in the array and override is:
    /// - **false**: it will override the 0th address.
    /// - **true**: it will randomly return an address.
    pub fn searchNextIndex(override: bool) usize {
        for (array, 0..) |value, index| {
            if (index == 0) continue;
            if (value == null) return index;
        }

        // No null, everything is used...

        // This saves your ass 1 time
        if (!override) {
            array[0] = null;
            return 0;
        }

        const rIndex = std.crypto.random.uintLessThan(usize, ArraySize);

        if (array[rIndex]) |_| {
            free(rIndex);
        }

        array[rIndex] = null;
        return rIndex;
    }

    /// Uses the `searchNextIndex()` function to get an index
    /// and puts the value into it
    pub fn malloc(value: T) void {
        const index = searchNextIndex(true);
        array[index] = value;
    }

    /// Sets the value of the index to `null`
    pub fn free(index: usize) void {
        array[index] = null;
    }
};

fn calculateStrength(base: f32) f32 {
    return (-(1 / (base + 1)) + 1) * 2;
}

pub inline fn applyOnHitEffect(
    entity: *?e.entities.Entity,
    effect: conf.on_hit_effects,
    strength: f32,
) void {
    const en = e.zlib.nullAssertOptionalPointer(
        e.entities.Entity,
        entity,
    ) catch return;

    const scaled_strength: f32 = (-(1 / (strength + 1)) + 1) * 10;
    if (en.entity_stats == null) return;

    var use_timeout: bool = true;

    var new: f32 = 0;
    var old: f32 = 0;
    var delta: f32 = 0;

    switch (effect) {
        .none => use_timeout = false,
        .vamp => {
            use_timeout = false;

            en.entity_stats.?.health *= scaled_strength;
        },
        .energized => {
            use_timeout = true;

            new = std.math.clamp(
                en.entity_stats.?.movement_speed * calculateStrength(strength),
                -1 * en.entity_stats.?.max_movement_speed,
                en.entity_stats.?.max_movement_speed,
            );
            old = en.entity_stats.?.movement_speed;
            en.entity_stats.?.movement_speed = new;
        },
        .stengthen => {
            use_timeout = true;

            new = en.entity_stats.?.damage * calculateStrength(strength);
            old = en.entity_stats.?.damage;
            en.entity_stats.?.damage = new;
        },
    }

    if (!use_timeout) return;

    delta = new - old;

    on_hits.malloc(.{
        .entity = en,
        .delta = delta,
        .T = effect,
        .end_time = e.time.gameTime + std.math.clamp(strength / 3, 0, 15),
    });
}

pub const Hands = struct {
    const hit_types = enum {
        light,
        heavy,
        dash,
    };

    const Self = @This();

    left: *e.entities.Entity,
    right: *e.entities.Entity,
    left_animator: e.Animator,
    right_animator: e.Animator,
    playing_left: bool = false,
    playing_right: bool = false,
    left_base_rotation: f32 = 0,
    right_base_rotation: f32 = 0,
    animation_attack_speed_ration: f32 = 0.8,

    light_hit_anim: []const u8 = "sword_hit_light",
    heavy_hit_anim: []const u8 = "sword_hit_heavy",
    dash_hit_anim: []const u8 = "sword_hit_dash",

    current_weapon: ?*conf.Item = null,

    pub fn init(
        allocator: *Allocator,
        left_hand: *e.entities.Entity,
        right_hand: *e.entities.Entity,
    ) !Self {
        var this = Self{
            .left = left_hand,
            .right = right_hand,
            .left_animator = e.Animator.init(allocator, left_hand),
            .right_animator = e.Animator.init(allocator, right_hand),
        };

        // Sword animation
        SwordAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.15,
                );

                light.chain(
                    0,
                    .{
                        .rotation = 0,
                    },
                );
                light.chain(
                    1,
                    .{
                        .rotation = -105,
                    },
                );
                light.chain(
                    2,
                    .{
                        .rotation = 0,
                    },
                );

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                heavy.chain(
                    0,
                    .{
                        .rotation = 0,
                    },
                );
                heavy.chain(
                    1,
                    .{
                        .rotation = -180,
                    },
                );
                heavy.chain(
                    2,
                    .{
                        .rotation = 0,
                    },
                );

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                dash.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                    },
                );
                dash.chain(
                    25,
                    .{
                        .ry = 24,
                        .rotation = -60,
                    },
                );
                dash.chain(
                    50,
                    .{ .ry = 128, .rx = -1 * right_hand.transform.scale.x / 2, .rotation = -60 },
                );
                dash.chain(
                    100,
                    .{
                        .ry = 0,
                        .rotation = 0,
                    },
                );

                try this.right_animator.chain(dash);
                break :Right;
            }

            break :SwordAnimation;
        }
        // Polearm animation
        PolearmAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "polearm_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.15,
                );

                light.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                        .rx = 0,
                    },
                );
                light.chain(
                    1,
                    .{
                        .rotation = -10,
                        .ry = 48,
                        .rx = 24,
                    },
                );
                light.chain(
                    2,
                    .{
                        .rotation = 0,
                        .ry = 0,
                        .rx = 0,
                    },
                );

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "polearm_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );

                heavy.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                        .rx = 0,
                    },
                );
                heavy.chain(
                    1,
                    .{
                        .rotation = -10,
                        .ry = -24,
                        .rx = -12,
                    },
                );
                heavy.chain(
                    2,
                    .{
                        .rotation = -10,
                        .ry = 64,
                        .rx = 24,
                    },
                );
                heavy.chain(
                    3,
                    .{
                        .rotation = -10,
                        .ry = 64,
                        .rx = 24,
                    },
                );
                heavy.chain(
                    4,
                    .{
                        .rotation = 0,
                        .ry = 0,
                        .rx = 0,
                    },
                );

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "polearm_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    dash.chain(
                        0,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    dash.chain(
                        1,
                        .{
                            .rotation = -10,
                            .ry = -24,
                            .rx = -12,
                        },
                    );
                    dash.chain(
                        2,
                        .{
                            .rotation = -10,
                            .ry = 64,
                            .rx = 24,
                        },
                    );
                    dash.chain(
                        3,
                        .{
                            .rotation = -10,
                            .ry = 64,
                            .rx = 24,
                        },
                    );
                    dash.chain(
                        4,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                }

                try this.right_animator.chain(dash);
                break :Right;
            }

            break :PolearmAnimation;
        }
        // Daggers animation
        DaggersAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.15,
                );
                {
                    light.chain(
                        0,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    light.chain(
                        1,
                        .{
                            .rotation = 10,
                            .ry = 48,
                        },
                    );
                    light.chain(
                        2,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                }

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    heavy.chain(
                        0,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    heavy.chain(
                        1,
                        .{
                            .rotation = 0,
                            .ry = 80,
                        },
                    );
                    heavy.chain(
                        2,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                }

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    dash.chain(
                        0,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    dash.chain(
                        25,
                        .{
                            .ry = -24,
                            .rx = 12,
                            .rotation = -360,
                        },
                    );
                    dash.chain(
                        100,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                }

                try this.right_animator.chain(dash);
                break :Right;
            }
            Left: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.2,
                );
                {
                    light.chain(
                        0,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    light.chain(
                        1,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    light.chain(
                        2,
                        .{
                            .rotation = -10,
                            .ry = 48,
                        },
                    );
                    light.chain(
                        3,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                }

                try this.left_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_heavy",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );
                {
                    heavy.chain(
                        0,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                    heavy.chain(
                        2,
                        .{
                            .rotation = 0,
                            .ry = 80,
                        },
                    );
                    heavy.chain(
                        3,
                        .{
                            .rotation = 0,
                            .ry = 0,
                            .rx = 0,
                        },
                    );
                }
                try this.left_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "daggers_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.35,
                    // 5,
                );

                dash.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                        .rx = 0,
                    },
                );
                dash.chain(
                    25,
                    .{
                        .ry = -24,
                        .rx = 12,
                        .rotation = -360,
                    },
                );
                dash.chain(
                    100,
                    .{
                        .rotation = 0,
                        .ry = 0,
                        .rx = 0,
                    },
                );

                try this.left_animator.chain(dash);
                break :Left;
            }

            break :DaggersAnimation;
        }
        // Claymore animation
        SwordAnimation: {
            Right: {
                var light = e.Animator.Animation.init(
                    allocator,
                    "claymore_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.5,
                );

                light.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                    },
                );
                light.chain(
                    1,
                    .{
                        .rotation = -360,
                        .ry = 64,
                    },
                );
                light.chain(
                    2,
                    .{
                        .rotation = -360,
                        .ry = 0,
                    },
                );

                try this.right_animator.chain(light);

                var heavy = e.Animator.Animation.init(
                    allocator,
                    "claymore_hit_heavy",
                    e.Animator.interpolation.ease_out,
                    0.25,
                );

                heavy.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                    },
                );
                heavy.chain(
                    1,
                    .{
                        .rotation = -720,
                        .ry = 128,
                    },
                );
                heavy.chain(
                    1,
                    .{
                        .rotation = -720,
                        .ry = 64,
                    },
                );
                heavy.chain(
                    2,
                    .{
                        .rotation = -720,
                        .ry = 0,
                    },
                );

                try this.right_animator.chain(heavy);

                var dash = e.Animator.Animation.init(
                    allocator,
                    "claymore_hit_dash",
                    e.Animator.interpolation.ease_in_out,
                    0.25,
                );

                dash.chain(
                    0,
                    .{
                        .rotation = 0,
                        .ry = 0,
                    },
                );
                dash.chain(
                    1,
                    .{
                        .ry = 0,
                        .rotation = 180,
                    },
                );
                dash.chain(
                    2,
                    .{
                        .ry = 24,
                        .rotation = -90,
                    },
                );
                dash.chain(
                    3,
                    .{
                        .ry = 24,
                        .rotation = -90,
                    },
                );
                dash.chain(
                    4,
                    .{
                        .ry = 24,
                        .rotation = -90,
                    },
                );
                dash.chain(
                    5,
                    .{
                        .ry = 0,
                        .rotation = 0,
                    },
                );

                try this.right_animator.chain(dash);
                break :Right;
            }

            break :SwordAnimation;
        }
        return this;
    }

    pub fn deinit(self: *Self) void {
        self.left_animator.deinit();
        self.right_animator.deinit();
    }

    pub fn update(self: *Self) void {
        self.left_animator.update();
        self.right_animator.update();

        self.playing_left = self.left_animator.playing.items.len != 0;
        self.playing_right = self.right_animator.playing.items.len != 0;
    }

    pub fn play(
        self: *Self,
        T: hit_types,
    ) !void {
        const id = switch (T) {
            .light => self.light_hit_anim,
            .heavy => self.heavy_hit_anim,
            .dash => self.dash_hit_anim,
        };

        // if (!self.left_animator.isPlaying(id))
        self.left_animator.stop(id);
        try self.left_animator.play(id);

        // if (!self.right_animator.isPlaying(id))
        self.right_animator.stop(id);
        try self.right_animator.play(id);
    }

    pub fn equip(self: *Self, item: *conf.Item) void {
        const reset = Get: {
            if (self.current_weapon == null) break :Get false;
            if (self.current_weapon.?.id != item.id) break :Get false;

            break :Get true;
        };

        if (reset) return;

        self.current_weapon = item;

        self.left.display.sprite = item.weapon_sprite_left;
        self.right.display.sprite = item.weapon_sprite_right;

        switch (item.weapon_type) {
            .sword => {
                self.right.transform.scale = e.Vec2(48, 96);
                self.left.transform.scale = e.Vec2(0, 0);

                self.right_base_rotation = 60;

                self.light_hit_anim = "sword_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "sword_hit_light",
                    else => "sword_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "sword_hit_dash",
                    else => "sword_hit_light",
                };
            },
            .polearm => {
                self.right.transform.scale = e.Vec2(48, 128);
                self.left.transform.scale = e.Vec2(0, 0);

                self.right_base_rotation = 10;

                self.light_hit_anim = "polearm_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "polearm_hit_light",
                    else => "polearm_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "polearm_hit_dash",
                    else => "polearm_hit_light",
                };
            },
            .daggers => {
                self.right.transform.scale = e.Vec2(48, 48);
                self.left.transform.scale = e.Vec2(48, 48);

                self.right_base_rotation = -10;
                self.left_base_rotation = 10;

                self.light_hit_anim = "daggers_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "daggers_hit_light",
                    else => "daggers_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "daggers_hit_dash",
                    else => "daggers_hit_light",
                };
            },
            .claymore => {
                self.right.transform.scale = e.Vec2(48, 192);
                self.left.transform.scale = e.Vec2(0, 0);

                self.right_base_rotation = 85;

                self.light_hit_anim = "claymore_hit_light";
                self.heavy_hit_anim = switch (item.rarity) {
                    .common => "claymore_hit_light",
                    else => "claymore_hit_heavy",
                };
                self.dash_hit_anim = switch (item.rarity) {
                    .legendary => "claymore_hit_dash",
                    else => "claymore_hit_light",
                };
            },
            .special => {},
        }

        if (self.left_animator.animations.getPtr(self.light_hit_anim)) |anim| {
            anim.transition_time = item.attack_speed * item.weapon_light.attack_speed_modifier * self.animation_attack_speed_ration;
            anim.recalculateTransitionTimePerKeyFrame();
        }
        if (self.right_animator.animations.getPtr(self.light_hit_anim)) |anim| {
            anim.transition_time = item.attack_speed * item.weapon_light.attack_speed_modifier * self.animation_attack_speed_ration;
            anim.recalculateTransitionTimePerKeyFrame();
        }

        if (!std.mem.eql(u8, self.heavy_hit_anim, self.light_hit_anim)) {
            if (self.left_animator.animations.getPtr(self.heavy_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_heavy.attack_speed_modifier * self.animation_attack_speed_ration;
                anim.recalculateTransitionTimePerKeyFrame();
            }
            if (self.right_animator.animations.getPtr(self.heavy_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_heavy.attack_speed_modifier * self.animation_attack_speed_ration;
                anim.recalculateTransitionTimePerKeyFrame();
            }
        }

        if (!std.mem.eql(u8, self.dash_hit_anim, self.light_hit_anim)) {
            if (self.left_animator.animations.getPtr(self.dash_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_dash.attack_speed_modifier * self.animation_attack_speed_ration;
                anim.recalculateTransitionTimePerKeyFrame();
            }
            if (self.right_animator.animations.getPtr(self.dash_hit_anim)) |anim| {
                anim.transition_time = item.attack_speed * item.weapon_dash.attack_speed_modifier * self.animation_attack_speed_ration;
                anim.recalculateTransitionTimePerKeyFrame();
            }
        }
    }
};

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {
    for (on_hits.array, 0..) |it, index| {
        const item: *OnHit = if (it) |_| &(on_hits.array[index].?) else continue;

        if (item.end_time >= e.time.gameTime) continue;

        switch (item.T) {
            .energized => {
                item.entity.entity_stats.?.movement_speed -= item.delta;
            },
            .stengthen => {
                item.entity.entity_stats.?.damage -= item.delta;
            },
            else => {},
        }

        on_hits.free(index);
    }
}

pub fn deinit() !void {}
