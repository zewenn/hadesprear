const std = @import("std");
const Allocator = std.mem.Allocator;

const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const enemies = @import("enemies.zig");

var loaded: ?conf.LoadedLevel = null;
var round: usize = 0xff15;
var actual_round: usize = 0;

var Player: *e.Entity = undefined;

const TMType = e.time.TimeoutHandler(struct {});
var tm: TMType = undefined;

const manager = e.zlib.HeapManager(e.Entity, (struct {
    pub fn callback(alloc: Allocator, item: *e.Entity) !void {
        e.entities.remove(item.id);
        alloc.free(item.id);
    }
}).callback);

pub fn levelEntity(entity: e.Entity, tags: []const u8) !*e.Entity {
    const resptr = try manager.appendReturn(entity);
    resptr.tags = tags;
    resptr.id = try e.UUIDV7();

    return resptr;
}

pub fn makeLoadedLevel(from: conf.Level) !conf.LoadedLevel {
    var backgrounds = try e.ALLOCATOR.alloc(*e.Entity, from.backgrounds.len);
    for (from.backgrounds, 0..) |bg, index| {
        backgrounds[index] = try levelEntity(bg, "background");
    }

    var walls = try e.ALLOCATOR.alloc(*e.Entity, from.walls.len);
    for (from.walls, 0..) |wall, index| {
        walls[index] = try levelEntity(wall, "wall");
    }

    return conf.LoadedLevel{
        .rounds = from.rounds,
        .reward_tier = from.reward_tier,
        .backgrounds = backgrounds,
        .walls = walls,
        .player_pos = from.player_pos,
    };
}

pub var TestLevel = conf.Level{
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
                .scale = e.Vec2(2560, 192),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/w16x48.png",
                .layer = .foreground,
                .background_tile_size = e.Vec2(64, 192),
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
                .scale = e.Vec2(2560, 192),
            },
            .display = .{
                .scaling = .pixelate,
                .sprite = "sprites/backgrounds/w16x48.png",
                .layer = .foreground,
                .background_tile_size = e.Vec2(64, 192),
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
    .player_pos = e.Vec2(0, 0),
};

pub fn awake() !void {
    tm = TMType.init(e.ALLOCATOR);
    manager.init(e.ALLOCATOR);

    try editor_suit.awake();
}

pub fn init() !void {
    Player = e.entities.get("Player") orelse @panic("Player does not exist or were not found!");
}

pub fn update() !void {
    try editor_suit.update();
    try tm.update();
    if (round == 0xff15) return;
    if (loaded == null) return;

    const enemies_in_scene = enemies.manager.len();
    if (enemies_in_scene == 0) try startRound();
}

pub fn deinit() !void {
    unload();
    tm.deinit();

    const items = manager.items() catch {
        std.log.err("Failed to get items from the manager", .{});
        return;
    };
    defer manager.alloc.free(items);

    for (items) |item| {
        manager.removeFreeId(item);
    }
    manager.deinit();
}

pub fn load(level: conf.Level) !void {
    if (loaded) |_| unload();
    loaded = try makeLoadedLevel(level);
    round = 0;

    std.log.debug("player_pos: {any}", .{level.player_pos});

    Player.transform.position = level.player_pos.multiply(e.Vec2(64, 64));

    const loadedptr = &(loaded.?);

    for (loadedptr.backgrounds) |entity| {
        try e.entities.add(entity);
    }

    for (loadedptr.walls) |entity| {
        if (entity.collider == null) @panic("Walls must have colliders");

        try e.entities.add(entity);
    }
}

pub fn unload() void {
    if (loaded == null) return;
    round = 0xff15;

    const loadedptr = &(loaded.?);

    for (loadedptr.backgrounds) |entity| {
        manager.removeFreeId(entity);
    }
    e.ALLOCATOR.free(loadedptr.backgrounds);

    for (loadedptr.walls) |entity| {
        manager.removeFreeId(entity);
    }
    e.ALLOCATOR.free(loadedptr.walls);

    loaded = null;
}

pub fn startRound() !void {
    if (loaded == null) return;
    if (round == 0xff15) return;

    if (loaded.?.rounds.len == 0) return;

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
                const loaded_level = loaded orelse return;
                if (loaded_level.rounds.len == 0) return;

                if (actual_round < loaded_level.rounds.len - 1) {
                    actual_round += 1;
                    round = actual_round;
                }
            }
        }).callback,
        .{},
        1,
    );
}

pub fn sortRectsByY(_: void, lsh: e.Rectangle, rsh: e.Rectangle) bool {
    return lsh.y < rsh.y;
}

