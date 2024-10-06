const Import = @import("../../.temp/imports.zig").Import;

const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const assets = Import(.assets);
const entities = @import("../engine.m.zig").entities;
const GUI = Import(.gui);
const input = Import(.input);

const rl = @import("raylib");
const z = Import(.z);

// ==================================================

pub const window = @import("./window.zig");

pub const camera = @import("./camera.zig");

// ==================================================

fn sortEntities(_: void, lsh: *entities.Entity, rsh: *entities.Entity) bool {
    const lsh_transform = lsh.transform;
    const rsh_transform = rsh.transform;

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

fn sortGUIElements(_: void, lsh: *GUI.GUIElement, rsh: *GUI.GUIElement) bool {
    const lsh_z_index = lsh.options.style.z_index;
    const rsh_z_index = rsh.options.style.z_index;

    return lsh_z_index < rsh_z_index;
}

pub fn update() !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);

    // ==============================================

    //                    Entities

    // ==============================================

    const entity_slice = try entities.all();
    defer entities.alloc.free(entity_slice);
    std.sort.insertion(*entities.Entity, entity_slice, {}, sortEntities);

    for (entity_slice) |entity| {
        const transform = entity.transform;
        const display = entity.display;

        var img: rl.Image = undefined;
        defer rl.unloadImage(img);

        var texture: rl.Texture = undefined;

        const use_previous: bool = Decide: {
            if (entity.cached_display == null) break :Decide false;

            const cached = entity.cached_display.?;

            if (cached.transform.scale.equals(transform.scale) == 0) break :Decide false;
            if (cached.transform.rotation.equals(transform.rotation) == 0) break :Decide false;
            if (!std.mem.eql(u8, cached.display.sprite, display.sprite)) break :Decide false;
            if (cached.display.scaling != display.scaling) break :Decide false;

            if (cached.img == null) break :Decide false;
            if (cached.texture == null) break :Decide false;

            break :Decide true;
        };

        if (use_previous and entity.cached_display != null) {
            img = rl.imageCopy(entity.cached_display.?.img.?);
            texture = entity.cached_display.?.texture.?;
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
            if (entity.cached_display) |cached| {
                if (cached.img) |chached_image| {
                    rl.unloadImage(chached_image);
                }
                if (cached.texture) |cached_texture| {
                    rl.unloadTexture(cached_texture);
                }
            }

            entity.cached_display = .{
                .transform = transform,
                .display = display,
                .img = rl.imageCopy(img),
                .texture = rl.loadTextureFromImage(img),
            };

            texture = entity.cached_display.?.texture.?;
        }

        drawTetxure(
            texture,
            transform,
            display.tint,
            display.ignore_world_pos,
        );
    }

    // ==============================================

    //                      GUI

    // ==============================================

    var GUIElements = std.ArrayList(*GUI.GUIElement).init(std.heap.page_allocator);
    defer GUIElements.deinit();

    for (GUI.elements.array, 0..) |entry, index| {
        if (entry == null) continue;
        try GUIElements.insert(0, &(GUI.elements.array[index].?));
        // try GUIElements.append(entry.value_ptr);
    }

    const sorted_elements = try GUIElements.toOwnedSlice();
    defer GUIElements.allocator.free(sorted_elements);

    std.sort.insertion(*GUI.GUIElement, sorted_elements, {}, sortGUIElements);

    for (sorted_elements) |element| {
        _ = element.calculateTransform();

        const style = GetStyle: {
            if (element.is_hovered) {
                break :GetStyle element.options.style.merge(element.options.hover);
            }
            break :GetStyle element.options.style;
        };

        if (!style.display) continue;

        var transform: entities.Transform = undefined;

        if (element.transform) |t| {
            transform = t;
        } else continue;

        // const origin: rl.Vector2 = GetOrigin: {
        //     var anchor = rl.Vector2.init(0, 0);

        //     switch (element.options.style.translate.x) {
        //         .min => anchor.x = 0,
        //         .center => anchor.x = transform.scale.x * camera.zoom / 2,
        //         .max => anchor.x = transform.scale.x * camera.zoom,
        //     }
        //     switch (element.options.style.translate.y) {
        //         .min => anchor.y = 0,
        //         .center => anchor.y = transform.scale.y * camera.zoom / 2,
        //         .max => anchor.y = transform.scale.y * camera.zoom,
        //     }
        //     break :GetOrigin anchor;
        // };
        const origin = transform.anchor.?.multiply(
            rl.Vector2.init(camera.zoom, camera.zoom),
        );

        BackgroundColorRendering: {
            var background_color: rl.Color = undefined;
            if (style.background.color) |c| {
                background_color = c;
            } else break :BackgroundColorRendering;

            rl.drawRectanglePro(
                rl.Rectangle.init(
                    transform.position.x,
                    transform.position.y,
                    transform.scale.x,
                    transform.scale.y,
                ),
                origin,
                transform.rotation.z,
                background_color,
            );
        }

        BacgroundImageRendering: {
            if (style.background.image == null) break :BacgroundImageRendering;

            const display: entities.Display = .{
                .sprite = style.background.image.?,
                .scaling = .pixelate,
            };

            var img: rl.Image = undefined;
            defer rl.unloadImage(img);

            var texture: rl.Texture = undefined;

            const use_previous: bool = Decide: {
                if (element.cached_display == null) {
                    break :Decide false;
                }

                const cached = element.cached_display.?;

                if (cached.transform.scale.equals(transform.scale) == 0) {
                    break :Decide false;
                }
                if (cached.transform.rotation.equals(transform.rotation) == 0) {
                    break :Decide false;
                }
                if (!std.mem.eql(u8, cached.display.sprite, display.sprite)) {
                    break :Decide false;
                }
                if (cached.display.scaling != display.scaling) {
                    break :Decide false;
                }

                if (cached.img == null) break :Decide false;
                if (cached.texture == null) break :Decide false;

                break :Decide true;
            };

            if (use_previous and element.cached_display != null) {
                img = rl.imageCopy(element.cached_display.?.img.?);
                texture = element.cached_display.?.texture.?;
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
                if (element.cached_display) |cached| {
                    if (cached.img) |chached_image| {
                        rl.unloadImage(chached_image);
                    }
                    if (cached.texture) |cached_texture| {
                        rl.unloadTexture(cached_texture);
                    }
                }

                element.cached_display = .{
                    .transform = transform,
                    .display = display,
                    .img = rl.imageCopy(img),
                    .texture = rl.loadTextureFromImage(img),
                };

                texture = element.cached_display.?.texture.?;
            }
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
                origin,
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
            if (assets.get(rl.Font, style.font.family)) |_font| {
                font = _font;
            } else break :FontRendering;

            const len = std.mem.indexOfSentinel(u8, 0, content);
            const ox: f32 = style.font.size * @as(f32, @floatFromInt(len)) / 2;
            const oy: f32 = style.font.size / 2;

            rl.drawTextPro(
                font,
                content,
                transform.position,
                // origin,
                rl.Vector2.init(ox, oy),
                transform.rotation.z,
                style.font.size,
                style.font.spacing,
                style.color,
            );
        }
    }

    rl.drawRectangle(
        @intFromFloat(input.mouse_position.x - 5),
        @intFromFloat(input.mouse_position.y - 5),
        5,
        5,
        rl.Color.black,
    );
}

fn drawTetxure(
    texture: rl.Texture,
    transform: entities.Transform,
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
