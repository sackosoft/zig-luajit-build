//! Copyright (c) 2024-2025 Theodore Sackos
//! SPDX-License-Identifier: MIT
//!
//! This file demonstrates using the native C API to implement a primitive Read-Evaluatate-Print (REPL) loop. The user
//! is prompted to LuaJIT code as input, it's executed in the LuaJIT runtime and the results from the evaluation are
//! printed as output.

const std = @import("std");

// The LuaJIT C API
const c = @import("c");

pub fn main() !void {
    var alloc = std.heap.page_allocator;

    const ud = try alloc.create(std.mem.Allocator);
    defer alloc.destroy(ud);
    ud.* = alloc;

    const L: *c.lua_State = @ptrCast(c.lua_newstate(NativeAllocator.alloc, ud));
    defer c.lua_close(L);

    c.luaL_openlibs(L);

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var line_buffer: [1025]u8 = undefined;

    while (true) {
        try stdout.writeAll("> ");
        try stdout.flush();

        var line_writer = std.Io.Writer.fixed(&line_buffer);
        const input_len = try stdin.streamDelimiterLimit(&line_writer, '\n', std.Io.Limit.limited(1024));
        if (input_len == 0) continue;

        // Throw away the `\n` on the input.
        stdin.toss(1);

        // Replace the `\n` terminated string with a null terminated (`\0`) string.
        line_buffer[input_len] = '\u{0}';
        const input = line_buffer[0 .. input_len + 1];

        if (std.mem.eql(u8, input[0..4], "exit")) break;
        if (std.mem.eql(u8, input[0..4], "quit")) break;

        if (c.luaL_dostring(L, input.ptr)) {
            var len: usize = undefined;
            const s = c.lua_tolstring(L, -1, &len);
            std.debug.print("Error: {s}\n", .{s});
            continue;
        }
    }
}

const max_alignment: std.mem.Alignment = std.mem.Alignment.of(std.c.max_align_t);
const max_alignment_bytes: usize = std.mem.Alignment.toByteUnits(max_alignment);
const NativeAllocator = struct {
    fn alloc(ud: ?*anyopaque, ptr: ?*anyopaque, osize: usize, nsize: usize) callconv(.c) ?*align(max_alignment_bytes) anyopaque {
        const allocator: *std.mem.Allocator = @ptrCast(@alignCast(ud.?));
        const aligned_ptr = @as(?[*]align(max_alignment_bytes) u8, @ptrCast(@alignCast(ptr)));
        if (aligned_ptr) |p| {
            if (nsize != 0) {
                const old_mem = p[0..osize];
                return (allocator.realloc(old_mem, nsize) catch return null).ptr;
            }

            allocator.free(p[0..osize]);
            return null;
        } else {
            // Malloc case
            return (allocator.alignedAlloc(u8, max_alignment, nsize) catch return null).ptr;
        }
    }
};
