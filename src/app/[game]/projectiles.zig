const Import = @import("../../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const uuid = @import("uuid");

const e = @import("../../engine/engine.m.zig");

const ENEMY_PROJECTILE_SPRITE: []const u8 = "";
const PLAYER_PROJECTILE_SPRITE: []const u8 = "projectile_player_light.png";

const sides = enum { player, enemy };

const LivingProjectilesType = std.StringHashMap(Projectile);
var living_projectiles: LivingProjectilesType = undefined;

const ProjectileErrors = error{CreationBeforeAwakeError};
var awake_flag = false;

pub const Projectile = struct {
    const Self = @This();

    id: []const u8,
    entity: *e.ecs.Entity,
    transform: e.ecs.cTransform,
    display: e.ecs.cDisplay,
    lifetime_end: f64,
    speed: f32,
    side: sides,
    direction: f32,

    pub fn init(side: sides, lifetime: f64, speed: f32, direction: f32, transform: e.ecs.cTransform) !Self {
        if (!awake_flag) {
            return ProjectileErrors.CreationBeforeAwakeError;
        }

        const uuid_len_36 = uuid.urn.serialize(uuid.v7.new());

        var id_arr = std.ArrayList(u8).init(e.ALLOCATOR);
        defer id_arr.deinit();

        for (uuid_len_36) |c| {
            try id_arr.append(c);
        }

        const id_slice = try id_arr.toOwnedSlice();
        
        const entity = try e.ecs.newEntity(id_slice);
        const display = e.ecs.cDisplay{
            .scaling = .pixelate,
            .tint = e.Color.white,
            .sprite = switch (side) {
                .enemy => ENEMY_PROJECTILE_SPRITE,
                .player => PLAYER_PROJECTILE_SPRITE,
            },
        };

        var self = Self{
            .id = id_slice,
            .lifetime_end = e.time.currentTime + lifetime,
            .speed = speed,
            .side = side,
            .entity = entity,
            .display = display,
            .transform = transform,
            .direction = direction,
        };

        self.transform.rotation.z = self.direction - 90;

        return self;
    }

    pub fn move(self: *Self) void {
        const move_vector = e.Vec2(1, 0)
            .rotate(std.math.degreesToRadians(self.direction))
            .normalize();

        self.transform.position.x += move_vector.x * self.speed * @as(f32, @floatCast(e.time.deltaTime));
        self.transform.position.y += move_vector.y * self.speed * @as(f32, @floatCast(e.time.deltaTime));
    }

    pub fn deinit(self: *Self) void {
        e.ecs.removeEntity(self.entity.id);
        e.ALLOCATOR.free(self.id);
    }
};

pub fn awake() !void {
    living_projectiles = LivingProjectilesType.init(e.ALLOCATOR);
    awake_flag = true;
}

pub fn update() !void {
    var it = living_projectiles.iterator();
    while (it.next()) |entry| {
        var projectile = entry.value_ptr;
        const key = entry.key_ptr.*;

        if (e.time.currentTime > projectile.lifetime_end) {
            std.log.info("\tRemoving projectile", .{});
            projectile.deinit();
            _ = living_projectiles.remove(key);
            e.ALLOCATOR.free(key);
            continue;
        }

        std.log.info("\tMoving projectile", .{});
        projectile.move();
        std.log.info("\tFinished projectile", .{});
    }
}

pub fn deinit() !void {
    var it = living_projectiles.iterator();
    while (it.next()) |entry| {
        var projectile = entry.value_ptr;
        const key = entry.key_ptr.*;

        projectile.deinit();
        e.ALLOCATOR.free(key);
    }

    living_projectiles.deinit();
}

pub fn shoot(projectile: Projectile) !void {
    const key = try e.ALLOCATOR.dupe(u8, projectile.id);

    try living_projectiles.put(key, projectile);
    var self = living_projectiles.getPtr(key).?;

    try self.entity.attach(&self.transform, "transform");
    try self.entity.attach(&self.display, "display");
}

pub const new = Projectile.init;
