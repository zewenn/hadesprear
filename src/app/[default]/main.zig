const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

const GUI = e.GUI;
const u = GUI.u;

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    e.input.ui_mode = true;

    try GUI.UI(
        .{
            .id = "body",
            .style = .{
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
            },
        },
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
                            .left = u("50w"),
                            .top = u("50h"),
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
                try GUI.Button(
                    .{
                        .id = "hello-world-2",
                        .style = GUI.StyleSheet{
                            .font = .{
                                .size = 64,
                                .spacing = 1,
                            },
                            .color = e.Color.pink,
                            .translate = .{
                                .x = .center,
                                .y = .center,
                            },
                            .background = .{
                                .color = e.Color.blue,
                            },
                        },
                    },
                    "Hello World!",
                    e.Vector2.init(4, 7),
                    struct {
                        pub fn printTest() anyerror!void {
                            std.log.debug("Clicked!", .{});
                        }
                    }.printTest,
                ),
            },
        ),
        "",
    );
}

pub fn init() !void {
    // try e.scenes.load("game");
}

pub fn update() !void {}

pub fn deinit() !void {}
