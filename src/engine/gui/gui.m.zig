const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const entities = Import(.ecs);
const z = Import(.z);
const input = Import(.input);

pub const GUIElement = @import("GUIElement.zig");
pub const StyleSheet = @import("StyleSheet.zig");
pub const ButtonInterface = @import("ButtonInterface.zig");
pub const u = @import("Unit.zig").u;
pub const toUnit = @import("Unit.zig").toUnit;

pub const elements = struct {
    const T = GUIElement;
    const options: struct {
        max_size: usize = 8_000_000,
        max_entities: ?usize = null,
    } = .{
        .max_size = 8_000_000,
        .max_entities = 1024,
    };

    pub const TSize: comptime_int = @sizeOf(T);
    pub const MaxArraySize: comptime_int = @divTrunc(options.max_size, TSize);
    pub const ArraySize: comptime_int = if (options.max_entities) |max| @min(max, MaxArraySize) else MaxArraySize;
    pub var array: [ArraySize]?T = [_]?T{null} ** ArraySize;

    /// This will search for the next free *(value == null)*
    /// index in the array and return it.
    /// If there are no available indexes in the array and override is:
    /// - **false**: it will override the 0th address.
    /// - **true**: it will randomly return an address.
    pub fn searchNextIndex(override: bool) usize {
        for (array, 0..) |value, index| {
            if (index == 0) continue;
            if (value == null) return index;
        }

        // No null, everything is used...

        // This saves your ass 1 time
        if (!override) {
            array[0] = null;
            return 0;
        }

        const rIndex = std.crypto.random.uintLessThan(usize, ArraySize);

        if (array[rIndex]) |_| {
            free(rIndex);
        }

        array[rIndex] = null;
        return rIndex;
    }

    /// Uses the `searchNextIndex()` function to get an index
    /// and puts the value into it
    pub fn malloc(value: T) void {
        const index = searchNextIndex(true);
        array[index] = value;
    }

    /// Sets the value of the index to `null`
    pub fn free(index: usize) void {
        array[index] = null;
    }

    pub fn get(id: []const u8) ?*GUIElement {
        for (array, 0..) |item, index| {
            if (item == null) continue;
            if (std.mem.eql(u8, id, item.?.options.id)) return &(array[index].?);
        }
        return null;
    }

    pub fn freeWithFreeId(index: usize) void {
        const value = array[index];

        if (value == null) return;

        alloc.free(value.?.options.id);

        array[index] = null;
    }
};

pub var ButtonMatrix: [9][16]?ButtonInterface = undefined;
pub var keyboard_cursor_position = rl.Vector2.init(0, 0);

var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    ButtonMatrix = [_][16]?ButtonInterface{
        [_]?ButtonInterface{null} ** 16,
    } ** 9;
}

pub fn update() void {
    if (!input.ui_mode) return;

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
                        continue;
                    }

                    keyboard_cursor_position.x = @floatFromInt(x);
                    keyboard_cursor_position.y = @floatFromInt(y);

                    button.is_hovered = true;

                    if (rl.isMouseButtonPressed(.mouse_button_left)) {
                        btn.?.callback_fn() catch {};
                    }
                }
            }
        },

        // TODO: Jump to next button automatically
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

                if (rl.isKeyPressed(.key_space) or rl.isKeyPressed(.key_enter)) {
                    std.log.debug("kcp: {any}", .{keyboard_cursor_position});

                    btn.callback_fn() catch {};
                }
            }
        },
    }
}

pub fn deinit() void {
    for (elements.array, 0..) |element, index| {
        if (element == null) continue;

        if (element.?.children) |children| {
            children.deinit();
        }
        if (element.?.heap_id) {
            elements.freeWithFreeId(index);
            continue;
        }

        elements.free(index);
    }
}

pub fn select(selector: []const u8) ?*GUIElement {
    for (0..elements.array.len) |entry| {
        const value = elements.array[entry];

        if (value == null) continue;

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

pub fn clear() void {
    for (elements.array, 0..) |element, index| {
        if (element == null) continue;

        if (element.?.children) |children| {
            children.deinit();
        }
        if (element.?.heap_id) {
            elements.freeWithFreeId(index);
            continue;
        }

        elements.free(index);
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

    if (elements.get(options.id) != null) {
        std.log.warn("Data clobbering", .{});
    }

    elements.malloc(Parent);

    const el_ptr = elements.get(Parent.options.id).?;

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
        std.log.debug("lol", .{});
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
