# simple-repl

This sample application is provided to test the functionality of the the `zig-luajit-build` C API directly. For Zig
language bindings to LuaJIT, kindly refer to one of the following projects:

* [zig-luajit](https://github.com/sackosoft/zig-luajit) - The parent project to this code. Less mature but more clean
  for LuaJIT-focused developers.
* [ziglua](https://github.com/natecraddock/ziglua) - (Unaffiliated) The more mature project that supports more Lua
  runtimes than LuaJIT, less clean Zig API surface.

## Version

Last tested with Zig version `0.15.1`.

## Usage

Usage instructions:

* Ensure your current working directory is `zig-luajit-build/examples/simple-repl`.
* Use `zig build run` to start the read-evaluate-print-loop (REPL).
* Use `print()` to write Lua values to standard output. The REPL does not do any output itself.

## Example Output

Here's a sample of running the interpreter:

```
~/repos/zig-luajit-build/examples/simple-repl > zig build run
> print('Hello, world!')
Hello, world!
> print(1 + 1)
2
> f = function() print("Yes, even functions work too") end
> f()
Yes, even functions work too
>
```
