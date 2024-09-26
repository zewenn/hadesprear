const entities_module = @import("./engine/entities/entities.m.zig");
const rl = @import("raylib");

pub const entities = entities_module.make(struct {
    const Self = @This();

    id: []const u8,
    tags: []const u8,
    transform: entities_module.Transform,
    display: entities_module.Display,
    collider: ?entities_module.Collider = null,
    cached_display: ?entities_module.CachedDisplay = null,
    shooting_stats: ?ShootingStats = null,

    facing: enum { left, right } = .left,
    projectile_data: ?ProjectileData = null,

    entity_stats: ?EntityStats = null,

    pub fn freeRaylibStructs(self: *Self) void {
        if (self.cached_display) |cached| {
            if (cached.img) |image| {
                rl.unloadImage(image);
            }
            if (cached.texture) |texture| {
                rl.unloadTexture(texture);
            }
        }
    }
});

pub const ProjectileData = struct {
    lifetime_end: f64,
    side: enum {
        player,
        enemy,
    },
    weight: enum {
        light,
        heavy,
    },
    speed: f32,
    direction: f32,
    scale: rl.Vector2,
};

pub const ShootingStats = struct {
    damage: f32 = 20,
    timeout: f64 = 0.1,
    timeout_end: f64 = 0,
};

pub const EntityStats = struct {
    movement_speed: f32 = 335,

    health: f32 = 100,
    damage: f32 = 20,

    crit_rate: f32 = 0,
    crit_damage_multiplier: f32 = 2,

    is_enemy: bool = false,
};
