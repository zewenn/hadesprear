const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const rl = @import("raylib");

const entities = @import("../engine.m.zig").entities;

const Self = @This();

// === Transform ===

// Position
x: ?f32 = null,
y: ?f32 = null,

// Rotation
rx: ?f32 = null,
ry: ?f32 = null,
rotation: ?f32 = null,

// Scale
width: ?f32 = null,
height: ?f32 = null,

// === Display ===

sprite: ?[]const u8 = null,
scaling: ?entities.Display.scalings = null,
tint: ?rl.Color = null,
