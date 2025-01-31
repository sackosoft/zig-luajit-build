const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        if (gpa.deinit() != .ok) {
            std.debug.print("GPA: Leak detected.\n", .{});
            std.process.exit(1);
        }
    }

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len != 3) {
        std.debug.print("Usage: `{s} <path-to-dynasm.lua> <path-to-fixed-file-to-create>`\n", .{@typeName(@This())});
        std.process.exit(1);
    }

    var input = try std.fs.cwd().openFile(args[1], .{});
    defer input.close();

    var output = try std.fs.cwd().createFile(args[2], .{});
    defer output.close();

    var line_buffer: [256 * 1024]u8 = undefined;
    var reader = input.reader();

    // This seems to be the source of the problem building LuaJIT on windows using Zig.
    // The `g_fname` is written as windows file paths `C:\Users\Example\...`. The LuaJIT maintainers expect
    // Windows builds to be run with MSVC (which seems to support these nonstandard paths), but the Zig toolchain
    // cannot handle it.
    // https://github.com/LuaJIT/LuaJIT/blob/a4f56a459a588ae768801074b46ba0adcfb49eb1/dynasm/dynasm.lua#L88C5-L88C50
    const target = (
        \\wline("#line "..g_lineno..' "'..g_fname..'"')
    );

    // Instead, we will replace it with the appropriate Lua to normalize the paths back to forward slash separators.
    const replacement = (
        \\wline("#line "..g_lineno..' "'..g_fname:gsub("\\", "/")..'"')
    );

    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        if (std.mem.indexOf(u8, line, target)) |_| {
            _ = try output.write(replacement);
        } else {
            _ = try output.write(line);
            _ = try output.write("\n");
        }
    }
}
