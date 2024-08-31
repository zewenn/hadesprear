const std = @import("std");
const z = @import("./z/z.zig");
const ecs = @import("./ecs/ecs.zig");
const rl = @import("raylib");
const assets = @import("./assets.zig");
const Allocator = @import("std").mem.Allocator;

const Previous = struct {
    transform: ?ecs.components.Transform = null,
    display: ?ecs.components.Display = null,
    texture: ?rl.Texture2D = null,
};

/// Key: entity.id - Value: Previously rendered data
var PreviousMap: std.StringHashMap(Previous) = undefined;
var alloc: *Allocator = undefined;

pub fn init(allocator: *Allocator) void {
    alloc = allocator;

    PreviousMap = std.StringHashMap(Previous).init(alloc.*);
    z.dprint("[MODULE] DISPLAY: LOADED", .{});
}

pub fn deinit() void {
    var kIt = PreviousMap.keyIterator();

    while (kIt.next()) |key| {
        const value = PreviousMap.getPtr(key.*);
        if (value) |val| {
            if (val.texture) |txtr| {
                rl.unloadTexture(txtr);
            }
        }
    }
    PreviousMap.deinit();
}

pub fn update() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);

    var KIt = ecs.entities.keyIterator();

    while (KIt.next()) |key| {
        var entity = ecs.getEntity(key.*).?.*;
        var prev: *Previous = undefined;
        var flag: bool = false;

        if (PreviousMap.getPtr(entity.id)) |pr| {
            prev = pr;
        } else {
            PreviousMap.put(entity.id, Previous{}) catch {
                z.panic("Failed to allocate memory for Previous object");
            };
            prev = PreviousMap.getPtr(entity.id).?;
        }

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

        if (prev.transform) |ptransform| {
            if (!transform.equals(ptransform)) {
                prev.transform = transform;
                flag = true;
            }
        } else flag = true;

        if (prev.display) |pdisplay| {
            if (!z.arrays.StringEqual(
                display.sprite,
                pdisplay.sprite,
            )) {
                prev.display = display;
                flag = true;
            }
        } else flag = true;

        if (prev.texture) |_texture| {
            if (!flag) {
                texture = _texture;
            } else {
                rl.unloadTexture(_texture);
            }
        } else flag = true;

        if (!flag) {
            drawTetxure(texture, transform.position, rl.Color.white);
            continue;
        }

        if (assets.get(rl.Image, display.sprite)) |_img| {
            img = _img;
        } else {
            std.log.info("DISPLAY: IMAGE: MISSING IMAGE \"{s}\"", .{display.sprite});
            continue;
        }

        switch (display.scaling) {
            .normal => rl.imageResize(
                &img,
                @intFromFloat(transform.scale.x),
                @intFromFloat(transform.scale.y),
            ),
            .pixelate => rl.imageResizeNN(
                &img,
                @intFromFloat(transform.scale.x),
                @intFromFloat(transform.scale.y),
            ),
        }

        rl.imageRotate(
            &img,
            @intFromFloat(transform.rotation.z),
        );

        texture = rl.loadTextureFromImage(img);
        prev.texture = texture;
        // defer rl.unloadTexture(texture);
        drawTetxure(texture, transform.position, rl.Color.white);
    }
}

fn drawTetxure(texture: rl.Texture, pos: rl.Vector2, tint: rl.Color) void {
    rl.drawTexture(
        texture,
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        tint,
    );
}
