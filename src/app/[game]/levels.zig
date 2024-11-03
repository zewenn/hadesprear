const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const enemies = @import("enemies.zig");

var loaded: ?conf.Level = null;
var round: usize = 0xff15;
var actual_round: usize = 0;

const TMType = e.time.TimeoutHandler(struct {});
var tm: TMType = undefined;

pub const TestLevel = conf.Level{
    .rounds = @constCast(&[_][]conf.EnemySpawner{
        @constCast(&[_]conf.EnemySpawner{
            conf.EnemySpawner{
                .enemy_archetype = .brute,
                .enemy_subtype = .normal,
                .spawn_at = e.Vec2(64, 128),
            },
            conf.EnemySpawner{
                .enemy_archetype = .angler,
                .enemy_subtype = .normal,
                .spawn_at = e.Vec2(-600, -156),
            },
        }),
        @constCast(&[_]conf.EnemySpawner{
            conf.EnemySpawner{
                .enemy_archetype = .brute,
                .enemy_subtype = .normal,
                .spawn_at = e.Vec2(64, 128),
            },
            conf.EnemySpawner{
                .enemy_archetype = .angler,
                .enemy_subtype = .normal,
                .spawn_at = e.Vec2(-600, -156),
            },
            conf.EnemySpawner{
                .enemy_archetype = .angler,
                .enemy_subtype = .normal,
                .spawn_at = e.Vec2(-300, -186),
            },
            conf.EnemySpawner{
                .enemy_archetype = .angler,
                .enemy_subtype = .normal,
                .spawn_at = e.Vec2(-100, -200),
            },
        }),
    }),
    .reward_tier = .common,
    .backgrounds = @constCast(&[_]e.Entity{
        .{
            .id = "background",
            .tags = "wallpaper",
            .transform = .{
                .position = e.Vec2(0, 0),
                .rotation = e.Vec3(0, 0, 0),
                .scale = e.Vec2(2560, 1280),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/32x32.png",
                .layer = .background,
                .background_tile_size = e.Vec2(128, 128),
            },
        },
    }),
    .walls = @constCast(&[_]e.Entity{
        e.Entity{
            .id = ".",
            .tags = ".",
            .transform = .{
                .position = e.Vec2(0, 640 - 96),
                .rotation = e.Vec3(0, 0, 0),
                .scale = e.Vec2(2560, 48 * 4),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/w16x48.png",
                .layer = .foreground,
                .background_tile_size = e.Vec2(64, 48 * 4),
            },
            .collider = e.components.Collider{
                .dynamic = false,
                .rect = e.Rect(0, -32, 2560, 32),
                .weight = 10,
            },
        },
        e.Entity{
            .id = ".",
            .tags = ".",
            .transform = .{
                .position = e.Vec2(0, -640 - 96),
                .rotation = e.Vec3(0, 0, 0),
                .scale = e.Vec2(2560, 48 * 4),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/w16x48.png",
                .layer = .foreground,
                .background_tile_size = e.Vec2(64, 48 * 4),
            },
            .collider = e.components.Collider{
                .dynamic = false,
                .rect = e.Rect(0, -32, 2560, 32),
                .weight = 10,
            },
        },
        e.Entity{
            .id = ".",
            .tags = ".",
            .transform = .{
                .position = e.Vec2(-1280 + 32, -128),
                .rotation = e.Vec3(0, 0, 0),
                .scale = e.Vec2(64, 1280),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/wt16x16.png",
                .layer = .walls,
                .background_tile_size = e.Vec2(64, 64),
            },
            .collider = e.components.Collider{
                .dynamic = false,
                .rect = e.Rect(0, 128, 64, 1280),
                .weight = 10,
            },
        },
        e.Entity{
            .id = ".",
            .tags = ".",
            .transform = .{
                .position = e.Vec2(1280 - 32, -128),
                .rotation = e.Vec3(0, 0, 0),
                .scale = e.Vec2(64, 1280),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/wt16x16.png",
                .layer = .walls,
                .background_tile_size = e.Vec2(64, 64),
            },
            .collider = e.components.Collider{
                .dynamic = false,
                .rect = e.Rect(0, 128, 64, 1280),
                .weight = 10,
            },
        },
    }),
};

pub fn awake() !void {
    tm = TMType.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {
    try tm.update();
    if (round == 0xff15) return;
    if (loaded == null) return;

    const enemies_in_scene = enemies.manager.len();
    if (enemies_in_scene == 0) try startRound();
}

pub fn deinit() !void {
    unload();
    tm.deinit();
}

pub fn load(level: conf.Level) !void {
    if (loaded) |_| unload();
    loaded = level;
    round = 0;

    const loadedptr = &(loaded.?);

    for (loadedptr.backgrounds) |*entity| {
        entity.id = try e.UUIDV7();
        entity.tags = "background";
        entity.display.layer = .background;

        try e.entities.add(entity);
    }

    for (loadedptr.walls) |*entity| {
        entity.id = try e.UUIDV7();
        entity.tags = "wall";
        // entity.display.layer = .walls;

        if (entity.collider == null) @panic("Walls must have colliders");

        try e.entities.add(entity);
    }
}

pub fn unload() void {
    if (loaded == null) return;
    round = 0xff15;

    const loadedptr = &(loaded.?);

    for (loadedptr.backgrounds) |*entity| {
        e.entities.remove(entity.id);
        e.ALLOCATOR.free(entity.id);
    }

    for (loadedptr.walls) |*entity| {
        e.entities.remove(entity.id);
        e.ALLOCATOR.free(entity.id);
    }

    loaded = null;
}

pub fn startRound() !void {
    if (loaded == null) return;
    if (round == 0xff15) return;

    for (loaded.?.rounds[round]) |spawndata| {
        try enemies.spawnWithIndicator(
            spawndata.enemy_archetype,
            spawndata.enemy_subtype,
            spawndata.spawn_at,
            0.75,
        );
    }
    if (round != 0xff15)
        actual_round = round;
    round = 0xff15;

    try tm.setTimeout(
        (struct {
            pub fn callback(_: TMType.ARGSTYPE) !void {
                if (actual_round < loaded.?.rounds.len - 1) {
                    actual_round += 1;
                    round = actual_round;
                }
            }
        }).callback,
        .{},
        1,
    );
}
