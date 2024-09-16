const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

const ProjectileArrayType = std.ArrayList(e.entities.Entity);
var projectile_array: ProjectileArrayType = undefined;

pub fn awake() !void {
    projectile_array.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {
    projectile_array.deinit();
}
