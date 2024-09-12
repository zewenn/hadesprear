const InternalLibrarires = enum {
	collision,
	z,
	ecs,
	animator,
	events,
	input,
	time,
	scenes,
	gui,
	display,
	engine,
	assets,
};
pub inline fn Import(comptime lib: InternalLibrarires) type {
	return switch (lib) {
		.collision => @import("../../src/engine/collision.m.zig"),
		.z => @import("../../src/engine/z/z.m.zig"),
		.ecs => @import("../../src/engine/ecs/ecs.m.zig"),
		.animator => @import("../../src/engine/animator/animator.m.zig"),
		.events => @import("../../src/engine/events.m.zig"),
		.input => @import("../../src/engine/input.m.zig"),
		.time => @import("../../src/engine/time.m.zig"),
		.scenes => @import("../../src/engine/scenes.m.zig"),
		.gui => @import("../../src/engine/gui/gui.m.zig"),
		.display => @import("../../src/engine/display/display.m.zig"),
		.engine => @import("../../src/engine/engine.m.zig"),
		.assets => @import("../../src/engine/assets.m.zig"),
	};

}
