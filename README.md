<div align="center">

# zig-luajit-build

Used to compile and link the native [LuaJIT][LUAJIT] C API into Zig ⚡ applications.

![Ubuntu Build Status Badge](https://img.shields.io/github/actions/workflow/status/sackosoft/zig-luajit-build/build-ubuntu.yml?label=Linux%20Build)
![Windows Build Status Badge](https://img.shields.io/github/actions/workflow/status/sackosoft/zig-luajit-build/build-windows.yml?label=Windows%20Build)
![GitHub License](https://img.shields.io/github/license/sackosoft/zig-luajit-build)

<!--
TODO: Capture attention with a visualization, diagram, demo or other visual placeholder here.
![Placeholder]()
-->

</div>

LuaJIT is a fork from the [Lua][LUA] project -- "Lua is a powerful, efficient, lightweight, embeddable scripting language."

[LUAJIT]: https://luajit.org/index.html
[LUA]: https://www.lua.org/about.html

## Are you looking for a Zig interface to the LuaJIT C API?

This package does not contain Zig language bindings to the C API. This package only handles building and linking the
LuaJIT library into a Zig application.

If you're looking to run Lua on LuaJIT in your Zig application, you're probably looking for one of these projects:

1. [sackosoft/zig-luajit](https://github.com/sackosoft/zig-luajit) **- Zig language bindings LuaJIT.**
    - Preferred solution when only one Lua runtime (LuaJIT) is required;  built on top of `zig-luajit-build`.
2. [natecraddock/ziglua](https://github.com/natecraddock/ziglua) - Zig language bindings for Lua 5.x and Luau and LuaJIT.
    - More mature project, maintained by Nathan Craddock. Has some quirks as a result of supporting all Lua runtimes
      with the same Zig API.

## Zig Version

The `main` branch targets Zig's `master` (nightly) deployment (currently `0.14.0-dev.XXXX`).

## Installation & Usage

Install using `zig fetch`. This will add a `luajit_build` dependency to your `build.zig.zon` file.

```bash
zig fetch --save=luajit_build git+https://github.com/sackosoft/zig-luajit-build
```

Next, in order for your code to import the LuaJIT C API, you'll need to update your `build.zig` to:

1. get a reference to the `luajit-build` dependency which was added by zig fetch.
2. get a reference to the `luajit-build` module, containing the native LuaJIT C API.
3. attach that module as an import to your library or executable, so that your code can reference the C API.

```zig
// (1) Reference the dependency
const luajit_build_dep = b.dependency("luajit_build", .{
    .target = target, 
    .optimize = optimize,
    .link_as = .static  // Or .dynamic to link as a shared library
});

// (2) Reference the module containing the LuaJIT C API.
const luajit_build = luajit_build_dep.module("luajit-build");

// Set up your library or executable
const lib = // ...
const exe = // ...

// (3) Add the module as an import, available via `@import("c")`, or any other name you choose here.
lib.root_module.addImport("c", luajit_build);
// Or
exe.root_module.addImport("c", luajit_build);
```

Now the code in your library or executable can import and access the LuaJIT C API!

```zig
const c = @import("c");  // Access LuaJIT functions via 'c'

pub fn main() !void {
    const state: ?*c.lua_State = c.luaL_newstate();
    if (state) |L| {
        c.luaL_openlibs(L);
        c.luaL_dostring(
            L, 
            \\ print("Hello, world!")
        );
    }
}
```

## Configuration

This package supports one configuration option, shown in the example above.

- `link_as`: Controls how LuaJIT is linked
  - `.static`: Build and link LuaJIT as a static library (default).
  - `.dynamic`: Build and link LuaJIT as a shared library.

## License

Some files in this repository were copied or adapted from the [natecraddock/ziglua](https://github.com/natecraddock/ziglua) project.
Any files copied or adapted from that project have a comment describing the attribution at the top. Such files are shared by Nathan
Craddock under the MIT License in [ziglua/license](https://github.com/natecraddock/ziglua/blob/90dab7e72173709353dcaaa6d911bed7655c030d/license).

All other files are released under the MIT License in [zig-luajit-build/LICENSE](./LICENSE).

