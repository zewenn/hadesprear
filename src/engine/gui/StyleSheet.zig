const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");

const ecs = Import(.ecs);
const z = Import(.z);

const Unit = @import("Unit.zig");

const Self = @This();
const Translate = enum { min, center, max };

top: Unit = Unit.init(0, .px),
left: Unit = Unit.init(0, .px),

translate: struct {
    x: Translate = .min,
    y: Translate = .min,
} = .{},

rotation: f32 = 0,

width: Unit = Unit.init(64, .px),
height: Unit = Unit.init(64, .px),

color: rl.Color = rl.Color.black,

background: struct {
    color: ?rl.Color = null,
    image: ?[]const u8 = null,
} = .{},

font: struct {
    family: []const u8 = "press_play.ttf",
    size: f32 = 12,
    spacing: f32 = 0,
} = .{},

pub fn equals(self: *Self, other: Self) bool {
    if (!self.top.equals(other.top)) return false;
    if (!self.left.equals(other.left)) return false;

    if (self.rotation != other.rotation) return false;

    if (!self.width.equals(other.width)) return false;
    if (!self.height.equals(other.height)) return false;

    if (!self.color.normalize().equals(other.color.normalize()))
        return false;

    if (!self.background_color.normalize().equals(other.background_color.normalize()))
        return false;

    if (self.background_image) |sBgImg| {
        if (other.background_image) |oBgImg| {
            if (!z.arrays.StringEqual(sBgImg, oBgImg)) return false;
        } else return false;
    } else if (other.background_image != null) return false;

    return true;
}

pub fn merge(self: *Self, other: Self) Self {
    var result = self.*;

    if (!z.eql(result.background.color, other.background.color))
        result.background.color = other.background.color;

    if (!z.eql(result.background.image, other.background.image))
        result.background.image = other.background.image;

    if (!z.eql(result.font.family, other.font.family))
        result.font.family = other.font.family;
}
