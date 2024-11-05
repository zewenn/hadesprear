const std = @import("std");
const rl = @import("raylib");
const Allocator = @import("std").mem.Allocator;
const z = @import("./z/z.m.zig");

pub const Image = rl.Image;
pub const Sound = rl.Sound;
pub const Wave = rl.Wave;
pub const Font = rl.Font;

const json = std.json;

const saveloader = @import("saveloader.zig");

const filenames = @import("../.temp/filenames.zig").Filenames;
var files: [filenames.len][]const u8 = undefined;

var image_map: std.StringHashMap(Image) = undefined;
var wave_map: std.StringHashMap(Wave) = undefined;
var font_map: std.StringHashMap(Font) = undefined;
var json_map: std.StringHashMap([]const u8) = undefined;

var alloc: Allocator = undefined;

pub inline fn compile(allocator: Allocator) !void {
    var content_arr: std.ArrayListAligned([]const u8, null) = undefined;
    content_arr = std.ArrayList([]const u8).init(allocator);
    defer content_arr.deinit();

    inline for (filenames) |filename| {
        try content_arr.append(@embedFile("../assets/" ++ filename));
    }

    const x2 = content_arr.toOwnedSlice() catch unreachable;
    defer allocator.free(x2);

    std.mem.copyForwards([]const u8, &files, x2);
}

pub fn init(allocator: Allocator) !void {
    std.log.info("ASSETS: Loading...", .{});
    alloc = allocator;
    image_map = std.StringHashMap(Image).init(alloc);
    wave_map = std.StringHashMap(Wave).init(alloc);
    font_map = std.StringHashMap(Font).init(alloc);
    json_map = std.StringHashMap([]const u8).init(alloc);

    // const testimg = try Image.loadFromMemory(files[0], 4);
    // std.debug.print("{any}", .{getPixelData(&testimg, .{ .x = 0, .y = 0 })});

    for (filenames, files) |name, data| {
        // Images
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "png")) {
            const img = rl.loadImageFromMemory(".png", data);
            try image_map.put(name, img);
        }

        // Audio
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "mp3")) {
            const wave = rl.loadWaveFromMemory(".mp3", data);
            try wave_map.put(name, wave);
        }
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "wav")) {
            const wave = rl.loadWaveFromMemory(".wav", data);
            try wave_map.put(name, wave);
        }

        if (std.mem.eql(u8, name[name.len - 4 .. name.len], "json")) {
            try json_map.put(name, data);
        }

        // Fonts
        if (std.mem.eql(u8, name[name.len - 3 .. name.len], "ttf")) {
            var fontChars = [_]i32{
                48, 49, 50, 51, 52, 53, 54, 55, 56, 57, // 0-9
                65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, // A-Z
                97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, // a-z
                33, 34, 35, 36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  58,  59,  60,  61,  62,  63,  64,  91,  92,  93,  94,
                95, 96, 123, 124, 125, 126, // !, ", #, $, %, &, ', (, ), *, +, ,, -, ., /, :, ;, <, =, >, ?, @, [, \, ], ^, _, `, {, |, }, ~
            };

            const font = rl.loadFontFromMemory(".ttf", data, 256, &fontChars);
            try font_map.put(name, font);
        }
    }
    std.log.info("ASSETS: Loaded", .{});
}

/// Caller owns the returned memory!
pub fn get(T: type, id: []const u8) ?T {
    if (T == rl.Image) {
        if (!image_map.contains(id)) {
            std.log.err("Image does not exist: {s}", .{id});
            @panic("Image doen't exist");
        }

        if (image_map.getPtr(id)) |img| {
            return rl.imageCopy(img.*);
        }
        return null;
    }
    if (T == rl.Sound) {
        if (!wave_map.contains(id)) @panic("Wave doen't exist");

        if (wave_map.get(id)) |wav| {
            const sound = rl.loadSoundFromWave(wav);
            return sound;
        }
        return null;
    }
    if (T == rl.Font) {
        if (!font_map.contains(id)) @panic("Font doen't exist");
        return font_map.get(id);
    }
    std.log.err("ASSETS: File type not supported", .{});
    return null;
}

pub fn getJson(T: type, allocator: Allocator, id: []const u8) !T {
    if (!json_map.contains(id)) @panic("JSON doen't exist");

    const json_contents = json_map.get(id).?;

    return try json.parseFromSliceLeaky(T, allocator, json_contents, .{ .allocate = .alloc_always });
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

    var fIt = font_map.keyIterator();
    while (fIt.next()) |key| {
        if (font_map.get(key.*)) |font| {
            rl.unloadFont(font);
        }
    }
    font_map.deinit();

    json_map.deinit();
}
