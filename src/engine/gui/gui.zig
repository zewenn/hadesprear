const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");
const ecs = @import("../ecs/ecs.zig");

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
    return try Element(options, &[_]*GUIElement{}, text);
}

pub fn UI(options: GUIElement.Options, children: []*GUIElement, content: [*:0]const u8) !void {
    _ = Element(options, children, content);
}