pub fn loadFromMatrix(matrix: [200][200]u8) !void {
    // const EMPTY_ID = 0;
    const WALL_ID = 1;

    var walls_horizontal = std.ArrayList(e.Rectangle).init(e.ALLOCATOR);
    defer walls_horizontal.deinit();

    var walls_vertical = std.ArrayList(e.Rectangle).init(e.ALLOCATOR);
    defer walls_vertical.deinit();

    var backgrounds_arr = std.ArrayList(e.Rectangle).init(e.ALLOCATOR);
    defer backgrounds_arr.deinit();

    const player_pos = e.Vec2(5, 5);
    const BACKGROUND_ID = 2;
    const BACKGROUND_2_ID = 3;

    for (matrix, 0..) |row, ri| {
        var current_width: f32 = 0;

        for (row, 0..) |col, ci| {
            if (col != WALL_ID) {
                if (current_width >= 2) {
                    walls_horizontal.append(
                        e.Rect(
                            e.loadf32(ci) - current_width,
                            ri,
                            current_width,
                            1,
                        ),
                    ) catch {
                        std.log.info("Failed to append!", .{});
                    };
                }

                current_width = 0;
                continue;
            }

            if (col == WALL_ID) current_width += 1;
        }
    }

    var current_height: f32 = 0;
    for (0..matrix[0].len) |ci| {
        for (matrix, 0..) |row, ri| {
            const col = row[ci];

            if (col != WALL_ID) {
                if (current_height >= 2) {
                    walls_vertical.append(
                        e.Rect(
                            ci,
                            e.loadf32(ri) - current_height,
                            1,
                            current_height,
                        ),
                    ) catch {
                        std.log.info("Failed to append!", .{});
                    };
                }

                current_height = 0;
                continue;
            }

            if (col == WALL_ID) current_height += 1;
        }
    }

    var current_width: f32 = 0;
    current_height = 1;

    for (matrix, 0..) |row, ri| {
        for (row, 0..) |col, ci| {
            if (col != BACKGROUND_ID) {
                if (current_width >= 2) {
                    backgrounds_arr.append(
                        e.Rect(
                            e.loadf32(ci) - current_width,
                            e.loadf32(ri) - current_height,
                            current_width,
                            current_height,
                        ),
                    ) catch {
                        std.log.info("Failed to append!", .{});
                    };
                }

                current_width = 0;
                continue;
            }
            current_width += 1;
        }
    }

    current_width = 0;
    current_height = 1;

    for (matrix, 0..) |row, ri| {
        for (row, 0..) |col, ci| {
            if (col != BACKGROUND_2_ID) {
                if (current_width >= 2) {
                    backgrounds_arr.append(
                        e.Rect(
                            e.loadf32(ci) - current_width,
                            e.loadf32(ri) - current_height,
                            current_width,
                            current_height,
                        ),
                    ) catch {
                        std.log.info("Failed to append!", .{});
                    };
                }

                current_width = 0;
                continue;
            }
            current_width += 1;
        }
    }

    const bgclone = try e.zlib.arrays.cloneToOwnedSlice(e.Rectangle, backgrounds_arr);
    defer e.ALLOCATOR.free(bgclone);

    std.sort.insertion(
        e.Rectangle,
        bgclone,
        {},
        sortRectsByY,
    );

    for (bgclone) |*rect| {
        const bgclone2 = try e.zlib.arrays.cloneToOwnedSlice(e.Rectangle, backgrounds_arr);
        defer e.ALLOCATOR.free(bgclone2);

        std.sort.insertion(
            e.Rectangle,
            bgclone2,
            {},
            sortRectsByY,
        );

        for (bgclone2) |rect2| {
            if (rect.x != rect2.x) continue;
            if (rect.width != rect2.width) continue;
            if (rect.y + rect.height != rect2.y) continue;
            if (std.meta.eql(rect.*, rect2)) continue;

            var delete_index: usize = 0;

            for (backgrounds_arr.items, 0..) |*item, index| {
                if (std.meta.eql(item.*, rect.*)) {
                    item.x = rect.x;
                    item.y = rect.y;
                    item.height += rect2.height;
                    rect.height += rect2.height;
                    item.width = rect.width;
                }
                if (std.meta.eql(item.*, rect2)) {
                    delete_index = index;
                }
            }

            _ = backgrounds_arr.orderedRemove(delete_index);
        }
    }

    // std.log.info("Horizontal", .{});
    // for (walls_horizontal.items) |wall| {
    //     std.log.info(
    //         "Wall: x: {d} | y: {d} | w: {d} | h: {d}",
    //         .{ wall.x, wall.y, wall.width, wall.height },
    //     );
    // }
    // std.log.info("Vertical", .{});
    // for (walls_vertical.items) |wall| {
    //     std.log.info(
    //         "Wall: x: {d} | y: {d} | w: {d} | h: {d}",
    //         .{ wall.x, wall.y, wall.width, wall.height },
    //     );
    // }

    // std.log.info("Backgrounds", .{});
    // for (backgrounds_arr.items) |wall| {
    //     std.log.info(
    //         "Background: x: {d} | y: {d} | w: {d} | h: {d}",
    //         .{ wall.x, wall.y, wall.width, wall.height },
    //     );
    // }

    var wallsarr = std.ArrayList(e.Entity).init(e.ALLOCATOR);
    defer wallsarr.deinit();

    var backsarr = std.ArrayList(e.Entity).init(e.ALLOCATOR);
    defer wallsarr.deinit();

    for (walls_horizontal.items) |rect| {
        try wallsarr.append(
            e.Entity{
                .id = ".",
                .tags = ".",
                .transform = .{
                    .position = e.Vec2(
                        rect.x * 64 + rect.width * 64 / 2,
                        rect.y * 64 - 64 + rect.height * 64 / 2,
                    ),
                    .rotation = e.Vec3(0, 0, 0),
                    .scale = e.Vec2(rect.width * 64, 192),
                },
                .display = .{
                    .scaling = .pixelate,
                    .sprite = "sprites/backgrounds/w16x48.png",
                    .layer = .foreground,
                    .background_tile_size = e.Vec2(64, 192),
                },
                .collider = e.components.Collider{
                    .dynamic = false,
                    .rect = e.Rect(0, -32, rect.width * 64, 32),
                    .weight = 10,
                },
            },
        );
    }

    for (walls_vertical.items) |rect| {
        try wallsarr.append(
            e.Entity{
                .id = ".",
                .tags = ".",
                .transform = .{
                    .position = e.Vec2(
                        rect.x * 64 + rect.width * 64 / 2,
                        rect.y * 64 - 128 + rect.height * 64 / 2,
                    ),
                    .rotation = e.Vec3(0, 0, 0),
                    .scale = e.Vec2(rect.width * 64, rect.height * 64),
                },
                .display = .{
                    .scaling = .pixelate,
                    .sprite = "sprites/backgrounds/wt16x16.png",
                    .layer = .foreground,
                    .background_tile_size = e.Vec2(64, 64),
                },
                .collider = e.components.Collider{
                    .dynamic = false,
                    .rect = e.Rect(0, 96, rect.width * 64, rect.height * 64 - 32),
                    .weight = 10,
                },
            },
        );
    }

    for (backgrounds_arr.items) |rect| {
        try backsarr.append(
            e.Entity{
                .id = ".",
                .tags = ".",
                .transform = .{
                    .position = e.Vec2(
                        rect.x * 64 + rect.width * 64 / 2,
                        rect.y * 64 + rect.height * 64 / 2,
                    ),
                    .rotation = e.Vec3(0, 0, 0),
                    .scale = e.Vec2(rect.width * 64, rect.height * 64),
                },
                .display = .{
                    .scaling = .pixelate,
                    .sprite = "sprites/backgrounds/16x16.png",
                    .layer = .background,
                    .background_tile_size = e.Vec2(64, 64),
                },
            },
        );
    }

    const walls: []e.Entity = try wallsarr.toOwnedSlice();
    defer wallsarr.allocator.free(walls);

    const backgrounds: []e.Entity = try backsarr.toOwnedSlice();
    defer backsarr.allocator.free(backgrounds);

    try load(.{
        .rounds = &[_][]conf.EnemySpawner{},
        .reward_tier = .common,
        .backgrounds = backgrounds,
        .walls = walls,
        .player_pos = player_pos,
    });
}

