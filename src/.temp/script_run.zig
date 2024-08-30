const e = @import("../engine/engine.zig");

pub fn register() !void {
	try e.events.on(.Awake, @import("../.scripts/player.zig").awake);
	try e.events.on(.Init, @import("../.scripts/player.zig").init);
	try e.events.on(.Update, @import("../.scripts/player.zig").update);
	try e.events.on(.Deinit, @import("../.scripts/player.zig").deinit);
}