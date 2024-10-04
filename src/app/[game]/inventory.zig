const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const GUI = e.GUI;

const u = GUI.u;
const toUnit = GUI.toUnit;

const bag_pages: comptime_int = 3;
const bag_page_rows: comptime_int = 4;
const bag_page_cols: comptime_int = 7;
const bag_size: comptime_int = bag_pages * bag_page_rows * bag_page_cols;
const bag_page_size: comptime_int = bag_page_cols * bag_page_rows;

pub const Item = conf.Item;

pub var delete_mode: bool = false;
pub var delete_mode_last_frame: bool = false;

pub var Hands = conf.Item{
    .T = .weapon,
    .damage = 10,
    .weapon_projectile_scale = e.Vec2(64, 64),

    .icon = "sprites/entity/player/weapons/gloves/left.png",
    .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
    .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
};

pub var bag: [bag_size]?conf.Item = [_]?conf.Item{null} ** bag_size;
pub var sorted_bag: []*?conf.Item = undefined;

const equipped = struct {
    pub var current_weapon: *Item = &Hands;
    pub var ring: ?*Item = null;
    pub var amethist: ?*Item = null;
    pub var wayfinder: ?*Item = null;
};

var INVENTORY_GUI: *GUI.GUIElement = undefined;
var shown: bool = false;
var bag_element: *GUI.GUIElement = undefined;
var slots: []*GUI.GUIElement = undefined;

const current_page = struct {
    var value: usize = 0;

    pub fn set(to: usize) void {
        if (to >= bag_pages) return;
        if (to < 0) return;

        value = to;
    }

    pub fn get() usize {
        return value;
    }
};

const SLOT_SIZE: f32 = 5;

const WIDTH_VW: f32 = SLOT_SIZE * 7 + 6;
const HEIGHT_VW: f32 = SLOT_SIZE * 4 + 3;

/// The sorting function `sortBag()` uses.
fn sort(_: void, a: *?conf.Item, b: *?conf.Item) bool {
    if (b.* == null) return true;
    if (a.* == null) return false;

    if (b.*.?.rarity == .common and a.*.?.rarity != .common) return true;
    if (b.*.?.rarity == .epic and a.*.?.rarity == .legendary) return true;

    if (b.*.?.rarity == a.*.?.rarity) return true;

    if (a.*.?.rarity == .common and b.*.?.rarity != .common) return false;
    if (a.*.?.rarity == .epic and b.*.?.rarity == .legendary) return false;

    std.log.warn("Something went wrong in the sort...", .{});
    return false;
}

/// Sorts the bag, result is in `sorted_bag`.
/// `null`s will be at the end of the array.
pub fn sortBag() void {
    std.sort.insertion(
        *?conf.Item,
        sorted_bag,
        {},
        sort,
    );
}

/// Return `true` when the item was picked up successfully,
/// `false` when the inventory is full.
pub fn pickUp(item: conf.Item) bool {
    for (bag, 0..) |it, index| {
        if (it != null) continue;

        bag[index] = item;
        return true;
    }
    return false;
}

/// Picks up the item, if the inventory is full returns `false` else `true`.
/// Sorts the bag by calling `sortBag()`.
pub fn pickUpSort(item: conf.Item) bool {
    const res = pickUp(item);
    sortBag();
    return res;
}

/// Refreses the UI to contain all items on the page
pub fn updateGUI() !void {
    for (0..bag_page_rows) |row| {
        for (0..bag_page_cols) |col| {
            const index = current_page.get() *
                bag_page_size +
                row *
                bag_page_cols +
                col;

            const element_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(element_selector);

            const button_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-btn-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(button_selector);

            const shower_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-btn-shower-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(shower_selector);

            const element: *GUI.GUIElement = if (GUI.select(element_selector)) |el| el else continue;
            const button: *GUI.GUIElement = if (GUI.select(button_selector)) |el| el else continue;
            const shower: *GUI.GUIElement = if (GUI.select(shower_selector)) |el| el else continue;

            const item = sorted_bag[index].*;

            if (item) |it| {
                shower.options.style.background.image = it.icon;

                element.options.style.background.image = switch (it.rarity) {
                    .common => "sprites/gui/item_slot.png",
                    .epic => "sprites/gui/item_slot_epic.png",
                    .legendary => "sprites/gui/item_slot_legendary.png",
                };

                if (delete_mode) {
                    button.options.hover.background.image = "sprites/gui/delete_slot.png";
                    continue;
                }
                button.options.hover.background.image = "sprites/gui/slot_highlight.png";
                continue;
            }

            button.options.hover.background.image = switch (delete_mode) {
                false => "sprites/gui/slot_highlight.png",
                true => "sprites/gui/slot_highlight_delete.png",
            };

            shower.options.style.background.image = null;
            element.options.style.background.image = "sprites/gui/item_slot_empty.png";
        }
    }

    const delete_button: *GUI.GUIElement = if (GUI.select("#delete_mode_shower")) |el| el else return;
    switch (delete_mode) {
        true => {
            delete_button.options.style.rotation = 15;
        },
        false => {
            delete_button.options.style.rotation = 0;
        },
    }
}

