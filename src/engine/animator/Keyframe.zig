const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");

const ecs = Import(.ecs);

const Self = @This();

// === Transform ===

// Position
x: ?f32 = null,
y: ?f32 = null,

// Rotation
rotation: ?f32 = null,

// Scale
width: ?f32 = null,
height: ?f32 = null,

// === Display ===

sprite: ?[]const u8 = null,
scaling: ?ecs.cDisplay.scalings = null,
tint: ?rl.Color = null,
