const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub fn HeapManager(comptime T: type, comptime freeId: ?*const fn (Allocator, *T) anyerror!void) type {
    return struct {
        var array: std.ArrayList(*T) = undefined;
        pub var alloc: Allocator = undefined;

        pub fn init(allocator: Allocator) !void {
            alloc = allocator;

            array = std.ArrayList(*T).init(alloc);
        }

        pub fn deinit() void {
            for (array.items) |it| {
                alloc.destroy(it);
            }
            array.deinit();
        }

        pub fn append(item: T) !void {
            const ptr = try alloc.create(T);
            ptr.* = item;

            try array.append(ptr);
        }

        pub fn remove(item: *T) void {
            for (array.items, 0..) |it, index| {
                if (!std.meta.eql(item.*, it.*)) continue;
                alloc.destroy(it);
                _ = array.swapRemove(index);
                return;
            }
        }

        pub fn removeFreeId(item: *T) void {
            for (array.items, 0..) |it, index| {
                if (!std.meta.eql(item.*, it.*)) continue;

                if (freeId) |func| {
                    func(alloc, item) catch {
                        std.log.err("An error occured in removeFreeId", .{});
                    };
                }

                alloc.destroy(it);
                _ = array.swapRemove(index);
                return;
            }
        }

        /// Caller owns the returned memory!
        pub fn items() ![]*T {
            var copy = try array.clone();

            return copy.toOwnedSlice();
        }

        pub fn len() usize {
            return array.items.len;
        }
    };
}
