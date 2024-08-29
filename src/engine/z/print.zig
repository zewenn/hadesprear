const std = @import("std");

pub fn print(comptime msg: []const u8, args: anytype) void {
    std.debug.print(msg, args);
}

pub fn println(comptime msg: []const u8, args: anytype) void {
    print(msg ++ "\n", args);
}

pub fn dprint(comptime msg: []const u8, args: anytype) void {
    print(
        "\n=========================================\n\n" ++ msg ++ "\n\n=========================================\n\n",
        args,
    );
}
