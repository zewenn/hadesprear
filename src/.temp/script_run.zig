pub fn register() !void {
	try @import("../.scripts/player.zig").main();
}