const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const ecs = Import(.ecs);
const z = Import(.z);

pub const GUIElement = @import("GUIElement.zig");
pub const StyleSheet = @import("StyleSheet.zig");

pub var Elements: std.StringHashMap(GUIElement) = undefined;

var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    Elements = std.StringHashMap(GUIElement).init(allocator.*);
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

pub fn UI(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !void {
    _ = try Element(options, children, content);
}
