const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");

const ecs = Import(.ecs);
const window = Import(.display).window;

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
    return switch (self.unit) {
        .px => parent + self.value,
        .unit => parent + self.value * 16,
        .percent => percent_parent * (self.value / 100),
        .vw => parent + window.size.x * (self.value / 100),
        .vh => parent + window.size.y * (self.value / 100),
    };
}

/// Parses the given input, if the input is incorrect
/// *(syntax is not `<number><'x' | 'u' | '%' | 'h' | 'w'>`)* returns 0x/0 pixels,
pub fn u(from: []const u8) Self {
    const str_value = from[0 .. from.len - 1];
    const str_unit = from[from.len - 1 ..];

    const unit: UnitEnum = switch (str_unit[0]) {
        'x' => .px,
        'u' => .unit,
        '%' => .percent,
        'h' => .vh,
        'w' => .vw,
        else => .px,
    };

    const float_value = std.fmt.parseFloat(f32, str_value) catch 0;

    return Self{
        .value = float_value,
        .unit = unit,
    };
}
