# lua-db - lua drawbuffers

This is a Lua library for graphics programming, written in C and Lua.
It's main component is a drawbuffer, a buffer that has a width, height,
pixel format, and pixel data. There are various graphics primitives
available for the drawbuffer objects, e.g. lines, triangles, rectangles.
lua-db does not support any hardware acceleration.

There are multiple output options:
 * SDL window
 * Linux framebuffer
 * Terminal output
  - monochrome/8bit colors/24bit colors
  - braile characters(required utf8 support, only 1 color per 2x4 pixels)
  - block characters(required utf8 support)
  - regular characters



# Dependencies

See the respective readme's on how to install them.

 * lua-time for most examples(runtime)
 * SDL2 library for sdl module (runtime, build)
 * Linux headers for framebuffer module(build)




# Installation

The installation is handled by the top-level makefile.

Simple run: `make install` in the top-level directory.




# Usage

Usually the module is loaded as:
```
local ldb = require("lua-db")
```

This loads all available lua modules and all available C modules, and returns
them in a table. (See lua/init.lua)

To load just the C core, you can use `require("ldb_core")`.

For now, see `examples/` for further usage information. This is TODO.



# Development

## Directory structure

`doc/` contains the files(markdown and makefile) needed to build the documentation.

`examples/` contains runnable example code. Some examples require assets, they are in `examples/data`.

`lua/` contains the Lua part of this library. If you require the library normally, `lua/init.lua` is loafunctionality

`lua/gui/` contains the GUI library.

`src/` contains the C part of the library. It's split into 4 parts:
 * ldb_core (core drawbuffer functionality, but no graphics primitives),
 * ldb_gfx (graphics primitives like lines, rectangles)
 * ldb_fb (Linux framebuffer output support)
 * ldb_sdl (SDL window output support)




## Development installation

You can install symlinks instead of running `make install`.

```
# make sure target path exists
sudo mkdir -p /usr/local/share/lua/5.1/lua-db
sudo mkdir -p /usr/local/lib/lua/5.1/

# install symlinks so make install is not needed after each change
# (adjust paths of lua-db source path)
sudo ln -s /home/max/stuff/lua-db3/lua /usr/local/share/lua/5.1/lua-db
sudo ln -s /home/max/stuff/lua-db3/src/ldb_core.so /usr/local/lib/lua/5.1/
sudo ln -s /home/max/stuff/lua-db3/src/ldb_fb.so /usr/local/lib/lua/5.1/
sudo ln -s /home/max/stuff/lua-db3/src/ldb_gfx.so /usr/local/lib/lua/5.1/
sudo ln -s /home/max/stuff/lua-db3/src/ldb_sdl.so /usr/local/lib/lua/5.1/
```





TODO: finish doc build