pub const editor_suit = struct {
    var enabled = false;

    pub fn getCursorPos() e.Vector2 {
        const cursor = e.camera
            .screenPositionToWorldPosition(e.input.mouse_position)
            .subtract(e.window.size
            .divide(e.Vec2(2, 2))
            .divide(e.Vec2(e.camera.zoom, e.camera.zoom)));

        const x: f32 = @divFloor(cursor.x, 64);
        const y: f32 = @divFloor(cursor.y, 64);

        const x_rem: f32 = @round(@divTrunc(@rem(cursor.x - @round(x), 64), 64));
        const y_rem: f32 = @round(@divTrunc(@rem(cursor.y - @round(y), 64), 64));

        return e.Vec2(
            x * 64 + x_rem * 64,
            y * 64 + y_rem * 64,
        );
    }

    var selected_shower: e.Entity = .{
        .id = "placedownShower",
        .tags = "",
        .transform = .{},
        .display = .{},
    };

    pub fn awake() !void {
        try e.entities.add(&selected_shower);
    }

    pub fn update() !void {
        if (!enabled) return;

        selected_shower.transform.position = getCursorPos();
    }

    pub fn deinit() !void {}

    pub fn enable() void {
        enabled = true;
        e.input.ui_mode = true;
    }

    pub fn disable() void {
        enabled = false;
        e.input.ui_mode = false;
    }
};
