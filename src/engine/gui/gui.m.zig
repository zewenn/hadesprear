const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const entities = @import("../engine.m.zig").entities;
const z = @import("../z/z.m.zig");
const input = @import("../input.m.zig");

pub const GUIElement = @import("GUIElement.zig");
pub const StyleSheet = @import("StyleSheet.zig");
pub const ButtonInterface = @import("ButtonInterface.zig");
pub const u = @import("Unit.zig").u;
pub const toUnit = @import("Unit.zig").toUnit;

pub const manager = z.HeapManager(GUIElement, (struct {
    pub fn callback(_: Allocator, item: *GUIElement) !void {
        if (!item.heap_id) return;
        alloc.free(item.options.id);
    }
}).callback);

pub var ButtonMatrix: [9][16]?ButtonInterface = undefined;
pub var hovered_button: ?*GUIElement = null;
pub var keyboard_cursor_position = rl.Vector2.init(0, 0);

var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;
    manager.init(alloc.*);

    ButtonMatrix = [_][16]?ButtonInterface{
        [_]?ButtonInterface{null} ** 16,
    } ** 9;
}

pub fn update() void {
    if (!input.ui_mode) return;
    hovered_button = null;

    switch (input.input_mode) {
        .KeyboardAndMouse => {
            for (ButtonMatrix, 0..) |row, y| {
                for (row, 0..) |btn, x| {
                    if (btn == null) continue;

                    const button = btn.?.element_ptr.?;
                    if (button.transform == null) _ = button.calculateTransform();

                    const button_rect = button.transform.?.getRect();
                    const mouse_rect = rl.Rectangle.init(
                        input.mouse_position.x - 5,
                        input.mouse_position.y - 5,
                        5,
                        5,
                    );

                    if (!mouse_rect.checkCollision(button_rect)) {
                        button.is_hovered = false;
                        // hovered_button = null;
                        continue;
                    }

                    keyboard_cursor_position.x = @floatFromInt(x);
                    keyboard_cursor_position.y = @floatFromInt(y);

                    button.is_hovered = true;
                    hovered_button = button;

                    if (rl.isMouseButtonPressed(.mouse_button_left)) {
                        btn.?.callback_fn() catch {};
                    }
                }
            }
        },

        .Keyboard => {
            for (ButtonMatrix) |row| {
                for (row) |btn| {
                    if (btn) |button| button.element_ptr.?.is_hovered = false;
                }
            }

            var towards: ?z.arrays.Direction = null;

            if (rl.isKeyPressed(.key_left) and keyboard_cursor_position.x > 0)
                towards = .left;

            if (rl.isKeyPressed(.key_right) and keyboard_cursor_position.x < 15)
                towards = .right;

            if (rl.isKeyPressed(.key_up) and keyboard_cursor_position.y > 0)
                towards = .up;

            if (rl.isKeyPressed(.key_down) and keyboard_cursor_position.y < 8)
                towards = .down;

            if (towards) |direction| {
                const next_tuple = z.arrays.SearchMatrixForNext(
                    ButtonInterface,
                    16,
                    9,
                    ButtonMatrix,
                    direction,
                    @intFromFloat(keyboard_cursor_position.x),
                    @intFromFloat(keyboard_cursor_position.y),
                );

                keyboard_cursor_position.x = @floatFromInt(next_tuple[0]);
                keyboard_cursor_position.y = @floatFromInt(next_tuple[1]);
            }
            const button = ButtonMatrix[@intFromFloat(keyboard_cursor_position.y)][@intFromFloat(keyboard_cursor_position.x)];

            if (button) |btn| {
                btn.element_ptr.?.is_hovered = true;
                hovered_button = btn.element_ptr.?;

                if (rl.isKeyPressed(.key_space) or rl.isKeyPressed(.key_enter)) {
                    btn.callback_fn() catch {};
                }
            }
        },
    }
}

pub fn remove(element: *GUIElement) !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        if (!z.eql(element, item)) continue;

        manager.removeFreeId(item);
    }
}

