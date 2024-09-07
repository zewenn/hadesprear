const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const assets = Import(.assets);
const ecs = Import(.ecs);
const GUI = Import(.gui);

const rl = @import("raylib");
const z = Import(.z);

// ==================================================

pub const window = @import("./window.zig");

pub const camera = struct {
    pub var position = rl.Vector2.init(0, 0);
    pub var zoom: f32 = 1;

    pub var following: ?*rl.Vector2 = null;

    pub fn follow(vec: *rl.Vector2) void {
        following = vec;
    }

    pub fn update() void {
        if (following) |v| {
            position = v.*;
        }
    }
};

// ==================================================

const Previous = struct {
    transform: ?ecs.components.Transform = null,
    display: ?ecs.components.Display = null,
    img: ?rl.Image = null,
    texture: ?rl.Texture = null,
};

const PreviousMap = std.StringHashMap(Previous);
var previous_map: PreviousMap = undefined;
var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    previous_map = PreviousMap.init(allocator.*);
    alloc = allocator;
}

pub fn deinit() void {
    previous_map.deinit();
}

pub fn sortEntities(_: void, lsh: *ecs.Entity, rsh: *ecs.Entity) bool {
    const lsh_transform = lsh.get(ecs.cTransform, "transform").?;
    const rsh_transform = rsh.get(ecs.cTransform, "transform").?;

    return (
    //
        lsh_transform.position.y -
        if (lsh_transform.anchor) |anchor| anchor.y else lsh_transform.scale.y * camera.zoom / 2
    //
    ) < (
    //
        rsh_transform.position.y -
        if (rsh_transform.anchor) |anchor| anchor.y else rsh_transform.scale.y * camera.zoom / 2
    //
    );
}

pub fn update() !void {
    rl.setTraceLogLevel(.log_error);
    defer rl.setTraceLogLevel(.log_debug);

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);

    const entities = try ecs.getEntities("transform");
    defer ecs.alloc.free(entities);
    std.sort.insertion(*ecs.Entity, entities, {}, sortEntities);

    for (entities) |entity| {
        var transform: ecs.components.Transform = undefined;
        var display: ecs.components.Display = undefined;

        var img: rl.Image = undefined;
        defer rl.unloadImage(img);

        var texture: rl.Texture = undefined;

        if (entity.get(ecs.components.Transform, "transform")) |_transform| {
            transform = _transform.*;
        } else continue;

        if (entity.get(ecs.components.Display, "display")) |_display| {
            display = _display.*;
        } else continue;

        const path: bool = Decide: {
            if (!previous_map.contains(entity.id)) {
                previous_map.put(entity.id, .{
                    .transform = transform,
                    .display = display,
                    .img = null,
                }) catch {
                    std.log.debug("failed to store entity", .{});
                };
                break :Decide false;
            }

            const last = previous_map.getPtr(entity.id).?;

            if (last.transform == null) break :Decide false;
            if (last.display == null) break :Decide false;
            if (last.img == null) break :Decide false;

            if (last.transform.?.rotation.equals(transform.rotation) != 0 and
                last.transform.?.scale.equals(transform.scale) != 0 and
                z.arrays.StringEqual(last.display.?.sprite, display.sprite) and
                last.display.?.scaling == display.scaling)
            {
                break :Decide true;
            }

            break :Decide false;
        };

        const last = previous_map.getPtr(entity.id).?;

        if (path) {
            img = rl.imageCopy(last.img.?);
            texture = last.texture.?;
        } else {
            if (assets.get(rl.Image, display.sprite)) |_img| {
                img = _img;
            } else {
                std.log.info("DISPLAY: IMAGE: MISSING IMAGE \"{s}\"", .{display.sprite});
                continue;
            }

            switch (display.scaling) {
                .normal => rl.imageResize(
                    &img,
                    @intFromFloat(transform.scale.x * camera.zoom),
                    @intFromFloat(transform.scale.y * camera.zoom),
                ),
                .pixelate => rl.imageResizeNN(
                    &img,
                    @intFromFloat(transform.scale.x * camera.zoom),
                    @intFromFloat(transform.scale.y * camera.zoom),
                ),
            }
            if (last.img) |image| {
                rl.unloadImage(image);
            }
            if (last.texture) |t| {
                rl.unloadTexture(t);
            }
            last.img = rl.imageCopy(img);
            last.texture = rl.loadTextureFromImage(img);

            texture = last.texture.?;

            last.display = display;
            last.transform = transform;
        }

        drawTetxure(
            texture,
            transform,
            display.tint,
            display.ignore_world_pos,
        );
    }

    var GUIIt = GUI.Elements.keyIterator();
    while (GUIIt.next()) |key| {
        var element: *GUI.GUIElement = GUI.Elements.getPtr(key.*).?;

        _ = element.calculateTransform();

        var transform: ecs.cTransform = undefined;

        if (element.transform) |t| {
            transform = t;
        } else continue;

        // std.log.debug("Display Before Background", .{});

        BackgroundColorRendering: {
            var background_color: rl.Color = undefined;
            if (element.options.style.background.color) |c| {
                background_color = c;
            } else break :BackgroundColorRendering;

            rl.drawRectanglePro(
                rl.Rectangle.init(
                    transform.position.x,
                    transform.position.y,
                    transform.scale.x,
                    transform.scale.y,
                ),
                rl.Vector2.init(0, 0),
                transform.rotation.z,
                background_color,
            );
        }

        BacgroundImageRendering: {
            // background_image
            var background_image: []const u8 = undefined;
            if (element.options.style.background.image) |bc_img| {
                background_image = bc_img;
            } else break :BacgroundImageRendering;

            var img: rl.Image = undefined;
            defer rl.unloadImage(img);

            var texture: rl.Texture = undefined;

            if (assets.get(rl.Image, background_image)) |_img| {
                img = _img;
            } else {
                std.log.info("DISPLAY: IMAGE: MISSING IMAGE \"{s}\"", .{background_image});
                break :BacgroundImageRendering;
            }

            rl.imageResizeNN(
                &img,
                @intFromFloat(transform.scale.x * camera.zoom),
                @intFromFloat(transform.scale.y * camera.zoom),
            );

            rl.unloadTexture(texture);
            texture = rl.loadTextureFromImage(img);

            // defer rl.unloadTexture(texture);
            rl.drawTexturePro(
                texture,
                rl.Rectangle.init(
                    0,
                    0,
                    transform.scale.x,
                    transform.scale.y,
                ),
                rl.Rectangle.init(
                    transform.position.x,
                    transform.position.y,
                    transform.scale.x,
                    transform.scale.y,
                ),
                rl.Vector2.init(0, 0),
                transform.rotation.z,
                rl.Color.white,
            );
        }

        FontRendering: {
            var content: [*:0]const u8 = undefined;
            if (element.contents) |c| {
                content = c;
            } else break :FontRendering;

            var font: rl.Font = undefined;
            if (assets.get(rl.Font, element.options.style.font.family)) |_font| {
                font = _font;
            } else break :FontRendering;

            rl.drawTextPro(
                font,
                content,
                transform.position,
                rl.Vector2.init(0, 0),
                transform.rotation.z,
                element.options.style.font.size,
                element.options.style.font.spacing,
                element.options.style.color,
            );
        }
    }
}

