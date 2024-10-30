const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const Keyframe = @import("Keyframe.zig");
const Number = @import("interpolation.zig").Number;
const components = @import("../entities/components.zig");

const time = @import("../time.m.zig");
const z = @import("../z/z.m.zig");

const Self = @This();

const Modes = enum {
    forwards,
    backwards,
};

id: []const u8,
timing_fn: *const fn (Number, Number, Number) Number,
keyframes: std.AutoHashMap(u8, Keyframe),

transition_time: Number,

transition_time_ms_per_frame: f64 = 0,
last_frame_at: f64 = 0,
next_frame_at: f64 = 0,

playing: bool = false,
loop: bool = false,
mode: Modes = .forwards,

current_frame: u8 = 0,
keys: std.ArrayList(u8),
keys_slice: ?[]u8 = null,
max_frames: u8 = 100,

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
        .transition_time_ms_per_frame = transition_time / 100,
    };
}

fn forwardsComp(_: void, a: u8, b: u8) bool {
    return a < b;
}
fn backwardsComp(_: void, a: u8, b: u8) bool {
    return b > a;
}

pub fn chain(self: *Self, percent: u8, kf: Keyframe) *Self {
    if (self.keyframes.get(percent) != null) z.panicWithArgs(
        "Animation \"{s}\" already has key \"{d}\" but the program tried to set it again.",
        .{ self.id, percent },
    );
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

    self.transition_time_ms_per_frame = self.transition_time / @as(f32, @floatFromInt(self.max_frames));

    return self;
}

