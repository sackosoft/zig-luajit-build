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
    const type_to_name: [12][:0]const u8 = .{
        "no value",
        "nil",
        "boolean",
        "userdata",
        "number",
        "string",
        "table",
        "function",
        "userdata",
        "thread",
        "proto",
        "cdata",
    };

    const T = struct {
        fn ErrHandler(l: *c.lua_State) callconv(.c) i32 {
            const top = c.lua_gettop(l);

            const t = c.lua_type(l, -1);
            const type_name = type_to_name[@as(usize, @intCast(t)) + 1];

            const string: [*:0]const u8 = c.lua_tolstring(l, -1, null).?;

            std.debug.print("ErrHandler: Stack contains {d} an {s}: '{s}'\n", .{ top, type_name, string });
            return 0;
        }

        fn Fn(l: *c.lua_State) callconv(.c) i32 {
            c.luaL_checkstack(l, 9000, "CUSTOM ERROR MESSAGE");
            return 0;
        }
    };

    c.lua_pushcclosure(L, @ptrCast(&T.ErrHandler), 0);
    c.lua_pushcclosure(L, @ptrCast(&T.Fn), 0);

    std.debug.print("Calling into function...\n", .{});
    const res = c.lua_pcall(L, 0, 0, 1);
    std.debug.print("pcall = {d}\n", .{res});
    std.debug.print("Error message: '{s}'\n", .{c.lua_tolstring(L, -1, null).?});
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
