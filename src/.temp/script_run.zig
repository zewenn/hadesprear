const Import = @import("./imports.zig").Import;

const sc = Import(.scenes);

pub fn register() !void {
	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/background.zig").awake,
		.eInit = @import("../app/[default]/background.zig").init,
		.eUpdate = @import("../app/[default]/background.zig").update,
		.eDeinit = @import("../app/[default]/background.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/projectiles.zig").awake,
		.eInit = @import("../app/[default]/projectiles.zig").init,
		.eUpdate = @import("../app/[default]/projectiles.zig").update,
		.eDeinit = @import("../app/[default]/projectiles.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/dashing.zig").awake,
		.eInit = @import("../app/[default]/dashing.zig").init,
		.eUpdate = @import("../app/[default]/dashing.zig").update,
		.eDeinit = @import("../app/[default]/dashing.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/enemies.zig").awake,
		.eInit = @import("../app/[default]/enemies.zig").init,
		.eUpdate = @import("../app/[default]/enemies.zig").update,
		.eDeinit = @import("../app/[default]/enemies.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/box.zig").awake,
		.eInit = @import("../app/[default]/box.zig").init,
		.eUpdate = @import("../app/[default]/box.zig").update,
		.eDeinit = @import("../app/[default]/box.zig").deinit,
	});	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/player.zig").awake,
		.eInit = @import("../app/[default]/player.zig").init,
		.eUpdate = @import("../app/[default]/player.zig").update,
		.eDeinit = @import("../app/[default]/player.zig").deinit,
	});
}