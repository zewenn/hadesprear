const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
var Player: *conf.Entity = undefined;

const projectiles = @import("projectiles.zig");
const balancing = @import("balancing.zig");

const prefabs = @import("items.zig").prefabs;
const usePrefab = @import("items.zig").usePrefab;

const weapons = @import("weapons.zig");

const TMType = e.time.TimeoutHandler(struct {
    round_count: usize = 0,
    round_index: usize = 0,
    damage: f32 = 0,
    side: conf.ProjectileSide = .player,
    projectile_list: [16]?f32,
    entity: *e.Entity,
    energised_strength: usize,
    blood: f32,
    scale: e.Vector2,
});
var tm: TMType = undefined;

fn countBlessing(arr: [16]?conf.Blessings, blessing: conf.Blessings) usize {
    var count: usize = 0;

    for (arr) |item| {
        if (item == null) continue;
        if (item.? != blessing) continue;
        count += 1;
    }

    return count;
}

pub fn summon(spell: conf.Item, entity: *e.Entity, side: conf.ProjectileSide, bonus_damage: f32) !void {
    if (spell.T != .spell) return;

    // curse
    const projectile_rounds = countBlessing(spell.spell_blessings, .curse);

    // fire
    const damage = balancing.powerScaleCurve(10 * countBlessing(spell.spell_blessings, .fire)) * @max(1, bonus_damage);

    // zephyr
    const summon_speed = 1 / e.loadf32(@max(1, countBlessing(spell.spell_blessings, .zephyr)));

    // fracture
    const projectile_count: f32 = @min(15, 1 + e.loadf32(countBlessing(spell.spell_blessings, .fracture)));
    const projectile_rotation: f32 = 360 / projectile_count;
    var projectile_arr: [16]?f32 = conf.createProjectileArray(0, [_]?f32{});

    for (0..projectile_arr.len - 1) |index| {
        projectile_arr[index] = projectile_rotation * e.loadf32(index);
    }

    // Kin
    const energised_strength = countBlessing(spell.spell_blessings, .kin);
    const blood = countBlessing(spell.spell_blessings, .blood);

    const steel = e.loadf32(countBlessing(spell.spell_blessings, .steel));
    const width: f32 = 64 * (steel * 14 / 12);
    const height = 64 * (steel * 13 / 12);

    for (0..projectile_rounds) |i| {
        try tm.setTimeout(
            (struct {
                pub fn callback(args: TMType.ARGSTYPE) !void {
                    try projectiles.summonMultiple(
                        .light,
                        args.entity,
                        usePrefab(.{
                            .level = 10,
                            .name = "",
                            .id = 0,
                            .attack_speed = 0,
                            .weapon_light = .{
                                .projectile_array = args.projectile_list,
                                .projectile_on_hit_effect = .energised,
                                .projectile_on_hit_strength_multiplier = e.loadf32(args.energised_strength * 2),
                                .projectile_scale = args.scale,
                            },
                        }),
                        // 0,
                        args.damage,
                        e.loadf32(args.round_index) / e.loadf32(args.round_count) * 360,
                        args.side,
                    );

                    if (args.blood > 0)
                        weapons.applyEffect(args.entity, .healing, balancing.powerScaleCurve(2 * args.blood));
                }
            }).callback,
            TMType.ARGSTYPE{
                .round_count = projectile_rounds,
                .round_index = i,
                .damage = damage,
                .side = side,
                .projectile_list = projectile_arr,
                .entity = entity,
                .energised_strength = energised_strength,
                .blood = e.loadf32(blood),
                .scale = e.Vec2(width, height),
            },
            @floatCast(e.loadf32(i + 1) * summon_speed),
        );
    }
}

pub fn awake() !void {
    tm = TMType.init(e.ALLOCATOR);
}

pub fn init() !void {
    Player = e.entities.get("Player").?;
}

pub fn update() !void {
    try tm.update();
}

pub fn deinit() !void {
    tm.deinit();
}
