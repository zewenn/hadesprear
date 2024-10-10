const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const rl = @import("raylib");

const components = @import("components.zig");

pub const Transform = components.Transform;
pub const Display = components.Display;
pub const Collider = components.Collider;
pub const CachedDisplay = components.CachedDisplay;
pub const RectangleVertices = components.RectangleVertices;

const EntityTypeError = error{
    TypeMustBeStruct,
    NoIdField,
    NoTagsField,
    NoTransformField,
    NoDisplayField,
    NoColliderField,
    NoCachedDisplayField,
};

/// `T` is the type all entities must match.
/// This type must have all internal fields since
/// otherwise some engine modules won't work
/// *(if the type does not have these fields and error
/// will be returned)*.
pub fn make(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct) @compileError("Type must be struct");

        var id_flag = false;
        var tags_flag = false;
        var transform_flag = false;
        var display_flag = false;
        var collider_flag = false;
        var cached_display_flag = false;
        var cached_collider = false;

        const fields = std.meta.fields(T);

        for (fields) |field| {
            if (std.mem.eql(u8, field.name, "id")) id_flag = true;
            if (std.mem.eql(u8, field.name, "tags")) tags_flag = true;
            if (std.mem.eql(u8, field.name, "transform")) transform_flag = true;
            if (std.mem.eql(u8, field.name, "display")) display_flag = true;
            if (std.mem.eql(u8, field.name, "collider")) collider_flag = true;
            if (std.mem.eql(u8, field.name, "cached_display")) cached_display_flag = true;
            if (std.mem.eql(u8, field.name, "cached_collider")) cached_collider = true;
        }

        if (!id_flag) @compileError("Entity type must have field: \"id\"");
        if (!tags_flag) @compileError("Entity type must have field: \"tags\"");
        if (!transform_flag) @compileError("Entity type must have field: \"transform\"");
        if (!display_flag) @compileError("Entity type must have field: \"display\"");
        if (!collider_flag) @compileError("Entity type must have field: \"collider\"");
        if (!cached_display_flag) @compileError("Entity type must have field: \"cached_display\"");
        if (!cached_collider) @compileError("Entity type must have field: \"cached_collider\"");
    }

    return struct {
        pub const Entity = T;

        pub const Transform = components.Transform;
        pub const Display = components.Display;
        pub const Collider = components.Collider;
        pub const CachedDisplay = components.CachedDisplay;
        pub const RectangleVertices = components.RectangleVertices;

        const EntityArrayType = std.ArrayList(*Entity);

        var entities: EntityArrayType = undefined;
        pub var alloc: Allocator = undefined;

        pub fn init(allocator: *Allocator) void {
            alloc = allocator.*;

            entities = EntityArrayType.init(alloc);
        }

        pub fn deinit() void {
            entities.deinit();
        }

        pub fn get(id: []const u8) ?*Entity {
            for (entities.items) |item| {
                if (std.mem.eql(u8, item.id, id)) return item;
            }
            return null;
        }

        /// Caller owns the returned memory.
        /// Returns all entities with the given tag.
        pub fn search(tag: []const u8) ![]*Entity {
            var list = EntityArrayType.init(alloc);
            defer list.deinit();

            for (entities.items) |item| {
                if (std.mem.containsAtLeast(
                    u8,
                    item.id,
                    1,
                    tag,
                )) try list.append(item);
            }
            return try list.toOwnedSlice();
        }

        /// Caller owns the returned memory.
        /// Returns all entities without the given tag.
        pub fn searchExclude(tag: []const u8) ![]*Entity {
            var list = EntityArrayType.init(alloc);
            defer list.deinit();

            for (entities.items) |item| {
                if (!std.mem.containsAtLeast(
                    u8,
                    item.tags,
                    1,
                    tag,
                )) try list.append(item);
            }
            return try list.toOwnedSlice();
        }

        /// Caller owns the returned memory
        pub fn all() ![]*Entity {
            var list = try entities.clone();
            defer list.deinit();

            return try list.toOwnedSlice();
        }

        pub fn exists(id: []const u8) bool {
            if (get(id) != null) return true;
            return false;
        }

        pub fn register(entity: *Entity) !void {
            try entities.append(entity);
        }

        pub fn delete(id: []const u8) void {
            for (entities.items, 0..) |item, i| {
                if (!std.mem.eql(u8, item.id, id)) continue;

                _ = entities.orderedRemove(i);
                return;
            }
        }

        pub fn clear() void {
            entities.clearAndFree();
        }

        /// **IMPORTANT**:
        /// You **need** to use this with heap allocated ids,
        /// since `.free()` will try to free the id of the object!
        pub fn Manager(comptime options: struct {
            max_size: usize = 8_000_000,
            max_entities: ?usize = null,
        }) type {
            return struct {
                pub const EntitySize: comptime_int = @sizeOf(Entity);
                pub const MaxArraySize: comptime_int = @divTrunc(options.max_size, EntitySize);
                pub const ArraySize: comptime_int = if (options.max_entities) |max| @min(max, MaxArraySize) else MaxArraySize;
                pub var array: [ArraySize]?Entity = [_]?Entity{null} ** ArraySize;

                /// This will search for the next free *(value == null)*
                /// index in the array and return it.
                /// If there are no available indexes in the array and override is:
                /// - **false**: it will override the 0th address.
                /// - **true**: it will randomly return an address.
                pub fn searchNextIndex(override: bool) usize {
                    for (array, 0..) |value, index| {
                        if (index == 0) continue;
                        if (value == null) return index;
                    }

                    // No null, everything is used...

                    // This saves your ass 1 time
                    if (!override) {
                        array[0] = null;
                        return 0;
                    }

                    const rIndex = std.crypto.random.uintLessThan(usize, ArraySize);

                    if (array[rIndex]) |_| {
                        free(rIndex);
                    }

                    array[rIndex] = null;
                    return rIndex;
                }

                /// Uses the `searchNextIndex()` function to get an index
                /// and puts the value into it
                pub fn malloc(value: Entity) void {
                    const index = searchNextIndex(true);
                    array[index] = value;
                }

                /// Sets the value of the index to `null`
                pub fn free(index: usize) void {
                    var value = array[index];

                    if (value == null) return;

                    value.?.freeRaylibStructs();
                    if (exists(value.?.id)) {
                        _ = delete(value.?.id);
                    }
                    alloc.free(value.?.id);

                    array[index] = null;
                }
            };
        }
    };
}
