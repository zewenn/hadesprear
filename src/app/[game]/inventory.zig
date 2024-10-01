const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const GUI = e.GUI;

const u = GUI.u;
const toUnit = GUI.toUnit;

const bag_pages: comptime_int = 3;
const bag_page_rows: comptime_int = 4;
const bag_page_cols: comptime_int = 9;
const bag_size: comptime_int = bag_pages * bag_page_rows * bag_page_cols;

pub const Item = conf.Item;

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
var bag_element: *GUI.GUIElement = undefined;
var slots: []*GUI.GUIElement = undefined;

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

fn generateSlots() !void {
    slots = try e.ALLOCATOR.alloc(*GUI.GUIElement, bag_page_rows * bag_page_cols);
    std.log.debug("slots.len: {d}", .{slots.len});

    inline for (0..bag_page_rows) |row| {
        inline for (0..bag_page_cols) |col| {
            const id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-{d}-{d}",
                .{ row, col },
            );
            std.log.debug("id created", .{});

            slots[row * bag_page_cols + col] = try GUI.Container(.{
                .id = id,
                .style = .{
                    .width = u("9%"),
                    .height = u("27%"),
                    .left = .{
                        .value = @as(f32, @floatFromInt(col)) * 10,
                        .unit = .percent,
                    },
                    .top = .{
                        .value = @as(f32, @floatFromInt(row)) * 30,
                        .unit = .percent,
                    },
                    .background = .{
                        .color = e.Color.blue,
                    },
                },
            }, @constCast(&[_]*GUI.GUIElement{}));
            std.log.debug("x created", .{});

            slots[row * bag_page_cols + col].heap_id = true;
            std.log.debug("slot added", .{});
            std.log.info("done: {d}", .{row * bag_page_cols + col});
        }
    }
}

pub fn awake() !void {
    e.input.ui_mode = true;

    sorted_bag = try e.ALLOCATOR.alloc(*?conf.Item, bag_size);

    for (0..bag.len) |index| {
        sorted_bag[index] = &(bag[index]);
    }

    sortBag();

    std.log.debug("asdasdassssssssd", .{});

    slots = try e.ALLOCATOR.alloc(*GUI.GUIElement, bag_page_rows * bag_page_cols);
    std.log.debug("slots.len: {d}", .{slots.len});

    inline for (0..bag_page_rows) |row| {
        inline for (0..bag_page_cols) |col| {
            const id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-{d}-{d}",
                .{ row, col },
            );
            std.log.debug("id created: {s}", .{id});

            slots[row * bag_page_cols + col] = try GUI.Container(.{
                .id = id,
                .style = .{
                    .width = u("9%"),
                    .height = u("27%"),
                    .left = .{
                        .value = @as(f32, @floatFromInt(col)) * 10,
                        .unit = .percent,
                    },
                    .top = .{
                        .value = @as(f32, @floatFromInt(row)) * 30,
                        .unit = .percent,
                    },
                    .background = .{
                        .color = e.Color.blue,
                    },
                },
            }, @constCast(&[_]*GUI.GUIElement{}));
            std.log.debug("x created", .{});

            slots[row * bag_page_cols + col].heap_id = true;
            std.log.debug("slot added", .{});
            std.log.info("done: {d}", .{row * bag_page_cols + col});

            if (row * bag_page_cols + col == 6) {
                std.log.info("so far: {any}", .{slots[2]});
            }

            std.log.info("so far: {any}", .{slots[0 .. row * bag_page_cols + col]});
        }
    }

    std.log.debug("slots: {any}", .{slots});

    for (slots) |slot| {
        std.log.debug("id: {any}", .{slot.options.style});
    }

    INVENTORY_GUI = try GUI.Container(
        .{
            .id = "InventoryParentBackground",
            .style = .{
                .background = .{
                    .color = e.Color.init(0, 0, 0, 20),
                },
                .width = u("100w"),
                .height = u("100h"),
            },
        },
        @constCast(&[_]*GUI.GUIElement{
            try GUI.Container(.{
                .id = "Bag",
                .style = .{
                    .width = u("70w"),
                    .height = u("23w"),
                    .top = u("50%"),
                    .left = u("50%"),
                    .translate = .{
                        .x = .center,
                        .y = .center,
                    },
                    .background = .{
                        .color = e.Color.red,
                    },
                },
            }, slots),
        }),
    );

    std.log.debug("asdasdasd", .{});

    // try GUI.Body(
    //     .{
    //         .id = "body",
    //     },
    //     @constCast(&[_]*GUI.GUIElement{
    //         //
    //         INVENTORY_GUI,
    //     }),
    //     "",
    // );
}

pub fn init() !void {
    _ = pickUpSort(conf.Item{
        .T = .weapon,
        .damage = 10,
        .weapon_projectile_scale = e.Vec2(64, 64),

        .icon = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
    });
    _ = pickUpSort(conf.Item{
        .T = .weapon,
        .damage = 10,
        .weapon_projectile_scale = e.Vec2(64, 64),

        .icon = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
    });

    bag[0] = null;

    std.log.debug("Sorted bag: ", .{});

    for (sorted_bag, 0..) |it, index| {
        std.log.debug("[{d}] Value: {any}", .{ index, it.* });
    }

    sortBag();

    std.log.debug("\nSorted bag: ", .{});

    for (sorted_bag, 0..) |it, index| {
        std.log.debug("[{d}] Value: {any}", .{ index, it.* });
    }
}

pub fn update() !void {}

pub fn deinit() !void {
    e.ALLOCATOR.free(slots);
    e.ALLOCATOR.free(sorted_bag);
}