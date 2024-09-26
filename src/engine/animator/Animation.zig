const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const Keyframe = @import("Keyframe.zig");
const Number = @import("interpolation.zig").Number;

const time = Import(.time);
const z = Import(.z);

const Self = @This();

const Modes = enum {
    forwards,
    backwards,
};

id: []const u8,
timing_fn: *const fn (Number, Number, Number) Number,
keyframes: std.AutoHashMap(u8, Keyframe),

transition_time: Number,

transition_time_ms_per_kf: f64 = 0,
last_keyframe_at: f64 = 0,
next_keyframe_at: f64 = 0,

playing: bool = false,
loop: bool = false,
mode: Modes = .forwards,

current_frame: u8 = 0,
keys: std.ArrayList(u8),
keys_slice: ?[]u8 = null,

alloc: *Allocator,

pub fn init(
    allocator: *Allocator,
    id: []const u8,
    timing_fn: *const fn (Number, Number, Number) Number,
    transition_time: Number,
) Self {
    return Self{
        .id = id,
        .timing_fn = timing_fn,
        .alloc = allocator,
        .keyframes = std.AutoHashMap(u8, Keyframe).init(allocator.*),
        .keys = std.ArrayList(u8).init(allocator.*),
        .transition_time = transition_time,
    };
}

fn forwardsComp(_: void, a: u8, b: u8) bool {
    return a < b;
}
fn backwardsComp(_: void, a: u8, b: u8) bool {
    return b > a;
}

pub fn chain(self: *Self, percent: u8, kf: Keyframe) void {
    self.keyframes.put(percent, kf) catch z.panic("Couldn't add key-keyframe pair");
    self.keys.append(percent) catch z.panic("Couldn't add key to keylist");

    var keys_clone = self.keys.clone() catch unreachable;
    defer keys_clone.deinit();

    if (self.keys_slice) |slice| {
        self.alloc.free(slice);
    }
    self.keys_slice = keys_clone.toOwnedSlice() catch unreachable;

    switch (self.mode) {
        .forwards => std.sort.insertion(
            u8,
            self.keys_slice.?,
            {},
            std.sort.asc(u8),
        ),
        .backwards => std.sort.insertion(
            u8,
            self.keys_slice.?,
            {},
            std.sort.desc(u8),
        ),
    }

    self.transition_time_ms_per_kf = @as(
        f64,
        @floatCast(self.transition_time),
    ) / @as(
        f64,
        @floatFromInt(self.keys_slice.?.len - 1),
    );
}

pub fn deinit(self: *Self) void {
    if (self.keys_slice) |slice| {
        self.alloc.free(slice);
    }
    self.keyframes.deinit();
    self.keys.deinit();
}

pub fn getNext(self: *Self) ?Keyframe {
    if (self.keys_slice.?.len <= self.current_frame + 1) return null;

    const key = self.keys_slice.?[self.current_frame + 1];
    return self.keyframes.get(key);
}

pub fn getCurrent(self: *Self) ?Keyframe {
    if (self.keys_slice.?.len <= self.current_frame) return null;

    const key = self.keys_slice.?[self.current_frame];
    return self.keyframes.get(key);
}

pub fn next(self: *Self) void {
    self.current_frame += 1;

    if (self.keys_slice.?.len <= self.current_frame) {
        if (self.loop) {
            self.current_frame = 0;
            return;
        }
        self.current_frame = @as(u8, @intCast(self.keys_slice.?.len)) - 1;
        self.playing = false;
    }
}

pub fn interpolateKeyframes(self: *Self, kf1: Keyframe, kf2: Keyframe, percent: Number) Keyframe {
    var new_kf = Keyframe{};

    if (kf1.x) |v1| {
        if (kf2.x) |v2| {
            new_kf.x = self.timing_fn(v1, v2, percent);
        }
    }

    if (kf1.y) |v1| {
        if (kf2.y) |v2| {
            new_kf.y = self.timing_fn(v1, v2, percent);
        }
    }

    if (kf1.rotation) |v1| {
        if (kf2.rotation) |v2| {
            new_kf.rotation = self.timing_fn(v1, v2, percent);
        }
    }

    if (kf1.width) |v1| {
        if (kf2.width) |v2| {
            new_kf.width = self.timing_fn(v1, v2, percent);
        }
    }

    if (kf1.height) |v1| {
        if (kf2.height) |v2| {
            new_kf.height = self.timing_fn(v1, v2, percent);
        }
    }

    if (kf1.sprite) |v1| {
        if (kf2.sprite) |v2| {
            new_kf.sprite = if (percent > 0.5) v2 else v1;
        }
    }

    if (kf1.scaling) |v1| {
        if (kf2.scaling) |v2| {
            new_kf.scaling = if (percent > 0.5) v2 else v1;
        }
    }

    if (kf1.tint) |v1| {
        if (kf2.tint) |v2| {
            new_kf.tint = if (percent > 0.5) v2 else v1;
        }
    }

    return new_kf;
}