pub fn logSortedBag() void {
    std.log.debug("Sorted bag: ", .{});
    for (sorted_bag, 0..) |it, i| {
        std.debug.print("{d}: ", .{i});
        if (it.*) |item| {
            std.debug.print("{s}\n", .{item.icon});
            continue;
        }
        std.debug.print("null\n", .{});
    }
}

/// Generates the button/slot interface
inline fn generateBtn(
    id: []const u8,
    btn_id: []const u8,
    shower_id: []const u8,
    col_start: f32,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .height = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .left = .{
                .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .top = .{
                .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .background = .{
                .image = "sprites/gui/item_slot.png",
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .width = u("100%"),
                    .height = u("100%"),
                    .top = u("0%"),
                    .left = u("0%"),
                },
                .hover = .{
                    .background = .{
                        .image = "sprites/gui/slot_highlight.png",
                    },
                },
            },
            "",
            e.Vec2(0 + col + col_start, 0 + row),
            if (func) |fun| fun else (struct {
                pub fn callback() anyerror!void {
                    if (!delete_mode) return;
                    if (col_start != 0)
                        sorted_bag[
                            bag_page_size *
                                current_page.get() +
                                row * bag_page_cols +
                                col
                        ].* = null;
                    sortBag();
                    try updateGUI();
                }
            }).callback,
        ),
        try GUI.Empty(.{
            .id = shower_id,
            .style = .{
                .width = u("100%"),
                .height = u("100%"),
                .background = .{
                    .image = "sprites/entity/player/weapons/gloves/left.png",
                },
            },
        }),
    }));
}

/// Generates the button/slot interface
inline fn generatePageBtn(
    id: []const u8,
    btn_id: []const u8,
    text: [*:0]const u8,
    page: usize,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = SLOT_SIZE * 2 + 1,
                .unit = .vw,
            },
            .height = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .left = .{
                .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + 1) - 1.5 + SLOT_SIZE / 2,
                .unit = .vw,
            },
            .top = .{
                .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .background = .{
                .image = "sprites/gui/page_btn_inactive.png",
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .top = u("50%"),
                    .left = u("50%"),
                    .width = u("100%"),
                    .height = u("100%"),
                    .translate = .{
                        .x = .center,
                        .y = .center,
                    },
                    .font = .{
                        .size = 18,
                    },
                    .color = e.Color.black,
                },
                .hover = .{
                    .color = e.Color.black,
                    .background = .{
                        .image = "sprites/gui/page_btn.png",
                    },
                },
            },
            text,
            e.Vec2(0 + col, 0 + row),
            if (func) |fun| fun else (struct {
                pub fn callback() anyerror!void {
                    current_page.set(page);
                    //
                    sortBag();
                    try updateGUI();
                    //
                    const p0: *GUI.GUIElement = if (GUI.select("#page1")) |el| el else return;
                    const p1: *GUI.GUIElement = if (GUI.select("#page2")) |el| el else return;
                    const p2: *GUI.GUIElement = if (GUI.select("#page3")) |el| el else return;
                    //
                    p0.options.style.background.image = "sprites/gui/page_btn_inactive.png";
                    p1.options.style.background.image = "sprites/gui/page_btn_inactive.png";
                    p2.options.style.background.image = "sprites/gui/page_btn_inactive.png";
                    //
                    const selector = try std.fmt.allocPrint(e.ALLOCATOR, "#page{d}", .{page + 1});
                    defer e.ALLOCATOR.free(selector);
                    const self: *GUI.GUIElement = if (GUI.select(selector)) |el| el else return;
                    self.options.style.background.image = "sprites/gui/page_btn.png";
                }
            }).callback,
        ),
    }));
}

