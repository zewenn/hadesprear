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
    Elements.deinit();
}

pub fn Element(options: GUIElement.Options, children: []GUIElement) !*GUIElement {
    var childrn = std.ArrayList(GUIElement).init(alloc.*);
    for (children) |child| {
        try childrn.append(child);
    }

    var Parent = GUIElement{.options = options};
    Parent.children = childrn;
    
    try Elements.put(options.id, Parent);

    const el_ptr = Elements.getPtr(Parent.options.id).?;

    for (childrn.items) |child| {
        @constCast(&child).parent = el_ptr;
    }

    return el_ptr;
}
