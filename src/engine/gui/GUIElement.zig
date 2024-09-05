const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const window = @import("../display.zig").window;

const StyleSheet = @import("StyleSheet.zig");

const rl = @import("raylib");
const ecs = @import("../ecs/ecs.zig");

const Self = @This();

pub const Options = struct {
    id: []const u8,
    style: StyleSheet = StyleSheet{},
};

children: ?std.ArrayList(Self) = null,
contents: ?[]const u8 = null,
parent: ?*Self = null,
options: Options,
transform: ?ecs.cTransform = null,

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

    const x = self.options.style.left.calculate(parent_transform.position.x, parent_transform.scale.x);
    const y = self.options.style.top.calculate(parent_transform.position.y, parent_transform.scale.y);

    const width = self.options.style.width.calculate(0, parent_transform.scale.x);
    const height = self.options.style.height.calculate(0, parent_transform.scale.y);

    self.transform = ecs.cTransform{
        .position = rl.Vector2.init(x, y),
        .rotation = rl.Vector3.init(0, 0, self.options.style.rotation),
        .scale = rl.Vector2.init(width, height),
    };

    return self.transform.?;
}
