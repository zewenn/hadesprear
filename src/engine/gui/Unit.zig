const std = @import("std");
const ecs = @import("../ecs/ecs.zig");

const window = @import("../display.zig").window;
const Self = @This();

const UnitEnum = enum {
    px,
    unit,
    percent,
    vw,
    vh,
};

value: f32,
unit: UnitEnum,

pub fn init(value: f32, unit: UnitEnum) Self {
    return Self{
        .value = value,
        .unit = unit,
    };
}

pub fn equals(self: *Self, other: Self) bool {
    if (self.unit != other.unit) return false;
    if (self.value != other.value) return false;
    return true;
}

pub fn calculate(self: *Self, parent: f32, percent_parent: f32) f32 {
    std.log.debug("Unit value: {any}", .{self.value});

    return switch (self.unit) {
        .px => parent + self.value,
        .unit => parent + self.value * 16,
        .percent => percent_parent * (self.value / 100),
        .vw => window.size.x * (self.value / 100),
        .vh => window.size.y * (self.value / 100),
    };
}
