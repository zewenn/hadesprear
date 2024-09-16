const entities_module = @import("./engine/entities/entities.m.zig");
const rl = @import("raylib");

pub const entities = entities_module.make(struct {
    id: []const u8,
    tags: []const u8,
    transform: entities_module.Transform,
    display: entities_module.Display,
    collider: ?entities_module.Collider,
    cached_display: ?entities_module.CachedDisplay = null,

    projectile_data: ?ProjectileData = null,
});

pub const ProjectileData = struct {
    lifetime_end: f64,
    side: enum {
        player,
        enemy,
    },
    speed: f32,
    direction: f32,
    scale: rl.Vector2,
};
