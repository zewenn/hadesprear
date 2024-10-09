const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const z = @import("./z/z.m.zig");
pub const entities = @import("./engine.m.zig").entities;

pub const rl = @import("raylib");
const Rect = @import("engine.m.zig").Rect;

pub const box_system = struct {
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
        e_transform: *entities.Transform,
        e_collider: *entities.Collider,
        other_transform: *entities.Transform,
        other_collider: *entities.Collider,
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

    /// If both entities have a collider it returns the `.collidionChech()`
    /// result, if not it returns false.
    pub fn collides(entity1: *entities.Entity, entity2: *entities.Entity) bool {
        if (entity1.collider) |e1_collider| {
            if (entity2.collider) |e2_collider| {
                const e1_rect = Rect(
                    entity1.transform.position.x + e1_collider.rect.x,
                    entity1.transform.position.y + e1_collider.rect.y,
                    e1_collider.rect.width,
                    e1_collider.rect.height,
                );
                const e2_rect = Rect(
                    entity2.transform.position.x + e2_collider.rect.x,
                    entity2.transform.position.y + e2_collider.rect.y,
                    e2_collider.rect.width,
                    e2_collider.rect.height,
                );

                return e1_rect.checkCollision(e2_rect);
            }
        }

        return false;
    }

    pub fn update(alloc: *Allocator) !void {
        const entities_slice = try entities.all();
        defer alloc.free(entities_slice);

        dynamic: for (entities_slice) |e| {
            if (e.collider == null) continue;
            if (e.collider.?.trigger) continue;

            const e_transform = &e.transform;

            const e_collider = &e.collider.?;

            if (!e_collider.dynamic) continue :dynamic;

            const e_rect = rl.Rectangle.init(
                e_collider.rect.x + e_transform.position.x,
                e_collider.rect.y + e_transform.position.y,
                e_collider.rect.width,
                e_collider.rect.height,
            );

            other: for (entities_slice) |other| {
                if (other.collider == null) continue;
                if (other.collider.?.trigger) continue;

                if (std.mem.eql(u8, e.id, other.id)) continue :other;

                const other_transform = &other.transform;

                const other_collider = &other.collider.?;

                const other_rect = rl.Rectangle.init(
                    other_collider.rect.x + other_transform.position.x,
                    other_collider.rect.y + other_transform.position.y,
                    other_collider.rect.width,
                    other_collider.rect.height,
                );

                if (!e_rect.checkCollision(other_rect)) continue :other;

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
                    continue :other;
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
};

pub const RectangleVertices = struct {
    const Self = @This();

    transform: *entities.Transform,

    P0: rl.Vector2,
    P1: rl.Vector2,
    P2: rl.Vector2,
    P3: rl.Vector2,

    x_min: f32 = 0,
    x_max: f32 = 0,

    y_min: f32 = 0,
    y_max: f32 = 0,

    pub fn init(transform: *entities.Transform, collider: *entities.Collider) Self {
        const PC = rl.Vector2.init(
            transform.position.x + transform.scale.x / 2 - collider.rect.width / 2,
            transform.position.y + transform.scale.y / 2 - collider.rect.height / 2,
        );
        const P0 = PC.add(
            rl.Vector2
                .init(-collider.rect.width / 2, -collider.rect.height / 2)
                .rotate(std.math.degreesToRadians(transform.rotation.z)),
        );
        const P1 = PC.add(
            rl.Vector2
                .init(collider.rect.width / 2, -collider.rect.height / 2)
                .rotate(std.math.degreesToRadians(transform.rotation.z)),
        );
        const P2 = PC.add(
            rl.Vector2
                .init(-collider.rect.width / 2, collider.rect.height / 2)
                .rotate(std.math.degreesToRadians(transform.rotation.z)),
        );
        const P3 = PC.add(
            rl.Vector2
                .init(collider.rect.width / 2, collider.rect.height / 2)
                .rotate(std.math.degreesToRadians(transform.rotation.z)),
        );

        const x_min: f32 = @min(@min(P0.x, P1.x), @min(P2.x, P3.x));
        const x_max: f32 = @max(@max(P0.x, P1.x), @max(P2.x, P3.x));

        const y_min: f32 = @min(@min(P0.y, P1.y), @min(P2.y, P3.y));
        const y_max: f32 = @max(@max(P0.y, P1.y), @max(P2.y, P3.y));

        return Self{
            .transform = transform,
            .P0 = P0,
            .P1 = P1,
            .P2 = P2,
            .P3 = P3,
            .x_min = x_min,
            .x_max = x_max,
            .y_min = y_min,
            .y_max = y_max,
        };
    }

    pub fn overlaps(self: *Self, other: Self) bool {
        if ((self.x_max > other.x_min and self.x_min < other.x_max) and
            (self.y_max > other.y_min and self.y_min < other.y_max))
            return true;
        return false;
    }

    pub fn pushback(a: *Self, b: Self, weight: f32) void {
        const overlap_x = @min(a.x_max - b.x_min, b.x_max - a.x_min);
        const overlap_y = @min(a.y_max - b.y_min, b.y_max - a.y_min);

        switch (overlap_x < overlap_y) {
            true => PushBack_X: {
                if (a.x_max > b.x_min and a.x_max < b.x_max) {
                    a.transform.position.x -= overlap_x * weight;
                    break :PushBack_X;
                }

                a.transform.position.x += overlap_x * weight;
                break :PushBack_X;
            },
            false => PushBack_Y: {
                if (a.y_max > b.y_min and a.y_max < b.y_max) {
                    a.transform.position.y -= overlap_y * weight;
                    break :PushBack_Y;
                }

                a.transform.position.y += overlap_y * weight;
                break :PushBack_Y;
            },
        }
    }
};

/// If both entities have a collider it returns the `.collidionChech()`
/// result, if not it returns false.
pub fn collides(entity1: *entities.Entity, entity2: *entities.Entity) bool {
    if (entity1.collider == null) return false;
    if (entity2.collider == null) return false;

    var a = RectangleVertices.init(
        &entity1.transform,
        &(entity1.collider.?),
    );
    const b = RectangleVertices.init(
        &entity2.transform,
        &(entity2.collider.?),
    );

    return a.overlaps(b);
}

pub fn update(alloc: *Allocator) !void {
    const entities_slice = try entities.all();
    defer alloc.free(entities_slice);

    dynamic: for (entities_slice) |e| {
        if (e.collider == null) continue;
        if (e.collider.?.trigger) continue;

        const e_transform = &e.transform;

        const e_collider = &e.collider.?;

        if (!e_collider.dynamic) continue :dynamic;

        var entity_vertices = RectangleVertices.init(
            e_transform,
            e_collider,
        );

        other: for (entities_slice) |other| {
            if (other.collider == null) continue;
            if (other.collider.?.trigger) continue;

            if (std.mem.eql(u8, e.id, other.id)) continue :other;

            const other_transform = &other.transform;

            const other_collider = &other.collider.?;

            var other_vertices = RectangleVertices.init(
                other_transform,
                other_collider,
            );

            if (!entity_vertices.overlaps(other_vertices)) continue :other;

            // Collision Happening

            if (!other_collider.dynamic) {
                entity_vertices.pushback(other_vertices, 1);
                continue :other;
            }

            const combined_weight = z.math.to_f128(e_collider.weight + other_collider.weight).?;
            const e_mult = z.math.f128_to(f32, z.math.div(
                e_collider.weight,
                combined_weight,
            ).?).?;
            const other_mult = z.math.f128_to(f32, z.math.div(
                other_collider.weight,
                combined_weight,
            ).?).?;

            // moveBack(e_distances, e_transform, e_collider, other_transform, other_collider, other_mult);
            // moveBack(other_distances, other_transform, other_collider, e_transform, e_collider, e_mult);

            entity_vertices.pushback(other_vertices, other_mult);
            other_vertices.pushback(entity_vertices, e_mult);
        }
    }
}
