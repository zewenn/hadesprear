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
    dash_modifiers: ?DashModifiers = null,

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
    damage: f32 = 10,
};

pub const ShootingStats = struct {
    damage: f32 = 20,
    timeout: f64 = 0.1,
    timeout_end: f64 = 0,
    projectile_lifetime: f64 = 2,
};

pub const EntityStats = struct {
    movement_speed: f32 = 335,

    health: f32 = 100,
    damage: f32 = 20,

    crit_rate: f32 = 0,
    crit_damage_multiplier: f32 = 2,

    is_enemy: bool = false,
    range: f32 = 500,

    can_move: bool = false,
    is_dashing: bool = false,
    is_invalnureable: bool = false,
};

pub const DashModifiers = struct {
    movement_speed_multiplier: f32 = 3,
    dash_time: f64 = 1,
    towards: rl.Vector2 = rl.Vector2.init(1, 0),
    charges: usize = 2,
    charges_available: usize = 2,

    dash_end: f64 = 0,
};

pub const ItemTypes = enum {
    weapon,
    ring,
    amethyst,
    wayfinder,
};

pub const Item = struct {
    T: ItemTypes = .weapon,
    rarity: enum {
        common,
        epic,
        legendary,
    } = .common,
    equipped: bool = false,
    unequippable: bool = true,

    level: usize = 0,
    cost_per_level: usize = 16,
    base_upgrade_cost: usize = 16,

    health: f32 = 0,
    tenacity: f32 = 0,

    damage: f32 = 0,
    crit_rate: f32 = 0,
    crit_damage_multiplier: f32 = 0,

    movement_speed: f32 = 0,
    dash_charges: f32 = 0,

    weapon_projectile_scale: rl.Vector2,

    name: [*:0]const u8,

    icon: []const u8,
    weapon_sprite_left: []const u8,
    weapon_sprite_right: []const u8,
};
