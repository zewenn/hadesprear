const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const e = Import(.engine);

// ===================== [Entity] =====================

// =================== [Components] ===================

// ===================== [Others] =====================

// ===================== [Events] =====================

pub fn awake() !void {
    _ = try e.GUI.Element(
        .{
            .id = "Test1",
            .style = e.GUI.StyleSheet{
                .background = .{
                    .color = e.Color.red,
                },
                .width = .{ .value = 40, .unit = .vw },
            },
        },
        @constCast(&[_]*e.GUI.GUIElement{
            try e.GUI.TextElement(
                .{
                    .id = "Text",
                    .style = .{ .top = .{
                        .value = 10,
                        .unit = .vh,
                    } },
                },
                "Zig is the best!",
            ),
        }),
        "Hello fucking world!",
    );
}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {
}
