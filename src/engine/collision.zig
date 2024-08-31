const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = @import("./z/z.zig");
pub const ecs = @import("./ecs/ecs.zig");

pub const rl = @import("raylib");

pub const Distances = struct {
    const Self = @This();

    pub const DistanceNames = enum {
        left,
        right,
        top,
        bottom,
    };

    left: f32,
    right: f32,
    top: f32,
    bottom: f32,

    pub fn getSmallest(self: *Self) ?DistanceNames {
        const smallest = z.math.f128_to(f32, z.math.min(
            self.left,
            z.math.min(
                self.right,
                z.math.min(
                    self.top,
                    self.bottom,
                ).?,
            ).?,
        ).?).?;

        if (smallest == self.left) return .left;
        if (smallest == self.right) return .right;
        if (smallest == self.top) return .top;
        if (smallest == self.bottom) return .bottom;
        return null;
    }
};

fn moveBack(
    dists: Distances,
    e_transform: *ecs.cTransform,
    e_collider: *ecs.cCollider,
    other_transform: *ecs.cTransform,
    other_collider: *ecs.cCollider,
    mult: f32,
) void {
    const smallest = @constCast(&dists).getSmallest();

    switch (smallest.?) {
        .left => {
            e_transform.position.x -= (
            //
                e_transform.position.x +
                e_collider.rect.x +
                e_collider.rect.width -
                other_transform.position.x -
                other_collider.rect.x
            //
            ) * mult;
        },
        .right => {
            e_transform.position.x += (
            //
                other_transform.position.x +
                other_collider.rect.x +
                other_collider.rect.width -
                e_transform.position.x -
                e_collider.rect.x
            //
            ) * mult;
        },
        .top => {
            e_transform.position.y += (
            //
                other_transform.position.y +
                other_collider.rect.y +
                other_collider.rect.height -
                e_transform.position.y -
                e_collider.rect.y
            //
            ) * mult;
        },
        .bottom => {
            e_transform.position.y -= (
            //
                e_transform.position.y +
                e_collider.rect.y +
                e_collider.rect.height -
                other_transform.position.y -
                other_collider.rect.y
            //
            ) * mult;
        },
    }
}

pub fn update(alloc: *Allocator) !void {
    const entities = try ecs.getEntities("collider");
    defer alloc.free(entities);

    for (entities) |e| {
        const query_e_transform = e.get(ecs.cTransform, "transform");
        if (query_e_transform == null) continue;

        z.dprint("E: {s}", .{e.id});

        const e_transform = query_e_transform.?;

        const e_collider = e.get(ecs.cCollider, "collider").?;

        if (!e_collider.dynamic) continue;

        const e_rect = rl.Rectangle.init(
            e_collider.rect.x + e_transform.position.x,
            e_collider.rect.y + e_transform.position.y,
            e_collider.rect.width,
            e_collider.rect.height,
        );

        for (entities) |other| {
            const query_other_transform = other.get(ecs.cTransform, "transform");
            if (query_other_transform == null) continue;

            const other_transform = query_other_transform.?;

            const other_collider = other.get(ecs.cCollider, "collider").?;

            const other_rect = rl.Rectangle.init(
                other_collider.rect.x + other_transform.position.x,
                other_collider.rect.y + other_transform.position.y,
                other_collider.rect.width,
                other_collider.rect.height,
            );

            if (!e_rect.checkCollision(other_rect)) continue;

            // Collision Happening
            const e_distances = Distances{
                .left = (
                //
                    e_transform.position.x +
                    e_collider.rect.x +
                    e_collider.rect.width -
                    other_transform.position.x -
                    other_collider.rect.x +
                    1
                //
                ),
                .right = (
                //
                    other_transform.position.x +
                    other_collider.rect.x +
                    other_collider.rect.width -
                    e_transform.position.x -
                    e_collider.rect.x +
                    1
                //
                ),
                .top = (
                //
                    other_transform.position.y +
                    other_collider.rect.y +
                    other_collider.rect.height -
                    e_transform.position.y -
                    e_collider.rect.y +
                    1
                //
                ),
                .bottom = (
                //
                    e_transform.position.y +
                    e_collider.rect.y +
                    e_collider.rect.height -
                    other_transform.position.y -
                    other_collider.rect.y +
                    1
                //
                ),
            };

            if (!other_collider.dynamic) {
                moveBack(e_distances, e_transform, e_collider, other_transform, other_collider, 1);
                continue;
            }

            const other_distances = Distances{
                .left = (
                //
                    other_transform.position.x +
                    other_collider.rect.x +
                    other_collider.rect.width -
                    e_transform.position.x -
                    e_collider.rect.x +
                    1

                //
                ),
                .right = (
                //
                    e_transform.position.x +
                    e_collider.rect.x +
                    e_collider.rect.width -
                    other_transform.position.x -
                    other_collider.rect.x +
                    1
                //
                ),
                .top = (
                //
                    e_transform.position.y +
                    e_collider.rect.y +
                    e_collider.rect.height -
                    other_transform.position.y -
                    other_collider.rect.y +
                    1
                //
                ),
                .bottom = (
                //
                    other_transform.position.y +
                    other_collider.rect.y +
                    other_collider.rect.height -
                    e_transform.position.y -
                    e_collider.rect.y +
                    1
                //
                ),
            };

            const combined_weight = z.math.to_f128(e_collider.weight + other_collider.weight).?;
            const e_mult = z.math.f128_to(f32, z.math.div(
                e_collider.weight,
                combined_weight,
            ).?).?;
            const other_mult = z.math.f128_to(f32, z.math.div(
                other_collider.weight,
                combined_weight,
            ).?).?;

            moveBack(e_distances, e_transform, e_collider, other_transform, other_collider, other_mult);
            moveBack(other_distances, other_transform, other_collider, e_transform, e_collider, e_mult);
        }
    }
}
