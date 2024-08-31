const std = @import("std");
const rl = @import("raylib");
const Allocator = @import("std").mem.Allocator;
const z = @import("./z/z.zig");

pub const Image = rl.Image;
pub const Sound = rl.Sound;
pub const Wave = rl.Wave;

const filenames = @import("../.temp/filenames.zig").Filenames;
var files: [filenames.len][]const u8 = undefined;

var image_map: std.StringHashMap(Image) = undefined;
var wave_map: std.StringHashMap(Wave) = undefined;
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
    z.dprint("[MODULE] ASSETS: LOADING...", .{});
    alloc = allocator;
    image_map = std.StringHashMap(Image).init(alloc.*);
    wave_map = std.StringHashMap(Wave).init(alloc.*);

    // const testimg = try Image.loadFromMemory(files[0], 4);
    // std.debug.print("{any}", .{getPixelData(&testimg, .{ .x = 0, .y = 0 })});

    for (filenames, files) |name, data| {
        if (z.arrays.StringEqual(name[name.len - 3 .. name.len], "png")) {
            const img = rl.loadImageFromMemory(".png", data);
            try image_map.put(name, img);
        }
        if (z.arrays.StringEqual(name[name.len - 3 .. name.len], "mp3")) {
            const wave = rl.loadWaveFromMemory(".mp3", data);
            try wave_map.put(name, wave);
        }
        if (z.arrays.StringEqual(name[name.len - 3 .. name.len], "wav")) {
            const wave = rl.loadWaveFromMemory(".wav", data);
            try wave_map.put(name, wave);
        }
    }
    z.dprint("[MODULE] ASSETS: LOADED", .{});
}

/// Caller owns the returned memory!
pub fn get(T: type, id: []const u8) ?T {
    if (T == rl.Image) {
        if (image_map.getPtr(id)) |img| {
            return rl.imageCopy(img.*);
        }
        return null;
    }
    if (T == rl.Sound) {
        if (wave_map.get(id)) |wav| {
            const sound = rl.loadSoundFromWave(wav);
            return sound;
        }
        return null;
    }
    z.dprint("ASSETS: File type not supported", .{});
    return null;
}

pub fn deinit() void {
    var kIt = image_map.keyIterator();
    while (kIt.next()) |key| {
        if (image_map.get(key.*)) |image| {
            rl.unloadImage(image);
        }
    }
    image_map.deinit();

    var wkIt = wave_map.keyIterator();
    while (wkIt.next()) |key| {
        if (wave_map.get(key.*)) |wave| {
            rl.unloadWave(wave);
        }
    }
    wave_map.deinit();
}
