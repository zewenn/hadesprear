
const std = @import("std");

pub fn print(comptime msg: []const u8, args: anytype) void {
    std.debug.print(msg, args);
}

pub fn println(comptime msg: []const u8, args: anytype) void {
    print(msg ++ "\n", args);
}