pub fn deinit() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        if (item.children) |children| {
            children.deinit();
        }

        manager.removeFreeId(item);
    }
    manager.deinit();
}

pub fn select(selector: []const u8) ?*GUIElement {
    const items = manager.items() catch return Err: {
        std.log.err("FAILED TO GET MANAGER ITEMS IN GUI/SELECT!", .{});
        break :Err null;
    };
    defer manager.alloc.free(items);

    for (items) |value| {
        switch (selector[0]) {
            '.' => {
                // Class based search
                if (std.mem.containsAtLeast(
                    u8,
                    value.options.class,
                    1,
                    selector[1..],
                )) {
                    return value;
                }
            },
            '#' => {
                // ID based search
                if (z.arrays.StringEqual(value.options.id, selector[1..])) {
                    return value;
                }
            },
            else => return null,
        }
    }
    return null;
}

pub fn assertSelect(selector: []const u8) *GUIElement {
    return if (select(selector)) |el| el else z.panicWithArgs(
        "FATAL Element couldn't be found: {s}",
        .{selector},
    );
}

pub fn clear() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        if (item.children) |children| {
            children.deinit();
        }
        manager.removeFreeId(item);
    }

    ButtonMatrix = [_][16]?ButtonInterface{
        [_]?ButtonInterface{null} ** 16,
    } ** 9;
}

pub fn Element(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !*GUIElement {
    var childrn = std.ArrayList(*GUIElement).init(alloc.*);

    for (children) |child| {
        try childrn.append(child);
    }

    var Parent = GUIElement{ .options = options };
    Parent.children = childrn;
    Parent.contents = content;

    try manager.append(Parent);

    const getFMT = try std.fmt.allocPrint(alloc.*, "#{s}", .{Parent.options.id});
    defer alloc.free(getFMT);

    const el_ptr = select(getFMT).?;

    for (childrn.items) |child| {
        if (child.options.style.z_index == 0)
            child.options.style.z_index = Parent.options.style.z_index;
        child.parent = el_ptr;
    }

    return el_ptr;
}

pub fn Container(options: GUIElement.Options, children: []*GUIElement) !*GUIElement {
    return try Element(options, children, "");
}

pub fn Empty(options: GUIElement.Options) !*GUIElement {
    return try Element(options, &[_]*GUIElement{}, "");
}

pub fn Text(options: GUIElement.Options, text: [*:0]const u8) !*GUIElement {
    var el = try Element(options, &[_]*GUIElement{}, text);

    const len = std.mem.indexOfSentinel(u8, 0, text);

    if (options.style.width.value == 64 and options.style.height.value == 64) {
        el.options.style.width = .{ .value = (@as(f32, @floatFromInt(len)) * el.options.style.font.size), .unit = .px };
        el.options.style.height = .{ .value = el.options.style.font.size, .unit = .px };
    }

    return el;
}

pub fn Button(options: GUIElement.Options, text: [*:0]const u8, grid_pos: rl.Vector2, callback: *const fn () anyerror!void) !*GUIElement {
    ButtonMatrix[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)] = ButtonInterface{
        .button_id = options.id,
        .callback_fn = callback,
    };

    const len = std.mem.indexOfSentinel(u8, 0, text);

    var O = options;
    if (z.eql(O.hover, StyleSheet{})) {
        O.hover = StyleSheet{
            .font = .{
                .size = O.style.font.size + 1,
            },
        };
    }

    if (O.style.width.value == 64 and O.style.height.value == 64) {
        O.hover.width = .{
            .value = (@as(f32, @floatFromInt(len)) * (O.hover.font.size)),
            .unit = .px,
        };
        O.hover.height = .{
            .value = O.hover.font.size,
            .unit = .px,
        };
    }

    var element = try Text(O, text);
    element.is_button = true;
    element.button_interface_ptr = &ButtonMatrix[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)].?;

    ButtonMatrix[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)].?.element_ptr = element;

    return element;
}

pub fn Body(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !void {
    _ = try Element(options, children, content);
}
