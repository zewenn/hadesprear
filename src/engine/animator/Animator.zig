const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const interpolation = @import("interpolation.zig");
const entities = @import("../engine.m.zig").entities;

pub const Keyframe = @import("Keyframe.zig");
pub const Animation = @import("Animation.zig");
pub const Number = interpolation.Number;

const time = Import(.time);
const z = Import(.z);

const Self = @This();

entity: *entities.Entity,
transform: *entities.Transform,
display: *entities.Display,

animations: std.StringHashMap(Animation),
playing: std.ArrayList(*Animation),

alloc: *Allocator,

pub fn init(allocator: *Allocator, entity: *entities.Entity) Self {
    return Self{
        .alloc = allocator,
        .entity = entity,
        .transform = &entity.transform,
        .display = &entity.display,
        .animations = std.StringHashMap(Animation).init(allocator.*),
        .playing = std.ArrayList(*Animation).init(allocator.*),
    };
}

pub fn deinit(self: *Self) void {
    var it = self.animations.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.*.deinit();
    }
    self.playing.deinit();
    self.animations.deinit();
}

/// Animations chained to the animator **will be** freed when `.deinit()` is called.
pub fn chain(self: *Self, anim: Animation) !void {
    try self.animations.put(anim.id, anim);
}

pub fn play(self: *Self, id: []const u8) !void {
    const anim = self.animations.getPtr(id);
    if (anim) |animation| {
        try self.playing.append(animation);
        animation.playing = true;
        animation.current_frame = 0;
        animation.last_keyframe_at = time.gameTime;
        animation.next_keyframe_at = time.gameTime + animation.transition_time_ms_per_kf;
    }
}

pub fn isPlaying(self: *Self, id: []const u8) bool {
    const anim = self.animations.getPtr(id);
    if (anim) |a| {
        return a.playing;
    }
    return false;
}

pub fn stop(self: *Self, id: []const u8) void {
    const anim = self.animations.getPtr(id);
    if (anim) |animation| {
        for (self.playing.items, 0..) |item, i| {
            if (!z.arrays.StringEqual(item.id, id)) continue;

            _ = self.playing.orderedRemove(i);
            break;
        }
        animation.playing = false;
    }
}

pub fn applyKeyframe(self: *Self, kf: Keyframe) void {
    // === Transform ===

    // Position
    if (kf.x) |v| {
        self.transform.position.x = v;
    }

    if (kf.y) |v| {
        self.transform.position.y = v;
    }

    // Rotation
    if (kf.rx) |v| {
        self.transform.rotation.x = v;
    }

    if (kf.ry) |v| {
        self.transform.rotation.y = v;
    }

    if (kf.rotation) |v| {
        self.transform.rotation.z = v;
    }

    // Scale
    if (kf.width) |v| {
        self.transform.scale.x = v;
    }

    if (kf.height) |v| {
        self.transform.scale.y = v;
    }

    // === Display ===
    if (kf.sprite) |v| {
        self.display.sprite = v;
    }

    if (kf.scaling) |v| {
        self.display.scaling = v;
    }

    if (kf.tint) |v| {
        self.display.tint = v;
    }
}

pub fn update(self: *Self) void {
    for (self.playing.items) |anim| {
        if (time.gameTime > anim.next_keyframe_at) {
            anim.next();
            if (!anim.playing) {
                self.stop(anim.id);
                break;
            }

            anim.last_keyframe_at = time.gameTime;
            anim.next_keyframe_at = time.gameTime + anim.transition_time_ms_per_kf;
        }

        const current_kf = anim.getCurrent();
        const next_kf = anim.getNext();

        if (next_kf == null and current_kf != null) {
            self.applyKeyframe(current_kf.?);
            continue;
        }

        if (current_kf == null or next_kf == null) continue;

        const curr = current_kf.?;
        const nxt = next_kf.?;

        const p: f32 = 1 - @as(
            f32,
            @floatCast(anim.next_keyframe_at - time.gameTime),
        ) / @as(
            f32,
            @floatCast(anim.transition_time_ms_per_kf),
        );

        self.applyKeyframe(
            anim.interpolateKeyframes(
                curr,
                nxt,
                p,
            ),
        );
    }
}
