const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const ecs = Import(.ecs);
const z = Import(.z);
const input = Import(.input);

pub const GUIElement = @import("GUIElement.zig");
pub const StyleSheet = @import("StyleSheet.zig");
pub const ButtonInterface = @import("ButtonInterface.zig");
pub const u = @import("Unit.zig").u;

pub var Elements: std.StringHashMap(GUIElement) = undefined;
pub var ButtonMatrix: [9][16]?ButtonInterface = undefined;
pub var keyboard_cursor_position = rl.Vector2.init(0, 0);

var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    Elements = std.StringHashMap(GUIElement).init(allocator.*);

    ButtonMatrix = [_][16]?ButtonInterface{
        [_]?ButtonInterface{null} ** 16,
    } ** 9;
}

pub fn update() void {
    if (!input.ui_mode) return;

    switch (input.input_mode) {
        .KeyboardAndMouse => {
            row_loop: for (ButtonMatrix) |row| {
                for (row) |btn| {
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

                    if (!mouse_rect.checkCollision(button_rect)) continue;

                    if (rl.isMouseButtonPressed(.mouse_button_left)) {
                        std.log.debug("btn transform: {any}", .{button.transform});
                        std.log.debug("btn rect: {any}", .{button_rect});
                        btn.?.callback_fn() catch {};
                    }

                    break :row_loop;
                }
            }
        },

        // TODO: Jump to next button automatically
        .Keyboard => {
            if (rl.isKeyPressed(.key_left) and keyboard_cursor_position.x > 0)
                keyboard_cursor_position.x -= 1;

            if (rl.isKeyPressed(.key_right) and keyboard_cursor_position.x < 15)
                keyboard_cursor_position.x += 1;

            if (rl.isKeyPressed(.key_up) and keyboard_cursor_position.y > 0)
                keyboard_cursor_position.y -= 1;

            if (rl.isKeyPressed(.key_down) and keyboard_cursor_position.y < 8)
                keyboard_cursor_position.y += 1;

            if (rl.isKeyPressed(.key_space) or rl.isKeyPressed(.key_enter)) {
                std.log.debug("kcp: {any}", .{keyboard_cursor_position});
                const button = ButtonMatrix[@intFromFloat(keyboard_cursor_position.y)][@intFromFloat(keyboard_cursor_position.x)];

                if (button) |btn| {
                    btn.callback_fn() catch {};
                }
            }
        },
    }
}

pub fn deinit() void {
    var elIt = Elements.iterator();
    while (elIt.next()) |entry| {
        if (entry.value_ptr.children) |children| {
            children.deinit();
        }
    }

    Elements.deinit();
}

pub fn select(selector: []const u8) ?*GUIElement {
    var it = Elements.iterator();

    while (it.next()) |entry| {
        const value = entry.value_ptr;

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
        }
        return null;
    }
}

pub fn clear() void {
    var elIt = Elements.iterator();
    while (elIt.next()) |entry| {
        if (entry.value_ptr.children) |children| {
            children.deinit();
        }
    }

    Elements.clearAndFree();
}

pub fn Element(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !*GUIElement {
    var childrn = std.ArrayList(*GUIElement).init(alloc.*);

    for (children) |child| {
        try childrn.append(child);
    }

    var Parent = GUIElement{ .options = options };
    Parent.children = childrn;
    Parent.contents = content;

    try Elements.put(options.id, Parent);

    const el_ptr = Elements.getPtr(Parent.options.id).?;

    for (childrn.items) |child| {
        child.parent = el_ptr;
    }

    return el_ptr;
}

pub fn Container(options: GUIElement.Options, children: []*GUIElement) !*GUIElement {
    return try Element(options, children, "");
}

pub fn TextElement(options: GUIElement.Options, text: [*:0]const u8) !*GUIElement {
    var el = try Element(options, &[_]*GUIElement{}, text);

    const len = std.mem.indexOfSentinel(u8, 0, text);

    el.options.style.width = .{ .value = (@as(f32, @floatFromInt(len)) * el.options.style.font.size), .unit = .px };
    el.options.style.height = .{ .value = el.options.style.font.size, .unit = .px };

    return el;
}

pub fn Button(options: GUIElement.Options, text: [*:0]const u8, grid_pos: rl.Vector2, callback: *const fn () anyerror!void) !*GUIElement {
    ButtonMatrix[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)] = ButtonInterface{
        .button_id = options.id,
        .callback_fn = callback,
    };

    var element = try TextElement(options, text);
    element.is_button = true;
    element.button_interface_ptr = &ButtonMatrix[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)].?;

    ButtonMatrix[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)].?.element_ptr = element;

    return element;
}

pub fn UI(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !void {
    _ = try Element(options, children, content);
}
