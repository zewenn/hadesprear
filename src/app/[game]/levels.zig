const std = @import("std");
const Allocator = std.mem.Allocator;

const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const enemies = @import("enemies.zig");

var loaded: ?conf.LoadedLevel = null;
var round: usize = 0xff15;
var actual_round: usize = 0;
var round_playing = true;

var Player: *e.Entity = undefined;

const TMType = e.time.TimeoutHandler(struct {});
var tm: TMType = undefined;

const manager = e.zlib.HeapManager(e.Entity, (struct {
    pub fn callback(alloc: Allocator, item: *e.Entity) !void {
        e.entities.remove(item.id);
        alloc.free(item.id);
        item.deinit();
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

    var rounds: [][]*conf.EnemySpawner = try e.ALLOCATOR.alloc([]*conf.EnemySpawner, from.rounds.len);
    for (from.rounds, 0..) |spawnerlist, index| {
        var enemy_spawners: []*conf.EnemySpawner = try e.ALLOCATOR.alloc(*conf.EnemySpawner, spawnerlist.len);
        for (spawnerlist, 0..) |spawner, jndex| {
            const spawner_ptr = try e.ALLOCATOR.create(conf.EnemySpawner);
            spawner_ptr.* = spawner;

            enemy_spawners[jndex] = spawner_ptr;
        }

        rounds[index] = enemy_spawners;
    }

    return conf.LoadedLevel{
        .rounds = rounds,
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
    if (e.isKeyDown(.key_left_alt) and e.isKeyPressed(.key_e)) {
        editor_suit.toggle();
    }

    try editor_suit.update();

    try tm.update();

    if (round == 0xff15) return;
    if (loaded == null) return;

    const enemies_in_scene = enemies.manager.len();
    if (enemies_in_scene == 0 and round_playing) try startRound();
}

pub fn deinit() !void {
    unload();
    tm.deinit();
    // editor_suit.manager.deinit();

    const items = manager.items() catch {
        std.log.err("Failed to get items from the manager", .{});
        return;
    };
    defer manager.alloc.free(items);

    for (items) |item| {
        manager.removeFreeId(item);
    }
    manager.deinit();

    try editor_suit.deinit();
}

pub fn load(level: conf.Level) !void {
    if (loaded) |_| unload();
    loaded = try makeLoadedLevel(level);
    round = 0;

    const loadedptr = &(loaded orelse return);

    Player.transform.position = level.player_pos.multiply(e.Vec2(64, 64));

    for (loadedptr.backgrounds) |entity| {
        try e.entities.append(entity);
    }

    for (loadedptr.walls) |entity| {
        if (entity.collider == null) @panic("Walls must have colliders");

        try e.entities.append(entity);
    }
}

pub fn unload() void {
    const loadedptr = &(loaded orelse return);

    round = 0xff15;

    for (loadedptr.backgrounds) |entity| {
        manager.removeFreeId(entity);
    }
    e.ALLOCATOR.free(loadedptr.backgrounds);

    for (loadedptr.walls) |entity| {
        manager.removeFreeId(entity);
    }
    e.ALLOCATOR.free(loadedptr.walls);

    for (loadedptr.rounds) |loaded_round| {
        for (loaded_round) |spawner| {
            e.ALLOCATOR.destroy(spawner);
        }
        e.ALLOCATOR.free(loaded_round);
    }
    e.ALLOCATOR.free(loadedptr.rounds);

    const items = manager.items() catch {
        std.log.err("Failed to get items from the manager", .{});
        return;
    };
    defer manager.alloc.free(items);

    for (items) |item| {
        manager.removeFreeId(item);
    }

    loaded = null;
}

pub fn startRound() !void {
    if (editor_suit.enabled) return;
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

pub fn loadFromMatrix(matrix: [200][200]u16) !void {
    const WALL_ID = 1;
    const BACKGROUND_ID = 2;
    const BACKGROUND_2_ID = 3;
    const PLAYER_SPAWNER = 4;

    // Enemies are defined in packs of 20
    // for example from 20 to 40
    // const ENEMIES = struct {
    //     pub const MINION_SPAWNER = 20;
    //     pub const BRUTE_SPAWNER = 21;
    //     pub const ANGLER_SPAWNER = 22;
    //     pub const TANK_SPAWNER = 23;
    // };
    // _ = ENEMIES;

    const RectangleArrayList = std.ArrayList(e.Rectangle);

    var wall_rectangles_horizontal = RectangleArrayList.init(e.ALLOCATOR);
    defer wall_rectangles_horizontal.deinit();
    errdefer wall_rectangles_horizontal.deinit();

    var wall_rectangless_vertical = RectangleArrayList.init(e.ALLOCATOR);
    defer wall_rectangless_vertical.deinit();
    errdefer wall_rectangless_vertical.deinit();

    var backgrounds_rectangles_arraylist = RectangleArrayList.init(e.ALLOCATOR);
    defer backgrounds_rectangles_arraylist.deinit();
    errdefer backgrounds_rectangles_arraylist.deinit();

    var player_position = e.Vec2(5, 5);
    var spawning_enemies_array: [10]std.ArrayList(conf.EnemySpawner) = [_]std.ArrayList(conf.EnemySpawner){undefined} ** 10;
    for (spawning_enemies_array, 0..) |_, index| {
        spawning_enemies_array[index] = std.ArrayList(conf.EnemySpawner).init(e.ALLOCATOR);
    }
    var read_rounds: [10][]conf.EnemySpawner = undefined;

    defer {
        for (read_rounds) |arr| {
            e.ALLOCATOR.free(arr);
        }

        for (spawning_enemies_array, 0..) |_, index| {
            spawning_enemies_array[index].deinit();
        }
    }

    Rectangles: {
        var current_width: f32 = 0;
        var current_height: f32 = 0;

        // =========================== [HORIZONTAL WALLS] ============================

        for (matrix, 0..) |row, ri| {
            current_width = 0;

            for (row, 0..) |col, ci| {
                if (col != WALL_ID) {
                    const condition2 = if (current_width == 0)
                        false
                    else if (ri >= 1 and ri <= 198) Ans: {
                        if (matrix[ri - 1][ci] == WALL_ID and matrix[ri + 1][ci] == WALL_ID)
                            break :Ans false;
                        break :Ans true;
                    } else false;

                    if (current_width >= 2 or condition2) {
                        wall_rectangles_horizontal.append(
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

        // ============================ [VERTICAL WALLS] ============================

        current_height = 0;
        for (0..matrix[0].len) |ci| {
            for (matrix, 0..) |row, ri| {
                const col = row[ci];

                if (col != WALL_ID) {
                    if (current_height >= 2) {
                        wall_rectangless_vertical.append(
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

        // ============================ [BACKGROUND #1] ============================

        current_width = 0;
        current_height = 1;
        for (matrix, 0..) |row, ri| {
            for (row, 0..) |col, ci| {
                if (col != BACKGROUND_ID and col != PLAYER_SPAWNER and @divFloor(col, 40000) != 1) {
                    if (current_width >= 1) {
                        backgrounds_rectangles_arraylist.append(
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

        // ============================ [BACKGROUND #2] ============================

        current_width = 0;
        current_height = 1;
        for (matrix, 0..) |row, ri| {
            for (row, 0..) |col, ci| {
                if (col != BACKGROUND_2_ID) {
                    if (current_width >= 1) {
                        backgrounds_rectangles_arraylist.append(
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

        // =========================== [BACKGROUND MERGE] ===========================

        const background_rectangles_cloned_slice = try e.zlib.arrays.cloneToOwnedSlice(
            e.Rectangle,
            backgrounds_rectangles_arraylist,
        );
        defer e.ALLOCATOR.free(background_rectangles_cloned_slice);

        std.sort.insertion(
            e.Rectangle,
            background_rectangles_cloned_slice,
            {},
            sortRectsByY,
        );

        for (background_rectangles_cloned_slice) |*outer_rectangle| {
            const updated_background_rectangles_cloned_slice = try e.zlib.arrays.cloneToOwnedSlice(
                e.Rectangle,
                backgrounds_rectangles_arraylist,
            );
            defer e.ALLOCATOR.free(updated_background_rectangles_cloned_slice);

            std.sort.insertion(
                e.Rectangle,
                updated_background_rectangles_cloned_slice,
                {},
                sortRectsByY,
            );

            for (updated_background_rectangles_cloned_slice) |inner_rectangle| {
                if (outer_rectangle.x != inner_rectangle.x) continue;
                if (outer_rectangle.width != inner_rectangle.width) continue;
                if (outer_rectangle.y + outer_rectangle.height != inner_rectangle.y) continue;
                if (std.meta.eql(outer_rectangle.*, inner_rectangle)) continue;

                var delete_index: usize = 0;

                for (backgrounds_rectangles_arraylist.items, 0..) |*item, index| {
                    if (std.meta.eql(item.*, outer_rectangle.*)) {
                        item.x = outer_rectangle.x;
                        item.y = outer_rectangle.y;
                        item.height += inner_rectangle.height;
                        outer_rectangle.height += inner_rectangle.height;
                        item.width = outer_rectangle.width;
                    }
                    if (std.meta.eql(item.*, inner_rectangle)) {
                        delete_index = index;
                    }
                }

                _ = backgrounds_rectangles_arraylist.orderedRemove(delete_index);
            }
        }

        // ============================ [PLAYER SPAWNER] ============================

        for (matrix, 0..) |row, ri| outer: {
            for (row, 0..) |col, ci| {
                if (col != PLAYER_SPAWNER) continue;

                player_position = e.Vec2(ci, ri);
                try editor_suit.newSpawner(.player, player_position, "{s}", "P");

                break :outer;
            }
        }

        // ============================ [ENEMY SPAWNERS] ============================

        // MAX 65535 => 0-0-0-00
        // 4    -  (1->6)  -  (1->99)  -  (0->9)
        // ENEMYID ARCHETYPE  SUBTYPE    ROUND

        for (matrix, 0..) |row, ri| {
            for (row, 0..) |col, ci| {
                // Filtering out enemy spawners
                if (@divFloor(col, 40000) != 1) continue;

                const asr: u16 = col - 40000;
                const archetype = (asr - (asr % 1000)) / 1000;
                const subtype = (asr - archetype * 1000 - (asr % 10)) / 10;
                const r = (asr - archetype * 1000 - subtype * 10);

                std.log.info("ars: {d}", .{asr});
                std.log.info("| a: {d}", .{archetype});
                std.log.info("| s: {d}", .{subtype});
                std.log.info("|-r: {d}", .{r});

                const enemy_pos = e.Vec2(ci, ri);
                try editor_suit.newSpawner(.enemy, enemy_pos, "R{d}", r);

                try spawning_enemies_array[r].append(conf.EnemySpawner{
                    .enemy_archetype = @enumFromInt(archetype),
                    .enemy_subtype = @enumFromInt(subtype),
                    .spawn_at = enemy_pos
                        .multiply(e.Vec2(64, 64)),
                });

                // if (col < ENEMIES.MINION_SPAWNER or col > ENEMIES.TANK_SPAWNER) continue;

                // player_position = e.Vec2(ci, ri);
                // try editor_suit.newSpawner(.player, player_position);
            }
        }

        for (spawning_enemies_array, 0..) |_, index| {
            read_rounds[index] = try spawning_enemies_array[index].toOwnedSlice();
        }

        break :Rectangles;
    }

    var wall_entities_arraylist = std.ArrayList(e.Entity).init(e.ALLOCATOR);
    defer wall_entities_arraylist.deinit();
    errdefer wall_entities_arraylist.deinit();

    var background_entities_arraylist = std.ArrayList(e.Entity).init(e.ALLOCATOR);
    defer background_entities_arraylist.deinit();
    errdefer background_entities_arraylist.deinit();

    Entities: {
        // =========================== [HORIZONTAL WALLS] ============================

        for (wall_rectangles_horizontal.items) |rect| {
            try wall_entities_arraylist.append(
                e.Entity{
                    .id = ".",
                    .tags = ".",
                    .transform = .{
                        .position = e.Vec2(
                            rect.x * 64 + rect.width * 64 / 2 - 32,
                            rect.y * 64 - 64 + rect.height * 64 / 2 - 32,
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

        // ============================ [VERTICAL WALLS] ============================

        for (wall_rectangless_vertical.items) |rect| {
            try wall_entities_arraylist.append(
                e.Entity{
                    .id = ".",
                    .tags = ".",
                    .transform = .{
                        .position = e.Vec2(
                            rect.x * 64 + rect.width * 64 / 2 - 32,
                            rect.y * 64 - 128 + rect.height * 64 / 2 - 32,
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

        // ============================= [BACKGROUNDS] ==============================

        for (backgrounds_rectangles_arraylist.items) |rect| {
            try background_entities_arraylist.append(
                e.Entity{
                    .id = ".",
                    .tags = ".",
                    .transform = .{
                        .position = e.Vec2(
                            rect.x * 64 + rect.width * 64 / 2 - 32,
                            rect.y * 64 + rect.height * 64 / 2 + 32,
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
        break :Entities;
    }

    const walls: []e.Entity = try wall_entities_arraylist.toOwnedSlice();
    defer wall_entities_arraylist.allocator.free(walls);

    const backgrounds: []e.Entity = try background_entities_arraylist.toOwnedSlice();
    defer background_entities_arraylist.allocator.free(backgrounds);

    try load(.{
        .rounds = &read_rounds,
        .reward_tier = .common,
        .backgrounds = backgrounds,
        .walls = walls,
        .player_pos = player_position,
    });
}

pub const editor_suit = struct {
    pub const ManagerType = struct {
        entity: e.Entity,
        gui: *e.GUI.GUIElement,
    };
    pub const manager = e.zlib.HeapManager(ManagerType, (struct {
        pub fn callback(alloc: Allocator, item: *ManagerType) !void {
            e.entities.remove(item.entity.id);
            alloc.free(item.entity.id);

            item.entity.deinit();
            e.ALLOCATOR.free(item.gui.options.id);
            if (item.gui.contents) |c|
                e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, c);
            try e.GUI.remove(item.gui);
        }
    }).callback);

    var enabled = false;
    // 0 - EMPTY
    // 1 - WALL
    // 2 - BACKGROUND
    // 3 - BACKGROUND_2
    // 4 - SPAWN PLAYER
    // 4xyyz -> ENEMY SPAWNER
    var placedown_type: u16 = 1;
    var current_matrix: [200][200]u16 = undefined;
    var cursor_position: e.Vector2 = e.Vec2(0, 0);

    var last_pos: e.Vector2 = e.Vec2(0, 0);
    var last_placedown_type: u16 = 0;

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
            x + x_rem,
            y + y_rem,
        );
    }

    var selected_shower: e.Entity = .{
        .id = "placedownShower",
        .tags = "",
        .transform = .{},
        .display = .{},
    };

    pub fn awake() !void {
        try e.entities.append(&selected_shower);
        editor_suit.manager.init(e.ALLOCATOR);

        current_matrix = [_][200]u16{[_]u16{0} ** 200} ** 200;
    }

    pub fn update() !void {
        if (!enabled) return;

        cursor_position = getCursorPos();

        if (cursor_position.x < 0 or cursor_position.y < 0) return;

        selected_shower.transform.position = cursor_position
            .multiply(e.Vec2(64, 64));

        const items = editor_suit.manager.items() catch {
            std.log.err("Failed to get items!", .{});
            return;
        };
        defer editor_suit.manager.free(items);

        for (items) |item| {
            const screen_pos = e.camera.worldPositionToScreenPosition(
                item.entity.transform.position.add(e.Vec2(24, 24)),
            );
            item.gui.options.style.top = e.GUI.toUnit(screen_pos.y);
            item.gui.options.style.left = e.GUI.toUnit(screen_pos.x);
        }

        if (e.isMouseButtonDown(.mouse_button_left) and
            (last_pos.equals(cursor_position) == 0 or
            last_placedown_type != placedown_type))
        {
            if (placedown_type == 4) {
                for (current_matrix, 0..) |row, ri| {
                    for (row, 0..) |col, ci| {
                        if (col != 4) continue;
                        current_matrix[ri][ci] = 2;
                    }
                }
            }
            current_matrix[e.loadusize(cursor_position.y)][e.loadusize(cursor_position.x)] = placedown_type;

            editor_suit.unload();
            try loadFromMatrix(current_matrix);

            last_placedown_type = placedown_type;
            last_pos = cursor_position;
        }

        var move_vector = e.Vec2(0, 0);

        if (e.isKeyDown(.key_w)) {
            move_vector.y -= 1;
        }
        if (e.isKeyDown(.key_s)) {
            move_vector.y += 1;
        }
        if (e.isKeyDown(.key_a)) {
            move_vector.x -= 1;
        }
        if (e.isKeyDown(.key_d)) {
            move_vector.x += 1;
        }

        if (e.isKeyPressed(.key_zero)) placedown_type = 0;
        if (e.isKeyPressed(.key_one)) placedown_type = 1;
        if (e.isKeyPressed(.key_two)) placedown_type = 2;
        if (e.isKeyPressed(.key_three)) placedown_type = 3;
        if (e.isKeyPressed(.key_four)) placedown_type = 4;
        if (e.isKeyPressed(.key_five)) placedown_type = 40000;
        if (e.isKeyPressed(.key_six)) placedown_type = 41131;

        e.camera.position = e.camera.position
            .add(move_vector
            .multiply(e.Vec2(
            350 * e.time.DeltaTime(),
            350 * e.time.DeltaTime(),
        )));
    }

    pub fn deinit() !void {
        editor_suit.unload();

        const items = editor_suit.manager.items() catch {
            std.log.err("Failed to get items!", .{});
            return;
        };
        defer editor_suit.manager.free(items);

        for (items) |item| {
            editor_suit.manager.removeFreeId(item);
        }

        editor_suit.manager.deinit();
    }

    pub fn enable() void {
        e.camera.follow_stopped = true;
        enabled = true;
        e.input.ui_mode = true;

        const items = editor_suit.manager.items() catch {
            std.log.err("Failed to get items!", .{});
            return;
        };
        defer editor_suit.manager.free(items);

        for (items) |item| {
            item.entity.transform.scale = e.Vec2(64, 64);
            item.gui.options.style.display = true;
        }
    }

    pub fn disable() void {
        e.camera.follow_stopped = false;
        enabled = false;
        e.input.ui_mode = false;

        const items = editor_suit.manager.items() catch {
            std.log.err("Failed to get items!", .{});
            return;
        };
        defer editor_suit.manager.free(items);

        for (items) |item| {
            item.entity.transform.scale = e.Vec2(0, 0);
            item.gui.options.style.display = false;
        }
    }

    pub fn toggle() void {
        if (enabled) {
            disable();
            return;
        }
        enable();
    }

    pub fn newSpawner(side: conf.ProjectileSide, at: e.Vector2, comptime fmt: []const u8, text: anytype) !void {
        const to_text = try std.fmt.allocPrint(e.ALLOCATOR, fmt, .{text});
        defer e.ALLOCATOR.free(to_text);

        const pos = at.multiply(switch (enabled) {
            true => e.Vec2(64, 64),
            false => e.Vec2(0, 0),
        });

        const guitext = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, to_text);
        // const screen_pos = e.camera.worldPositionToScreenPosition(pos);

        const returned = try editor_suit.manager.appendReturn(.{
            .entity = .{
                .id = try e.UUIDV7(),
                .tags = switch (side) {
                    .player => "player_spawner",
                    .enemy => "enemy_spawner",
                },
                .transform = .{
                    .position = pos,
                },
                .display = .{
                    .scaling = .pixelate,
                    .layer = .editor_spawners,
                },
            },
            .gui = try e.GUI.Text(
                .{
                    .id = try e.UUIDV7(),
                    .style = .{
                        .top = e.GUI.toUnit(250),
                        .left = e.GUI.toUnit(250),
                        .color = e.Colour.white,
                        .font = .{
                            .shadow = .{
                                .color = e.Colour.gray,
                                .offset = e.Vec2(1, 1),
                            },
                        },
                    },
                },
                guitext,
            ),
        });

        try e.entities.append(&(returned.entity));
    }

    pub fn unload() void {
        const items = editor_suit.manager.items() catch {
            std.log.err("Failed to get items!", .{});
            return;
        };
        defer editor_suit.manager.free(items);

        for (items) |item| {
            editor_suit.manager.removeFreeId(item);
        }
    }
};
