const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

const bag_pages: comptime_int = 3;
const bag_page_rows: comptime_int = 4;
const bag_page_cols: comptime_int = 9;
const bag_size: comptime_int = bag_pages * bag_page_rows * bag_page_cols;

pub const Item = conf.Item;

pub var Hands = conf.Item{
    .T = .weapon,
    .damage = 10,
    .weapon_projectile_scale = e.Vec2(64, 64),

    .icon = "sprites/entity/player/weapons/gloves/left.png",
    .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
    .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
};

pub var bag: [bag_size]?conf.Item = [_]?conf.Item{null} ** bag_size;
const equipped = struct {
    pub var current_weapon: *Item = &Hands;
    pub var ring: ?*Item = null;
    pub var amethist: ?*Item = null;
    pub var wayfinder: ?*Item = null;
};

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {}
