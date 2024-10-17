const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const entities = @import("../engine.m.zig").entities;
const zlib = @import("../z/z.m.zig");
const input = @import("../input.m.zig");

const loadusize = @import("../engine.m.zig").loadusize;

pub const GUIElement = @import("GUIElement.zig");
pub const StyleSheet = @import("StyleSheet.zig");
pub const ButtonInterface = @import("ButtonInterface.zig");
pub const u = @import("Unit.zig").u;
pub const toUnit = @import("Unit.zig").toUnit;

pub const manager = zlib.HeapManager(GUIElement, (struct {
    pub fn callback(_: Allocator, item: *GUIElement) !void {
        if (!item.heap_id) return;
        alloc.free(item.options.id);
    }
}).callback);

pub const BUTTON_MATRIX_WIDTH: usize = 16;
pub const BUTTON_MATRIX_HEIGHT: usize = 10;
pub const BUTTON_MATRIX_DEPTH: usize = 6;

pub const ButtonMatrix2D = [BUTTON_MATRIX_HEIGHT][BUTTON_MATRIX_WIDTH]?ButtonInterface;
pub const ButtonMatrix3D = [BUTTON_MATRIX_DEPTH]ButtonMatrix2D;

pub const BM3D = struct {
    pub var matrix: ButtonMatrix3D = undefined;
    pub var current_layer: usize = 0;

    pub fn clear() void {
        matrix = [_][BUTTON_MATRIX_HEIGHT][BUTTON_MATRIX_WIDTH]?ButtonInterface{
            [_][BUTTON_MATRIX_WIDTH]?ButtonInterface{
                [_]?ButtonInterface{null} ** BUTTON_MATRIX_WIDTH,
            } ** BUTTON_MATRIX_HEIGHT,
        } ** BUTTON_MATRIX_DEPTH;
    }

    /// # NEVER USE 0 AS A LAYER GOT IT?
    /// Btw you cannot set it to 0 this way, just by using `resetLayer()`
    /// If you try it will be clamped to 1
    pub fn setLayer(to: anytype) void {
        const final_to = zlib.math.clamp(usize, loadusize(to), 1, 5);
        current_layer = loadusize(final_to);
    }

    pub fn incrementLayer(by: anytype) void {
        const clamped = zlib.math.clamp(i32, by, -5, 5);
        const calculated: i32 = @as(i32, @intCast(current_layer)) + clamped;
        const calculated_clamped = zlib.math.clamp(i32, calculated, 1, 5);

        setLayer(calculated_clamped);
    }

    pub fn resetLayer() void {
        current_layer = 0;
    }

    pub fn getLayer(layer: anytype) ButtonMatrix2D {
        return matrix[loadusize(layer)];
    }

    pub fn getCurrentLayer() ButtonMatrix2D {
        return matrix[current_layer];
    }

    fn set(plane: anytype, row: anytype, col: anytype, to: ButtonInterface) void {
        const z = loadusize(plane);
        const y = loadusize(row);
        const x = loadusize(col);

        matrix[z][y][x] = to;
    }

    fn get(plane: anytype, row: anytype, col: anytype) ?ButtonInterface {
        const z = loadusize(plane);
        const y = loadusize(row);
        const x = loadusize(col);

        return matrix[z][y][x];
    }

    fn getPtr(plane: anytype, row: anytype, col: anytype) ?*ButtonInterface {
        const z = loadusize(plane);
        const y = loadusize(row);
        const x = loadusize(col);

        if (matrix[z][y][x] == null) return null;

        return &(matrix[z][y][x].?);
    }
};

pub var hovered_button: ?*GUIElement = null;
pub var keyboard_cursor_position = rl.Vector2.init(0, 0);

var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;
    manager.init(alloc.*);

    BM3D.clear();
}

pub fn update() void {
    if (!input.ui_mode) return;
    hovered_button = null;

    switch (input.input_mode) {
        .KeyboardAndMouse => {
            for (BM3D.getCurrentLayer(), 0..) |row, y| {
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
            for (BM3D.getCurrentLayer()) |row| {
                for (row) |btn| {
                    if (btn) |button| button.element_ptr.?.is_hovered = false;
                }
            }

            var towards: ?zlib.arrays.Direction = null;

            if (rl.isKeyPressed(.key_left) and keyboard_cursor_position.x > 0)
                towards = .left;

            if (rl.isKeyPressed(.key_right) and keyboard_cursor_position.x < 15)
                towards = .right;

            if (rl.isKeyPressed(.key_up) and keyboard_cursor_position.y > 0)
                towards = .up;

            if (rl.isKeyPressed(.key_down) and keyboard_cursor_position.y < 8)
                towards = .down;

            if (towards) |direction| {
                const next_tuple = zlib.arrays.searchMatrixForNext(
                    ButtonInterface,
                    BUTTON_MATRIX_WIDTH,
                    BUTTON_MATRIX_HEIGHT,
                    BM3D.getCurrentLayer(),
                    direction,
                    @intFromFloat(keyboard_cursor_position.x),
                    @intFromFloat(keyboard_cursor_position.y),
                );

                keyboard_cursor_position.x = @floatFromInt(next_tuple[0]);
                keyboard_cursor_position.y = @floatFromInt(next_tuple[1]);
            }
            const button = BM3D.get(
                BM3D.current_layer,
                keyboard_cursor_position.y,
                keyboard_cursor_position.x,
            );

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
        if (!zlib.eql(element, item)) continue;

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
                if (zlib.arrays.StringEqual(value.options.id, selector[1..])) {
                    return value;
                }
            },
            else => return null,
        }
    }
    return null;
}

pub fn assertSelect(selector: []const u8) *GUIElement {
    return if (select(selector)) |el| el else zlib.panicWithArgs(
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

    BM3D.clear();
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
    BM3D.set(
        BM3D.current_layer,
        grid_pos.y,
        grid_pos.x,
        ButtonInterface{
            .button_id = options.id,
            .callback_fn = callback,
        },
    );

    const len = std.mem.indexOfSentinel(u8, 0, text);

    var O = options;
    if (zlib.eql(O.hover, StyleSheet{})) {
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
    element.button_interface_ptr = BM3D.getPtr(BM3D.current_layer, grid_pos.y, grid_pos.x);

    element.button_interface_ptr.?.element_ptr = element;

    return element;
}

pub fn Body(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !void {
    _ = try Element(options, children, content);
}
