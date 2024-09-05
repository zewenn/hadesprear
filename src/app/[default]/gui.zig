const std = @import("std");
const e = @import("../../engine/engine.zig");

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    _ = try e.GUI.Element(
        .{
            .id = "Test1",
            .style = e.GUI.StyleSheet{
                .background_color = e.Color.red,
                .background_image = "player_left_0.png",
            },
        },
        &[_]e.GUI.GUIElement{},
    );
}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {}
