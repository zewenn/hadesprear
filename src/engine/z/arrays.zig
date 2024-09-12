const std = @import("std");

pub fn Array(comptime T: type, comptime len: usize, comptime val: [len]T) type {
    return struct {
        const Self = @This();

        pub inline fn this() [len]T {
            return val;
        }

        pub fn index(elem: T) ?usize {
            for (val, 0..len) |item, i| {
                if (elem == item) return i;
                if (@as(*anyopaque, @ptrCast(@constCast(&elem))) == @as(*anyopaque, @ptrCast(@constCast(&item)))) {
                    return i;
                }
            }
            return null;
        }

        pub fn at(i: usize) T {
            return val[i];
        }
    };
}

pub fn StringEqual(string1: []const u8, string2: []const u8) bool {
    if (string1.len != string2.len) return false;

    for (string1, string2) |l1, l2| {
        if (l1 != l2) return false;
    }

    return true;
}

pub const Direction = enum { up, down, left, right };

pub fn SearchMatrixForNext(
    comptime T: type,
    comptime W: usize,
    comptime H: usize,
    matrix: [H][W]?T,
    towards: Direction,
    x: usize,
    y: usize,
) [2]usize {
    // Creating the constants used...
    if (matrix.len == 0) return [2]usize{ 0, 0 };

    const matrix_width = W;
    const matrix_height = H;

    // We will need to extract a slice to search in
    // -> with vertical directions this will be `matrix[y + 1 ..]`
    // -> the tricky part is the horizontal slices, as `matrix[0..][x + 1..]`

    var x_min: usize = 0;
    var x_max: usize = 0;
    var y_min: usize = 0;
    var y_max: usize = 0;

    switch (towards) {
        .up => {
            x_min = 0;
            x_max = matrix_width;
            y_min = 0;
            y_max = if (y == 0) 0 else y;
        },
        .down => {
            x_min = 0;
            x_max = matrix_width;
            y_min = y + 1;
            y_max = matrix_height;
        },
        .left => {
            x_min = 0;
            x_max = if (x == 0) 0 else x;
            y_min = 0;
            y_max = matrix_height;
        },
        .right => {
            x_min = x + 1;
            x_max = matrix_width;
            y_min = 0;
            y_max = matrix_height;
        },
    }

    // how many directional matrix slices to look through
    // 0 is the starting middle slice
    // each increment increases the look scope by 1 towards both ends
    for (0..@min(matrix_width, matrix_height)) |scope| {
        const scope_x = switch (towards) {
            .up, .down => scope,
            .left, .right => matrix_width,
        };
        const scope_y = switch (towards) {
            .up, .down => matrix_height,
            .left, .right => scope,
        };

        for (y_min..y_max) |y_range_index| {
            if (y_range_index < (y - @min(y, scope_y)) or
                y_range_index > (y + @min(y_max - @min(y_max, y), scope_y)))
            {
                continue;
            }

            for (x_min..x_max) |x_range_index| {
                if (x_range_index < (x - @min(x, scope_x)) or
                    x_range_index > (x + @min(x_max - @min(x_max, x), scope_x)))
                {
                    continue;
                }

                if (matrix[y_range_index][x_range_index] != null) return [2]usize{ x_range_index, y_range_index };
            }
        }
    }

    return [2]usize{ x, y };
}
