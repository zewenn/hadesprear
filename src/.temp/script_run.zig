const Import = @import("./imports.zig").Import;

const sc = Import(.scenes);

pub fn register() !void {
	try sc.register("default", sc.Script{
		.eAwake = @import("../app/[default]/testing.zig").awake,
		.eInit = @import("../app/[default]/testing.zig").init,
		.eUpdate = @import("../app/[default]/testing.zig").update,
		.eDeinit = @import("../app/[default]/testing.zig").deinit,
	});
}