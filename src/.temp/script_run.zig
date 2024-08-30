const sc = @import("../engine/scenes.zig");

pub fn register() !void {
	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/player.zig").awake,
		.eInit = @import("../app/[default]/player.zig").init,
		.eUpdate = @import("../app/[default]/player.zig").update,
		.eDeinit = @import("../app/[default]/player.zig").deinit,
	});
}