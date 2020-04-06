## Directory structure

`doc/` contains the files(markdown and makefile) needed to build the documentation.

`examples/` contains runnable example code. Some examples require assets, they are in `examples/data`.

`lua/` contains the Lua part of this library. If you `require("lua-db")` the library normally, `lua/init.lua` is returned.

`lua/gui/` contains the GUI library.

`src/` contains the C part of the library. It's split into 4 parts:
 * ldb_core (core drawbuffer functionality, but no graphics primitives),
 * ldb_gfx (graphics primitives like lines, rectangles)
 * ldb_fb (Linux framebuffer output support)
 * ldb_sdl (SDL window output support)
