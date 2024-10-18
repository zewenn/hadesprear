const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

pub const EffectShower = struct {
    entity: e.Entity,
    animator: e.Animator = undefined,
};

const manager = e.zlib.HeapManager(EffectShower, (struct {
    pub fn callback(alloc: Allocator, item: *EffectShower) !void {
        e.entities.delete(item.entity.id);

        alloc.free(item.entity.id);
        alloc.free(item.entity.effect_shower_stats.?.bound_entity_id);
        item.entity.deinit();

        item.animator.deinit();
    }
}).callback);

pub fn awake() !void {
    manager.init(e.ALLOCATOR);
}

pub fn init() !void {}

pub fn update() !void {
    const entities = try e.entities.all();
    defer e.entities.alloc.free(entities);

    try setKeepAlive(false);

    EntityLoop: for (entities) |entity| {
        const estats: *conf.EntityStats = if (entity.entity_stats) |*t| t else continue;
    
        if (!(estats.is_invalnureable or
            estats.is_slowed or
            estats.is_rooted or
            estats.is_stunned or
            estats.is_asleep or
            estats.is_healing))
            continue;

        const items = try manager.items();
        defer manager.alloc.free(items);

        for (items) |item| {
            defer item.animator.update();
            if (!std.mem.eql(u8, entity.id, item.entity.effect_shower_stats.?.bound_entity_id)) continue;

            try setShowerTo(&(item.entity), entity, &(item.animator));

            continue :EntityLoop;
        }

        // No matches found so far

        const new_item = try new(entity.id);

        try setShowerTo(&(new_item.entity), entity, &(new_item.animator));
    }

    try removeDead();
}

pub fn deinit() !void {
    manager.deinit();
}

pub fn new(entity_id: []const u8) !*EffectShower {
    const id = try e.UUIDV7();

    const New = e.entities.Entity{
        .id = id,
        .tags = "projectile",
        .transform = .{},
        .display = .{
            .scaling = .pixelate,
            .sprite = e.MISSINGNO,
        },
        .effect_shower_stats = .{
            .bound_entity_id = try e.ALLOCATOR.dupe(u8, entity_id),
        },
    };

    const NewPtr = try manager.appendReturn(EffectShower{
        .entity = New,
    });

    var Animator = e.Animator.init(&e.ALLOCATOR, &(NewPtr.entity));
    {
        var invlunerable_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "invulnerable_anim",
            e.Animator.interpolation.lerp,
            0.45,
        );
        {
            invlunerable_anim.chain(
                0,
                .{
                    // Used to modify position.y
                    .d1f32 = 0,
                    .sprite = "sprites/effects/invulnerable/anim_0.png",
                },
            );
            invlunerable_anim.chain(
                1,
                .{
                    // Used to modify position.y
                    .d1f32 = -8,
                    .sprite = "sprites/effects/invulnerable/anim_1.png",
                },
            );
            invlunerable_anim.chain(
                2,
                .{
                    // Used to modify position.y
                    .d1f32 = -16,
                    .sprite = "sprites/effects/invulnerable/anim_2.png",
                },
            );
            invlunerable_anim.chain(
                3,
                .{
                    // Used to modify position.y
                    .d1f32 = 0,
                    .sprite = "sprites/effects/invulnerable/anim_3.png",
                },
            );

            invlunerable_anim.chain(
                4,
                .{
                    // Used to modify position.y
                    .d1f32 = 8,
                    .sprite = "sprites/effects/invulnerable/anim_4.png",
                },
            );
            invlunerable_anim.chain(
                5,
                .{
                    // Used to modify position.y
                    .d1f32 = 0,
                    .sprite = "sprites/effects/invulnerable/anim_5.png",
                },
            );
        }
        try Animator.chain(invlunerable_anim);

        var healing_anim = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "healing_anim",
            e.Animator.interpolation.lerp,
            0.45,
        );
        {
            healing_anim.chain(
                0,
                .{
                    // Used to modify position.y
                    .d1f32 = 0,
                    .sprite = "sprites/effects/healing/anim_0.png",
                },
            );
            healing_anim.chain(
                1,
                .{
                    // Used to modify position.y
                    .d1f32 = -8,
                    .sprite = "sprites/effects/healing/anim_1.png",
                },
            );
            healing_anim.chain(
                2,
                .{
                    // Used to modify position.y
                    .d1f32 = 0,
                    .sprite = "sprites/effects/healing/anim_0.png",
                },
            );
        }
        try Animator.chain(healing_anim);
    }

    NewPtr.animator = Animator;

    try e.entities.register(&(NewPtr.entity));

    return NewPtr;
}

pub fn setKeepAlive(to: bool) !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        // Removing junk if it somehow ended up in the manager

        if (item.entity.effect_shower_stats == null) {
            manager.remove(item);
            continue;
        }

        item.entity.effect_shower_stats.?.keep_alive = to;
    }
}

pub fn removeDead() !void {
    const items = try manager.items();
    defer manager.alloc.free(items);

    for (items) |item| {
        // Removing junk if it somehow ended up in the manager

        if (item.entity.effect_shower_stats == null) {
            manager.remove(item);
            continue;
        }

        if (item.entity.effect_shower_stats.?.keep_alive) continue;

        manager.removeFreeId(item);
    }
}

fn setShowerTo(item: *e.Entity, entity: *e.Entity, animator: *e.Animator) !void {
    item.transform.position = entity.transform.position;
    item.effect_shower_stats.?.keep_alive = true;

    const istats: *conf.EntityStats = if (entity.entity_stats) |*i| i else return;

    if (istats.is_invalnureable) {
        if (!animator.isPlaying("invulnerable_anim")) {
            try animator.play("invulnerable_anim");
        }
        // item.display.sprite = "sprites/effects/invulnerable/anim_0.png";
    }
    else if (istats.is_healing) {
        if (!animator.isPlaying("healing_anim")) {
            try animator.play("healing_anim");
        }
        // item.display.sprite = "sprites/effects/invulnerable/anim_0.png";
    }
}
