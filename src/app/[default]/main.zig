const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

const GUI = e.GUI;

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    try GUI.UI(
        .{ .id = "body", .style = .{
            .left = .{ .value = 50, .unit = .vw },
            .top = .{ .value = 50, .unit = .vh },

            .height = .{ .value = 50, .unit = .vh },
            .width = .{ .value = 50, .unit = .vw },

            .translate = .{
                .x = .center,
                .y = .center,
            },
            .background = .{
                .color = e.Color.red,
            },
        } },
        @constCast(
            &[_]*GUI.GUIElement{
                try GUI.Container(
                    .{
                        .id = "hello-world",
                        .style = GUI.StyleSheet{
                            .font = .{
                                .size = 64,
                                .spacing = 1,
                            },
                            .color = e.Color.pink,
                            .left = .{ .value = 50, .unit = .vw },
                            .top = .{ .value = 50, .unit = .vh },
                            .translate = .{
                                .x = .center,
                                .y = .center,
                            },
                            // .rotation = 90,
                            .background = .{
                                .color = e.Color.red,
                            },
                        },
                    },
                    @constCast(&[_]*GUI.GUIElement{}),
                ),
                try GUI.TextElement(.{
                    .id = "hello-world-2",
                    .style = GUI.StyleSheet{
                        .font = .{
                            .size = 64,
                            .spacing = 1,
                        },
                        .color = e.Color.pink,
                        // .left = .{ .value = 50, .unit = .vw },
                        // .top = .{ .value = 50, .unit = .vh },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                    },
                }, "Hello World!"),
            },
        ),
        "",
    );
}

pub fn init() !void {
    try e.scenes.load("game");
}

pub fn update() !void {}

pub fn deinit() !void {}