pub fn recalculateTransitionTimePerKeyFrame(self: *Self) void {
    self.transition_time_ms_per_frame = @as(
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
    for (self.keys_slice.?) |frame| {
        if (self.current_frame < frame) return self.keyframes.get(frame);
    }
    return null;
}

pub fn getCurrent(self: *Self) ?Keyframe {
    var last: u8 = 0;
    for (self.keys_slice.?) |frame| {
        if (self.current_frame >= frame) last = frame;
    }
    return self.keyframes.get(last);
}

pub fn next(self: *Self) void {
    self.current_frame += 1;

    if (self.max_frames < self.current_frame) {
        if (self.loop) {
            self.current_frame = 0;
            return;
        }
        self.current_frame = 100;
        self.playing = false;
    }
}

pub inline fn interpolateKeyframes(self: *Self, kf1: Keyframe, kf2: Keyframe, percent: Number) Keyframe {
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

    if (kf1.rx) |v1| {
        if (kf2.rx) |v2| {
            new_kf.rx = self.timing_fn(v1, v2, percent);
        }
    }

    if (kf1.ry) |v1| {
        if (kf2.ry) |v2| {
            new_kf.ry = self.timing_fn(v1, v2, percent);
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
            // new_kf.tint = if (percent > 0.5) v2 else v1;
            new_kf.tint = .{
                .r = @intFromFloat(self.timing_fn(@floatFromInt(v1.r), @floatFromInt(v2.r), percent)),
                .g = @intFromFloat(self.timing_fn(@floatFromInt(v1.g), @floatFromInt(v2.g), percent)),
                .b = @intFromFloat(self.timing_fn(@floatFromInt(v1.b), @floatFromInt(v2.b), percent)),
                .a = @intFromFloat(self.timing_fn(@floatFromInt(v1.a), @floatFromInt(v2.a), percent)),
            };
        }
    }

    // DUMMY SHIT
    {
        // f32

        if (kf1.d1f32) |v1| {
            if (kf2.d1f32) |v2| {
                new_kf.d1f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d2f32) |v1| {
            if (kf2.d2f32) |v2| {
                new_kf.d2f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d3f32) |v1| {
            if (kf2.d3f32) |v2| {
                new_kf.d3f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d4f32) |v1| {
            if (kf2.d4f32) |v2| {
                new_kf.d4f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d5f32) |v1| {
            if (kf2.d5f32) |v2| {
                new_kf.d5f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d6f32) |v1| {
            if (kf2.d6f32) |v2| {
                new_kf.d6f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d7f32) |v1| {
            if (kf2.d7f32) |v2| {
                new_kf.d7f32 = self.timing_fn(v1, v2, percent);
            }
        }

        if (kf1.d8f32) |v1| {
            if (kf2.d8f32) |v2| {
                new_kf.d8f32 = self.timing_fn(v1, v2, percent);
            }
        }

        // u8

        if (kf1.d1u8) |v1| {
            if (kf2.d1u8) |v2| {
                new_kf.d1u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d2u8) |v1| {
            if (kf2.d2u8) |v2| {
                new_kf.d2u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d3u8) |v1| {
            if (kf2.d3u8) |v2| {
                new_kf.d3u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d4u8) |v1| {
            if (kf2.d4u8) |v2| {
                new_kf.d4u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d5u8) |v1| {
            if (kf2.d5u8) |v2| {
                new_kf.d5u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d6u8) |v1| {
            if (kf2.d6u8) |v2| {
                new_kf.d6u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d7u8) |v1| {
            if (kf2.d7u8) |v2| {
                new_kf.d7u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        if (kf1.d8u8) |v1| {
            if (kf2.d8u8) |v2| {
                new_kf.d8u8 = @intFromFloat(@round(self.timing_fn(
                    @floatFromInt(v1),
                    @floatFromInt(v2),
                    percent,
                )));
            }
        }

        // Color

        if (kf1.d1Color) |v1| {
            if (kf2.d1Color) |v2| {
                new_kf.d1Color = .{
                    .r = @intFromFloat(self.timing_fn(@floatFromInt(v1.r), @floatFromInt(v2.r), percent)),
                    .g = @intFromFloat(self.timing_fn(@floatFromInt(v1.g), @floatFromInt(v2.g), percent)),
                    .b = @intFromFloat(self.timing_fn(@floatFromInt(v1.b), @floatFromInt(v2.b), percent)),
                    .a = @intFromFloat(self.timing_fn(@floatFromInt(v1.a), @floatFromInt(v2.a), percent)),
                };
            }
        }

        if (kf1.d2Color) |v1| {
            if (kf2.d2Color) |v2| {
                new_kf.d2Color = .{
                    .r = @intFromFloat(self.timing_fn(@floatFromInt(v1.r), @floatFromInt(v2.r), percent)),
                    .g = @intFromFloat(self.timing_fn(@floatFromInt(v1.g), @floatFromInt(v2.g), percent)),
                    .b = @intFromFloat(self.timing_fn(@floatFromInt(v1.b), @floatFromInt(v2.b), percent)),
                    .a = @intFromFloat(self.timing_fn(@floatFromInt(v1.a), @floatFromInt(v2.a), percent)),
                };
            }
        }

        if (kf1.d3Color) |v1| {
            if (kf2.d3Color) |v2| {
                new_kf.d3Color = .{
                    .r = @intFromFloat(self.timing_fn(@floatFromInt(v1.r), @floatFromInt(v2.r), percent)),
                    .g = @intFromFloat(self.timing_fn(@floatFromInt(v1.g), @floatFromInt(v2.g), percent)),
                    .b = @intFromFloat(self.timing_fn(@floatFromInt(v1.b), @floatFromInt(v2.b), percent)),
                    .a = @intFromFloat(self.timing_fn(@floatFromInt(v1.a), @floatFromInt(v2.a), percent)),
                };
            }
        }

        if (kf1.d4Color) |v1| {
            if (kf2.d4Color) |v2| {
                new_kf.d4Color = .{
                    .r = @intFromFloat(self.timing_fn(@floatFromInt(v1.r), @floatFromInt(v2.r), percent)),
                    .g = @intFromFloat(self.timing_fn(@floatFromInt(v1.g), @floatFromInt(v2.g), percent)),
                    .b = @intFromFloat(self.timing_fn(@floatFromInt(v1.b), @floatFromInt(v2.b), percent)),
                    .a = @intFromFloat(self.timing_fn(@floatFromInt(v1.a), @floatFromInt(v2.a), percent)),
                };
            }
        }
    }

    return new_kf;
}
