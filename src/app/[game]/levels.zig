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
            // conf.EnemySpawner{
            //     .enemy_archetype = .brute,
            //     .enemy_subtype = .normal,
            //     .spawn_at = e.Vec2(64, 128),
            // },
            // conf.EnemySpawner{
            //     .enemy_archetype = .angler,
            //     .enemy_subtype = .normal,
            //     .spawn_at = e.Vec2(-600, -156),
            // },
        }),
        @constCast(&[_]conf.EnemySpawner{
            // conf.EnemySpawner{
            //     .enemy_archetype = .brute,
            //     .enemy_subtype = .normal,
            //     .spawn_at = e.Vec2(64, 128),
            // },
            // conf.EnemySpawner{
            //     .enemy_archetype = .angler,
            //     .enemy_subtype = .normal,
            //     .spawn_at = e.Vec2(-600, -156),
            // },
            // conf.EnemySpawner{
            //     .enemy_archetype = .angler,
            //     .enemy_subtype = .normal,
            //     .spawn_at = e.Vec2(-300, -186),
            // },
            // conf.EnemySpawner{
            //     .enemy_archetype = .angler,
            //     .enemy_subtype = .normal,
            //     .spawn_at = e.Vec2(-100, -200),
            // },
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

    const loadedptr = &(loaded orelse return);

    Player.transform.position = level.player_pos.multiply(e.Vec2(64, 64));

    for (loadedptr.backgrounds) |entity| {
        try e.entities.add(entity);
    }

    for (loadedptr.walls) |entity| {
        if (entity.collider == null) @panic("Walls must have colliders");

        try e.entities.add(entity);
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
    const WALL_ID = 1;
    const BACKGROUND_ID = 2;
    const BACKGROUND_2_ID = 3;
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

    const player_position = e.Vec2(5, 5);

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
                if (col != BACKGROUND_ID) {
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
        .rounds = &[_][]conf.EnemySpawner{},
        .reward_tier = .common,
        .backgrounds = backgrounds,
        .walls = walls,
        .player_pos = player_position,
    });
}

pub const editor_suit = struct {
    var enabled = false;
    // 0 - EMPTY
    // 1 - WALL
    // 2 - BACKGROUND
    var placedown_type: u8 = 1;
    var current_matrix: [200][200]u8 = undefined;
    var cursor_position: e.Vector2 = e.Vec2(0, 0);

    var last_pos: e.Vector2 = e.Vec2(0, 0);
    var last_placedown_type: u8 = 0;

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

        cursor_position.x = x + x_rem;
        cursor_position.y = y + y_rem;

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

        current_matrix = [_][200]u8{[_]u8{0} ** 200} ** 200;
    }

    pub fn update() !void {
        if (!enabled) return;

        selected_shower.transform.position = getCursorPos();

        if (cursor_position.x < 0 or cursor_position.y < 0) return;

        if (e.isMouseButtonDown(.mouse_button_left) and
            (last_pos.equals(cursor_position) == 0 or
            last_placedown_type != placedown_type))
        {
            current_matrix[e.loadusize(cursor_position.y)][e.loadusize(cursor_position.x)] = placedown_type;
            // std.log.debug("manager.items.len: {d}", .{manager.len()});
            try loadFromMatrix(current_matrix);
            // std.log.debug("manager.items.len: {d}", .{manager.len()});

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

        if (e.isKeyPressed(.key_one)) placedown_type = 1;
        if (e.isKeyPressed(.key_two)) placedown_type = 2;

        e.camera.position = e.camera.position
            .add(move_vector
            .multiply(e.Vec2(
            350 * e.time.DeltaTime(),
            350 * e.time.DeltaTime(),
        )));
    }

    pub fn deinit() !void {}

    pub fn enable() void {
        e.camera.follow_stopped = true;
        enabled = true;
        e.input.ui_mode = true;
    }

    pub fn disable() void {
        e.camera.follow_stopped = false;
        enabled = false;
        e.input.ui_mode = false;
    }

    pub fn toggle() void {
        if (enabled) {
            disable();
            return;
        }
        enable();
    }
};