pub fn show() void {
    INVENTORY_GUI.options.style.top = u("0%");
    e.input.ui_mode = true;
    shown = true;
}

pub fn hide() void {
    INVENTORY_GUI.options.style.top = u("-100%");
    e.input.ui_mode = false;
    shown = false;
}

pub fn toggle() void {
    if (shown) hide() else show();
}

pub fn awake() !void {
    // e.input.ui_mode = true;

    sorted_bag = try e.ALLOCATOR.alloc(*?conf.Item, bag_size);

    for (0..bag.len) |index| {
        sorted_bag[index] = &(bag[index]);
    }

    sortBag();

    slots = try e.ALLOCATOR.alloc(*GUI.GUIElement, bag_page_rows * bag_page_cols);

    inline for (0..bag_page_rows) |row| {
        inline for (0..bag_page_cols) |col| {
            const id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-{d}-{d}",
                .{ row, col },
            );
            const button_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-btn-{d}-{d}",
                .{ row, col },
            );
            const button_shower_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-btn-shower-{d}-{d}",
                .{ row, col },
            );

            slots[row * bag_page_cols + col] = try generateBtn(
                id,
                button_id,
                button_shower_id,
                1,
                col,
                row,
                WIDTH_VW,
                HEIGHT_VW + SLOT_SIZE + 1,
                null,
            );

            slots[row * bag_page_cols + col].heap_id = true;
            slots[row * bag_page_cols + col].children.?.items[0].heap_id = true;
            slots[row * bag_page_cols + col].children.?.items[1].heap_id = true;
        }
    }

    INVENTORY_GUI = try GUI.Container(
        .{
            .id = "InventoryParentBackground",
            .style = .{
                .background = .{
                    .color = e.Color.init(0, 0, 0, 128),
                },
                .top = u("-100%"),
                .width = u("100w"),
                .height = u("100h"),
            },
        },
        @constCast(&[_]*GUI.GUIElement{
            // Main inventory
            try GUI.Container(
                .{
                    .id = "Bag",
                    .style = .{
                        .width = .{
                            .value = WIDTH_VW,
                            .unit = .vw,
                        },
                        .height = .{
                            .value = HEIGHT_VW,
                            .unit = .vw,
                        },
                        .top = u("50%"),
                        .left = u("41w"),
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.blue,
                        },
                    },
                },
                slots,
            ),
            // Equipped - Delete - Pages
            try GUI.Container(
                .{
                    .id = "equippedShower",
                    .style = .{
                        .width = .{
                            .value = SLOT_SIZE,
                            .unit = .vw,
                        },
                        .height = .{
                            .value = HEIGHT_VW + SLOT_SIZE + 1,
                            .unit = .vw,
                        },
                        .top = u("50%"),
                        .left = u("13w"),
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.green,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    try generateBtn(
                        "equipped_weapon",
                        "equipped_weapon_btn",
                        "equipped_weapon_shower",
                        0,
                        0,
                        0,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try generateBtn(
                        "equipped_amethyst",
                        "equipped_amethyst_btn",
                        "equipped_amethyst_shower",
                        0,
                        0,
                        1,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try generateBtn(
                        "equipped_ring",
                        "equipped_ring_btn",
                        "equipped_ring_shower",
                        0,
                        0,
                        2,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try generateBtn(
                        "equipped_brace",
                        "equipped_brace_btn",
                        "equipped_brace_shower",
                        0,
                        0,
                        3,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try generateBtn(
                        "delete_mode",
                        "delete_mode_btn",
                        "delete_mode_shower",
                        0,
                        0,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        (struct {
                            pub fn callback() anyerror!void {
                                delete_mode = !delete_mode;
                                try updateGUI();
                            }
                        }).callback,
                    ),
                    try generatePageBtn(
                        "page1",
                        "page_1_btn",
                        "Page 1",
                        0,
                        2,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try generatePageBtn(
                        "page2",
                        "page_2_btn",
                        "Page 2",
                        1,
                        4,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try generatePageBtn(
                        "page3",
                        "page_3_btn",
                        "Page 3",
                        2,
                        6,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                }),
            ),
            // Preview
            try GUI.Container(
                .{
                    .id = "item-preview",
                    .style = .{
                        .width = .{
                            .value = SLOT_SIZE * 4 + 3,
                            .unit = .vw,
                        },
                        .height = .{
                            .value = SLOT_SIZE * 7 + 6,
                            .unit = .vw,
                        },
                        .background = .{
                            .color = e.Color.red,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = 78,
                            .unit = .vw,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    try GUI.Container(
                        .{
                            .id = "preview-display",
                            .style = .{
                                .width = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .height = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .top = u("-50%"),
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1) - 0.5,
                                    .unit = .vw,
                                },
                                .background = .{
                                    .color = e.Color.blue,
                                    .image = "sprites/gui/item_slot_legendary.png",
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Empty(
                                .{
                                    .id = "preview-display-item",
                                    .style = .{
                                        .width = u("75%"),
                                        .height = u("75%"),
                                        .top = u("50%"),
                                        .left = u("50%"),
                                        .background = .{
                                            .image = "sprites/entity/player/weapons/gloves/left.png",
                                        },
                                        .rotation = 135,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                            ),
                        }),
                    ),
                    try GUI.Container(
                        .{
                            .id = "preview-level-container",
                            .style = .{
                                .width = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .height = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = -1 * SLOT_SIZE * 3.5 + 2.5,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = SLOT_SIZE * 1 + 1,
                                    .unit = .vw,
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .background = .{
                                    .color = e.Color.blue,
                                    .image = "sprites/gui/item_slot.png",
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Text(
                                .{
                                    .id = "preview-level-text",
                                    .style = .{
                                        .top = u("-28x"),
                                        .font = .{
                                            .size = 16,
                                        },
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "Level",
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-level-number",
                                    .style = .{
                                        .top = u("12x"),
                                        .font = .{
                                            .size = 48,
                                        },
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "90",
                            ),
                        }),
                    ),
                    try GUI.Text(
                        .{
                            .id = "preview-item-name",
                            .style = .{
                                .width = .{
                                    .value = 100,
                                    .unit = .percent,
                                },
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = -1 * SLOT_SIZE * 1 - 1,
                                    .unit = .vw,
                                },
                                // .left = .{
                                //     .value = SLOT_SIZE * 1 + 1,
                                //     .unit = .vw,
                                // },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .background = .{
                                    .image = "sprites/missingno.png",
                                },
                            },
                        },
                        "Item Name",
                    ),
                }),
            ),
        }),
    );

    const delete_button: *GUI.GUIElement = if (GUI.select("#delete_mode_shower")) |el| el else return;

    delete_button.options.style.background.image = "sprites/gui/delete_toggle.png";
    delete_button.options.style.translate = .{
        .x = .center,
        .y = .center,
    };
    delete_button.options.style.top = u("50%");
    delete_button.options.style.left = u("50%");
}

pub fn init() !void {
    _ = pickUpSort(conf.Item{
        .T = .weapon,
        .rarity = .legendary,
        .damage = 10,
        .weapon_projectile_scale = e.Vec2(64, 64),

        .icon = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
    });
    _ = pickUpSort(conf.Item{
        .T = .weapon,
        .rarity = .epic,
        .damage = 10,
        .weapon_projectile_scale = e.Vec2(64, 64),

        .icon = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
    });

    sortBag();
    try updateGUI();
    show();
}

pub fn update() !void {
    if (e.isKeyPressed(.key_i)) toggle();
    if (!e.input.ui_mode) return;

    if ((e.isMouseButtonPressed(.mouse_button_left) or
        e.isKeyPressed(.key_enter) or
        e.isKeyPressed(.key_backspace) or
        e.isKeyPressed(.key_space)) and
        delete_mode_last_frame)
    {
        delete_mode = false;
        try updateGUI();
    }

    if (e.isKeyPressed(.key_backspace) and !delete_mode_last_frame) {
        delete_mode = true;
        try updateGUI();
    }

    delete_mode_last_frame = delete_mode;
}

pub fn deinit() !void {
    e.ALLOCATOR.free(slots);
    e.ALLOCATOR.free(sorted_bag);
}
