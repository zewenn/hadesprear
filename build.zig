const std = @import("std");
const rlz = @import("raylib-zig");
const Allocator = @import("std").mem.Allocator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    //web exports are completely separate
    if (target.query.os_tag == .emscripten) {
        const exe_lib = rlz.emcc.compileForEmscripten(b, "testproj", "src/main.zig", target, optimize);

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);

        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run testproj");
        run_option.dependOn(&run_step.step);
        return;
    }

    const exe = b.addExecutable(.{
        .name = "testproj",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run testproj");
    run_step.dependOn(&run_cmd.step);

    // Automatic file "import"
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        var allocator = gpa.allocator();

        const files_dir = "./src/assets/";
        const output_file = std.fs.cwd().createFile("src/.temp/filenames.zig", .{}) catch unreachable;

        const seg = generateFileNames(files_dir, &allocator);
        defer {
            for (seg.list.items) |item| {
                seg.alloc.free(item);
            }
            seg.list.deinit();
        }

        var writer = output_file.writer();
        writer.writeAll("") catch unreachable;
        _ = writer.write("pub const Filenames = [_][]const u8{\n") catch unreachable;
        for (seg.list.items, 0..seg.list.items.len) |item, i| {
            if (i == 0) {
                _ = writer.write("\t\"") catch unreachable;
            } else {
                _ = writer.write("\",\n\t\"") catch unreachable;
            }
            writer.print("{s}", .{item}) catch unreachable;
            if (i == seg.list.items.len - 1) {
                _ = writer.write("\"") catch unreachable;
            }
        }
        _ = writer.write("\n};") catch unreachable;
    }
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        var allocator = gpa.allocator();

        const files_dir = "./src/.scripts/";
        const output_file = std.fs.cwd().createFile("src/.temp/script_run.zig", .{}) catch unreachable;

        const seg = generateFileNames(files_dir, &allocator);
        defer {
            for (seg.list.items) |item| {
                seg.alloc.free(item);
            }
            seg.list.deinit();
        }

        var writer = output_file.writer();
        writer.writeAll("") catch unreachable;
        _ = writer.write("pub fn register() !void {\n") catch unreachable;
        for (seg.list.items) |item| {
            writer.print("\ttry @import(\"../.scripts/{s}\").main();\n", .{item}) catch unreachable;
        }
        _ = writer.write("}") catch unreachable;
    }

    b.installArtifact(exe);
}

const Segment = struct {
    alloc: std.mem.Allocator,
    list: std.ArrayListAligned([]const u8, null),
};

fn generateFileNames(files_dir: []const u8, alloc: *Allocator) Segment {
    var dir = std.fs.cwd().openDir(files_dir, .{ .iterate = true }) catch unreachable;
    defer dir.close();

    var result = std.ArrayList([]const u8).init(alloc.*);

    var it = dir.iterate();
    while (it.next() catch unreachable) |*entry| {
        const copied = alloc.*.alloc(u8, entry.name.len) catch unreachable;

        for (copied, entry.name) |*l, l2| {
            l.* = l2;
        }

        if (entry.*.kind == .file) {
            result.append(copied) catch unreachable;
        }
    }

    return Segment{
        .alloc = alloc.*,
        .list = result,
    };
}