fn drawTetxure(
    texture: rl.Texture,
    transform: ecs.cTransform,
    tint: rl.Color,
    ignore_cam: bool,
) void {
    const X = GetX: {
        var x: f128 = 0;
        x = z.math.div(window.size.x, 2).?;
        x += z.math.to_f128(transform.position.x).?;
        if (!ignore_cam) x -= z.math.to_f128(camera.position.x).?;

        break :GetX z.math.f128_to(f32, x).?;
    };

    const Y = GetY: {
        var y = z.math.div(window.size.y, 2).?;
        y += z.math.to_f128(transform.position.y).?;
        if (!ignore_cam)
            y -= z.math.to_f128(camera.position.y).?;

        break :GetY z.math.f128_to(f32, y).?;
    };

    const origin: rl.Vector2 = if (transform.anchor) |anchor|
        anchor
    else
        rl.Vector2.init(
            transform.scale.x * camera.zoom / 2,
            transform.scale.y * camera.zoom / 2,
        );

    rl.drawTexturePro(
        texture,
        rl.Rectangle.init(0, 0, transform.scale.x, transform.scale.y),
        rl.Rectangle.init(X, Y, transform.scale.x, transform.scale.y),
        origin,
        transform.rotation.z,
        tint,
    );

    // Debug
    Debug: {
        if (!z.debug.debugDisplay) break :Debug;

        rl.drawRectangleLines(
            @intFromFloat(X - origin.x),
            @intFromFloat(Y - origin.y),
            @intFromFloat(transform.scale.x),
            @intFromFloat(transform.scale.y),
            rl.Color.lime,
        );

        rl.drawLine(
            @intFromFloat(X),
            @intFromFloat(Y),
            @intFromFloat(X - origin.x),
            @intFromFloat(Y - origin.y),
            rl.Color.yellow,
        );

        rl.drawCircle(@intFromFloat(X), @intFromFloat(Y), 2, rl.Color.purple);
        rl.drawCircle(@intFromFloat(X - origin.x), @intFromFloat(Y - origin.y), 2, rl.Color.red);
    }
}