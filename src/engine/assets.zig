const std = @import("std");
const rl = @import("raylib");
const Allocator = @import("std").mem.Allocator;
const z = @import("./z/z.zig");

pub const Image = rl.Image;

const filenames = @import("../.temp/filenames.zig").Filenames;
var files: [filenames.len][]const u8 = undefined;

var image_map: std.StringHashMap(Image) = undefined;
var alloc: *Allocator = undefined;

pub inline fn compile() !void {
    var content_arr: std.ArrayListAligned([]const u8, null) = undefined;
    content_arr = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer content_arr.deinit();

    inline for (filenames) |filename| {
        try content_arr.append(@embedFile("../assets/" ++ filename));
    }

    const x2 = content_arr.toOwnedSlice() catch unreachable;
    defer std.heap.page_allocator.free(x2);

    std.mem.copyForwards([]const u8, &files, x2);
}

pub fn init(allocator: *Allocator) !void {
    alloc = allocator;
    image_map = std.StringHashMap(Image).init(allocator.*);

    z.dprint("image_map: 0x{x}", .{@intFromPtr(&image_map)});

    // const testimg = try Image.loadFromMemory(files[0], 4);
    // std.debug.print("{any}", .{getPixelData(&testimg, .{ .x = 0, .y = 0 })});

    for (filenames, files) |name, data| {
        const img = rl.loadImageFromMemory(".png", data);
        
        try image_map.put(name, img);
    }
}

pub fn get(id: []const u8) ?Image {
    return image_map.get(id);
}

pub fn deinit() void {
    image_map.deinit();
}
