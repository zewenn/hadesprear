const Import = @import("./imports.zig").Import;

const sc = Import(.scenes);

pub fn register() !void {
	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/background.zig").awake,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/box2.zig").awake,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/box.zig").awake,
	});	try sc.register("game", sc.Script{
		.eAwake = @import("../app/[game]/player.zig").awake,
		.eInit = @import("../app/[game]/player.zig").init,
		.eUpdate = @import("../app/[game]/player.zig").update,
		.eDeinit = @import("../app/[game]/player.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/main.zig").awake,
		.eInit = @import("../app/[default]/main.zig").init,
		.eUpdate = @import("../app/[default]/main.zig").update,
		.eDeinit = @import("../app/[default]/main.zig").deinit,
	});
}