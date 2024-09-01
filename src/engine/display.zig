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

pub const window = struct {
    pub var size = rl.Vector2.init(0, 0);
    pub var borderless = false;
    pub var fullscreen = false;

    pub fn resize(to: rl.Vector2) void {
        rl.setWindowSize(
            @intFromFloat(to.x),
            @intFromFloat(to.y),
        );
        size = to;
    }

    pub fn toggleBorderless() void {
        if (borderless) {
            resize(rl.Vector2.init(1280, 720));
        } else {
            size = rl.Vector2.init(
                @floatFromInt(rl.getScreenWidth()),
                @floatFromInt(rl.getScreenHeight()),
            );
        }
        borderless = !borderless;
        rl.toggleBorderlessWindowed();
    }

    pub fn toggleFullscreen() void {
        if (fullscreen) {
            resize(rl.Vector2.init(1280, 720));
        } else {
            size = rl.Vector2.init(
                @floatFromInt(rl.getScreenWidth()),
                @floatFromInt(rl.getScreenHeight()),
            );
        }
        fullscreen = !fullscreen;
        rl.toggleFullscreen();
    }
};

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
    rl.setTraceLogLevel(.log_error);
    defer rl.setTraceLogLevel(.log_debug);

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.white);

    var KIt = ecs.entities.keyIterator();

    while (KIt.next()) |key| {
        var entity = ecs.getEntity(key.*).?.*;
        var prev: *Previous = undefined;

        // var flag: bool = false;

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

        // if (prev.transform) |ptransform| {
        //     if (transform.rotation.equals(ptransform.rotation) == 0 or
        //         transform.scale.equals(ptransform.scale) == 0)
        //     {
        //         prev.transform = transform;
        //         flag = true;
        //     }
        // } else {flag = true;}

        // if (prev.display) |pdisplay| {
        //     if (!z.arrays.StringEqual(
        //         display.sprite,
        //         pdisplay.sprite,
        //     )) {
        //         prev.display = display;
        //         flag = true;
        //     }
        // } else flag = true;

        // if (prev.texture) |_texture| {
        //     if (!flag) {
        //         texture = _texture;
        //     } else {
        //         rl.unloadTexture(_texture);
        //     }
        // } else flag = true;

        // if (!flag) {
        //     drawTetxure(texture, transform.position, rl.Color.white);
        //     continue;
        // }

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

        // rl.imageRotate(
        //     &img,
        //     @intFromFloat(transform.rotation.z),
        // );

        rl.unloadTexture(texture);
        texture = rl.loadTextureFromImage(img);
        prev.texture = texture;
        // defer rl.unloadTexture(texture);
        drawTetxure(texture, transform, display.tint);
    }
}

fn drawTetxure(texture: rl.Texture, trnsfrm: ecs.cTransform, tint: rl.Color) void {
    var x = z.math.div(window.size.x, 2).?;
    x += z.math.to_f128(trnsfrm.position.x).?;
    x -= z.math.to_f128(camera.position.x).?;
    x -= z.math.div(trnsfrm.scale.x * camera.zoom, 2).?;

    var y = z.math.div(window.size.y, 2).?;
    y += z.math.to_f128(trnsfrm.position.y).?;
    y -= z.math.to_f128(camera.position.y).?;
    y -= z.math.div(trnsfrm.scale.y * camera.zoom, 2).?;

    const ix = z.math.f128_to(f32, x).?;
    const iy = z.math.f128_to(f32, y).?;

    var origin: ?rl.Vector2 = trnsfrm.anchor;
    if (origin == null) {
        origin = rl.Vector2.init(0, 0);
    }

    // rl.drawRectanglePro(
    //     rl.Rectangle.init(ix, iy, trnsfrm.scale.x, trnsfrm.scale.y),
    //     origin.?,
    //     trnsfrm.rotation.z,
    //     rl.Color.light_gray,
    // );

    rl.drawTexturePro(
        texture,
        rl.Rectangle.init(0, 0, trnsfrm.scale.x, trnsfrm.scale.y),
        rl.Rectangle.init(ix, iy, trnsfrm.scale.x, trnsfrm.scale.y),
        origin.?,
        trnsfrm.rotation.z,
        tint,
    );

    // rl.drawLine(
    //     @intFromFloat(ix),
    //     @intFromFloat(iy),
    //     @intFromFloat(ix - origin.?.x),
    //     @intFromFloat(iy - origin.?.y),
    //     rl.Color.yellow,
    // );

    // rl.drawCircle(@intFromFloat(ix), @intFromFloat(iy), 2, rl.Color.purple);
    // rl.drawCircle(@intFromFloat(ix - origin.?.x), @intFromFloat(iy - origin.?.y), 2, rl.Color.red);
}
