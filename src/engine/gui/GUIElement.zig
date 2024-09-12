const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const window = Import(.display).window;

const StyleSheet = @import("StyleSheet.zig");
const ButtonInterface = @import("ButtonInterface.zig");

const rl = @import("raylib");
const ecs = Import(.ecs);

const Self = @This();

pub const Options = struct {
    id: []const u8,
    class: []const u8 = "",
    style: StyleSheet = StyleSheet{},
    hover: StyleSheet = StyleSheet{},
};

children: ?std.ArrayList(*Self) = null,
contents: ?[*:0]const u8 = null,
parent: ?*Self = null,
options: Options,
transform: ?ecs.cTransform = null,
is_button: bool = false,
button_interface_ptr: ?*ButtonInterface = null,
is_hovered: bool = false,

/// Sets the elements transform and returns the value.
/// Might calculate the parent elements value.
pub fn calculateTransform(self: *Self) ecs.cTransform {
    var parent_transform: ecs.cTransform = ecs.cTransform{
        .position = rl.Vector2.init(0, 0),
        .rotation = rl.Vector3.init(0, 0, 0),
        .scale = rl.Vector2.init(window.size.x, window.size.y),
    };

    // std.log.warn("parent: {any}", .{self.transform});
    if (self.parent) |parent| {
        if (parent.transform == null) {
            _ = parent.calculateTransform();
        }
        if (parent.transform) |ptrnsfrm| {
            parent_transform = ptrnsfrm;
        }
    }

    var style = GetStyle: {
        if (self.is_hovered) {
            break :GetStyle self.options.style.merge(self.options.hover);
        }
        break :GetStyle self.options.style;
    };

    const x = style.left.calculate(parent_transform.position.x, parent_transform.scale.x);
    const y = style.top.calculate(parent_transform.position.y, parent_transform.scale.y);

    const width = style.width.calculate(0, parent_transform.scale.x);
    const height = style.height.calculate(0, parent_transform.scale.y);

    self.transform = ecs.cTransform{
        .position = rl.Vector2.init(x, y),
        .rotation = rl.Vector3.init(0, 0, style.rotation),
        .scale = rl.Vector2.init(width, height),
        .anchor = CalculateAnchor: {
            var anchor = rl.Vector2.init(0, 0);

            switch (style.translate.x) {
                .min => anchor.x = 0,
                .center => anchor.x = width / 2,
                .max => anchor.x = width,
            }
            switch (style.translate.y) {
                .min => anchor.y = 0,
                .center => anchor.y = height / 2,
                .max => anchor.y = height,
            }
            break :CalculateAnchor anchor;
        },
    };

    return self.transform.?;
}

pub fn addChild(self: *Self, child: *Self) !void {
    if (self.children) |*children| {
        child.parent = self;
        try children.append(child);
    }
}
