//! Copyright (c) 2024-2025 Theodore Sackos
//! SPDX-License-Identifier: MIT
//!
//! The LuaJIT project has some expectations that Windows users build LuaJIT using the MSVC toolchain
//! or rely on MinGW to get a Linux-like build on Windows. LuaJIT uses a `dynasm.lua` script to dynamically
//! generate some content during build time, and those files include references to files with line numbers.
//! The file references, in generated header files, include Windows paths -- which break when Zig attempts
//! to compile them. As a result, this application "patches" the `dynasm.lua` script to produce Linux-flavored
//! path separators, which Zig handles gracefully. As far as I can tell, windows paths are non-standard anyway.

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

    var inputFile = try std.fs.cwd().openFile(args[1], .{});
    defer inputFile.close();

    var outputFile = try std.fs.cwd().createFile(args[2], .{});
    defer outputFile.close();

    var read_buffer: [16 * 1024]u8 = undefined;
    var reader = inputFile.reader(&read_buffer);

    var write_buffer: [16 * 1024]u8 = undefined;
    var writer = outputFile.writer(&write_buffer);

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

    while (reader.interface.takeDelimiterInclusive('\n')) |line| {
        if (std.mem.indexOf(u8, line, target)) |_| {
            _ = try writer.interface.write(replacement);
        } else {
            _ = try writer.interface.write(line);
            _ = try writer.interface.write("\n");
        }
    } else |err| blk: {
        switch (err) {
            error.EndOfStream => break :blk,
            error.ReadFailed => @panic("ERROR [ReadFailed] when reading lines to patch dynasm for platform-specific differences"),
            error.StreamTooLong => @panic("ERROR [StreamTooLong] when reading lines to patch dynasm for platform-specific differences"),
        }
    }

    try writer.interface.flush();
}
