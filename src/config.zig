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

    projectile_data: ?ProjectileData = null,

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
    speed: f32,
    direction: f32,
    scale: rl.Vector2,
};
