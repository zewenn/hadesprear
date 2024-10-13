const std = @import("std");

const entities_module = @import("./engine/entities/entities.m.zig");
const rl = @import("raylib");
const uuid = @import("uuid");
const z = @import("./engine/z/z.m.zig");

pub const Entity = struct {
    const Self = @This();

    id: []const u8,
    tags: []const u8,
    transform: entities_module.Transform,
    display: entities_module.Display,
    collider: ?entities_module.Collider = null,
    cached_display: ?entities_module.CachedDisplay = null,
    cached_collider: ?entities_module.RectangleVertices = null,

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
};

pub const entities = entities_module.make(Entity);

pub const ProjectileSide = enum {
    player,
    enemy,
};

pub const ProjectileData = struct {
    lifetime_end: f64,
    side: ProjectileSide,
    weight: enum {
        light,
        heavy,
    },
    sprite: []const u8,
    speed: f32,
    direction: f32,
    scale: rl.Vector2,
    damage: f32 = 10,
    health: f32 = 0.01,
    bleed_per_second: f32 = 100,

    owner: ?*Entity = null,
    on_hit_effect: on_hit_effects = .none,
    on_hit_effect_strength: f32 = 0,
};

pub const ShootingStats = struct {
    damage: f32 = 20,
    timeout: f64 = 0.1,
    timeout_end: f64 = 0,
    projectile_lifetime: f64 = 2,
};

pub const EntityStats = struct {
    movement_speed: f32 = 335,
    max_movement_speed: f32 = 1280,

    health: f32 = 100,
    max_health: f32 = 100,
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

pub const ItemStats = enum {
    damage,
    health,
    crit_rate,
    crit_damage,
    movement_speed,
    tenacity,
};

pub const on_hit_effects = enum {
    none,
    energized,
    vamp,
    stengthen,
};

pub const WeaponAttackTypeStats = struct {
    projectile_scale: rl.Vector2 = .{
        .x = 64,
        .y = 64,
    },
    projectile_speed: f32 = 650,
    projectile_array: [16]?f32 = [1]?f32{0} ++ ([_]?f32{null} ** 15),
    projectile_lifetime: f32 = 0.5,

    /// Any projectile_health above 1 will make the
    /// projectile into a piercing projectile
    projectile_health: f32 = 0.01,
    projectile_bps: f32 = 100,

    projectile_on_hit_effect: on_hit_effects = .none,
    projectile_on_hit_strength_multiplier: f32 = 1,

    multiplier: f32 = 1,
    sprite: []const u8 = "sprites/projectiles/player/generic/light.png",
    attack_speed_modifier: f32 = 1,
};

pub fn mergeWeaponAttackStats(base: WeaponAttackTypeStats, new: WeaponAttackTypeStats) WeaponAttackTypeStats {
    const default = WeaponAttackTypeStats{};
    var res = base;

    const fields: []const std.builtin.Type.StructField = std.meta.fields(WeaponAttackTypeStats);

    inline for (fields) |field| {
        if (!z.eql(@field(base, field.name), @field(new, field.name)) and
            !z.eql(@field(default, field.name), @field(new, field.name)))
        {
            const fieldptr = &(@field(res, field.name));
            fieldptr.* = @field(new, field.name);
        }
    }

    return res;
}

pub fn WeaponAttackLightStats(stats: WeaponAttackTypeStats) WeaponAttackTypeStats {
    return mergeWeaponAttackStats(
        .{
            .projectile_lifetime = 0.45,
        },
        stats,
    );
}
pub fn WeaponAttackHeavyStats(stats: WeaponAttackTypeStats) WeaponAttackTypeStats {
    return mergeWeaponAttackStats(
        .{
            .projectile_lifetime = 0.65,
            .multiplier = 2,
            .attack_speed_modifier = 2,
        },
        stats,
    );
}
pub fn WeaponAttackDashStats(stats: WeaponAttackTypeStats) WeaponAttackTypeStats {
    return mergeWeaponAttackStats(
        .{
            .projectile_lifetime = 0.85,
            .multiplier = 1.25,
            .attack_speed_modifier = 1.5,
            .projectile_scale = .{
                .x = 128,
                .y = 64,
            },
            .projectile_speed = 860,
        },
        stats,
    );
}

pub fn createProjectileArray(comptime size: usize, comptime degree_list: [size]?f32) [16]?f32 {
    return degree_list ++ ([_]?f32{null} ** (16 - size));
}

pub fn newItem(item: Item) Item {
    var res = item;
    res.weapon_light = WeaponAttackLightStats(res.weapon_light);
    res.weapon_heavy = WeaponAttackHeavyStats(res.weapon_heavy);
    res.weapon_dash = WeaponAttackDashStats(res.weapon_dash);

    return res;
}

pub const AttackTypes = enum {
    light,
    heavy,
    dash,
};

pub const Item = struct {
    /// If id is 0 the Item is a prefab and should not be modified without cloning
    id: u128 = 0,

    T: ItemTypes = .weapon,
    rarity: enum {
        common,
        epic,
        legendary,
    } = .common,

    // This is obviously not applicable to any non-weapons
    weapon_type: enum {
        sword,
        polearm,
        daggers,
        claymore,
        special,
    } = .sword,

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

    /// Smaller better
    attack_speed: f32 = 0.25,

    weapon_light: WeaponAttackTypeStats = WeaponAttackLightStats(.{}),
    weapon_heavy: WeaponAttackTypeStats = WeaponAttackHeavyStats(.{}),
    weapon_dash: WeaponAttackTypeStats = WeaponAttackDashStats(.{}),

    weapon_projectile_scale_light: rl.Vector2 = .{
        .x = 64,
        .y = 64,
    },

    name: [*:0]const u8,

    icon: []const u8 = "sprites/missingno.png",
    weapon_sprite_left: []const u8 = "sprites/missingno.png",
    weapon_sprite_right: []const u8 = "sprites/missingno.png",
};
