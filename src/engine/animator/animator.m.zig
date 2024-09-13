const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const interpolation = @import("interpolation.zig");
const ecs = Import(.ecs);

pub const Keyframe = @import("Keyframe.zig");
pub const Animation = @import("Animation.zig");
pub const Number = interpolation.Number;

const time = Import(.time);
const z = Import(.z);

const Self = @This();

entity: *ecs.Entity,
transform: *ecs.cTransform,
display: *ecs.cDisplay,

animations: std.StringHashMap(Animation),
playing: std.ArrayList(*Animation),

alloc: *Allocator,

const AnimatorCreationFailed = error{
    EntityNoTransform,
    EntityNoDisplay,
};

pub fn init(allocator: *Allocator, entity: *ecs.Entity) !Self {
    const transform = entity.get(ecs.cTransform, "transform");
    if (transform == null) return AnimatorCreationFailed.EntityNoTransform;

    const display = entity.get(ecs.cDisplay, "display");
    if (display == null) return AnimatorCreationFailed.EntityNoDisplay;

    return Self{
        .alloc = allocator,
        .entity = entity,
        .transform = transform.?,
        .display = display.?,
        .animations = std.StringHashMap(Animation).init(allocator.*),
        .playing = std.ArrayList(*Animation).init(allocator.*),
    };
}

pub fn deinit(self: *Self) void {
    var it = self.animations.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.*.deinit();
    }
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
        animation.last_keyframe_at = time.currentTime;
        animation.next_keyframe_at = time.currentTime + animation.transition_time_ms_per_kf;
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
        if (time.currentTime > anim.next_keyframe_at) {
            anim.next();
            if (!anim.playing) {
                self.stop(anim.id);
                break;
            }

            anim.last_keyframe_at = time.currentTime;
            anim.next_keyframe_at = time.currentTime + anim.transition_time_ms_per_kf;
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
            @floatCast(anim.next_keyframe_at - time.currentTime),
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
