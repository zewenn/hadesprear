const std = @import("std");
const rlz = @import("raylib-zig");
const Allocator = @import("std").mem.Allocator;
const String = @import("./libs/zig-string.zig").String;

pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    filenames: {
        const files_dir = "./src/assets/";
        const output_file = std.fs.cwd().createFile(
            "src/.temp/filenames.zig",
            .{
                .truncate = true,
                .exclusive = false,
            },
        ) catch unreachable;

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
        break :filenames;
    }
    // Handling Scenes & Scripts
    scenes: {
        const output_file = std.fs.cwd().createFile(
            "src/.temp/script_run.zig",
            .{
                .truncate = true,
                .exclusive = false,
            },
        ) catch unreachable;

        var writer = output_file.writer();
        writer.writeAll("") catch unreachable;
        _ = writer.write("const sc = @import(\"../engine/scenes.zig\");\n\n") catch unreachable;
        _ = writer.write("pub fn register() !void {\n") catch unreachable;

        var files_dirs = getEntries("./src/app/", &allocator);
        defer {
            for (files_dirs.items) |files_dir| {
                allocator.free(files_dir);
            }
            files_dirs.deinit();
        }

        for (files_dirs.items) |files_dir| {
            const scene_name = files_dir[1 .. files_dir.len - 1];

            var Sfiles_fir = String.init_with_contents(allocator, files_dir) catch unreachable;
            defer Sfiles_fir.deinit();

            if (!Sfiles_fir.startsWith("[") or !Sfiles_fir.endsWith("]")) continue;

            var Ssub_path = String.init_with_contents(allocator, "./src/app/") catch unreachable;
            defer Ssub_path.deinit();

            Ssub_path.concat(files_dir) catch unreachable;

            const sub_path = (Ssub_path.toOwned() catch unreachable).?;
            defer allocator.free(sub_path);

            const dir = std.fs.cwd().openDir(
                sub_path,
                .{
                    .iterate = true,
                },
            ) catch unreachable;

            var it = dir.iterate();

            while (it.next() catch unreachable) |entry| {
                if (entry.kind != .file) continue;

                var spath = Ssub_path.clone() catch unreachable;
                defer spath.deinit();

                spath.concat("/") catch unreachable;
                spath.concat(entry.name) catch unreachable;

                const file_sub = (spath.toOwned() catch unreachable).?;
                defer allocator.free(file_sub);

                // _ = writer.write(entry.name) catch unreachable;

                const file = std.fs.cwd().openFile(file_sub, .{}) catch unreachable;
                defer file.close();

                // Max buffer size is 128MB
                const contents_u8 = file.readToEndAlloc(allocator, 1024000000) catch |err| switch (err) {
                    error.FileTooBig => @panic("Maximum file size exceeded"),
                    else => @panic("Failed to read file"),
                };
                defer allocator.free(contents_u8);

                var Scontents = String.init_with_contents(allocator, contents_u8) catch unreachable;
                defer Scontents.deinit();

                writer.print("\ttry sc.register(\"{s}\", sc.Script", .{scene_name}) catch unreachable;
                _ = writer.write("{\n") catch unreachable;

                if (Scontents.find("\npub fn awake(") != null) {
                    writer.print(
                        "\t\t.eAwake = @import(\"../app/{s}/{s}\").awake,\n",
                        .{ files_dir, entry.name },
                    ) catch unreachable;
                }
                if (Scontents.find("\npub fn init(") != null) {
                    writer.print(
                        "\t\t.eInit = @import(\"../app/{s}/{s}\").init,\n",
                        .{ files_dir, entry.name },
                    ) catch unreachable;
                }
                if (Scontents.find("\npub fn update(") != null) {
                    writer.print(
                        "\t\t.eUpdate = @import(\"../app/{s}/{s}\").update,\n",
                        .{ files_dir, entry.name },
                    ) catch unreachable;
                }
                if (Scontents.find("\npub fn deinit(") != null) {
                    writer.print(
                        "\t\t.eDeinit = @import(\"../app/{s}/{s}\").deinit,\n",
                        .{ files_dir, entry.name },
                    ) catch unreachable;
                }

                _ = writer.write("\t});") catch unreachable;
            }

            //try e.scenes.register("default", e.scenes.Script{
            //     .eAwake = player_script.awake,
            // });

        }
        _ = writer.write("\n}") catch unreachable;
        break :scenes;
    }

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

/// Caller owns the returned memory.
fn getEntries(files_dir: []const u8, alloc: *Allocator) std.ArrayList([]const u8) {
    var dir = std.fs.cwd().openDir(files_dir, .{ .iterate = true }) catch unreachable;
    defer dir.close();

    var result = std.ArrayList([]const u8).init(alloc.*);

    var it = dir.iterate();
    while (it.next() catch unreachable) |*entry| {
        if (entry.kind != .directory) continue;
        const copied = alloc.alloc(u8, entry.name.len) catch unreachable;

        for (copied, entry.name) |*l, l2| {
            l.* = l2;
        }
        result.append(copied) catch unreachable;
    }

    return result;
}
