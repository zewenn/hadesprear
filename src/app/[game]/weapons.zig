const std = @import("std");
const conf = @import("../../config.zig");
const Allocator = @import("std").mem.Allocator;

const e = @import("../../engine/engine.m.zig");

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
                var right = e.Animator.Animation.init(
                    allocator,
                    "sword_hit_light",
                    e.Animator.interpolation.ease_in_out,
                    0.15,
                );

                right.chain(
                    0,
                    .{
                        .rotation = 0,
                    },
                );
                right.chain(
                    1,
                    .{
                        .rotation = -105,
                    },
                );
                right.chain(
                    2,
                    .{
                        .rotation = 0,
                    },
                );

                try this.right_animator.chain(right);
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

        if (!self.left_animator.isPlaying(id))
            try self.left_animator.play(id);

        if (!self.right_animator.isPlaying(id))
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
            },
            .polearm => {},
            .daggers => {},
            .claymore => {},
            .special => {},
        }
    }
};

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {}
