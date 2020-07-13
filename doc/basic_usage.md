# Basic Usage

Usually the module is loaded as:
```
local ldb = require("lua-db")
```

This loads all available Lua modules and all available C modules, and returns
them in a table. (See `lua/init.lua`)

To load just the C core, you can use `require("ldb_core")`.

The main structure in lua-db is a drawbuffer. It's a userdata value with
associated metatable methods that represent a drawing surface.

A drawbuffer is created using the new_drawbuffer function from the core module.
```
local db = ldb.new_drawbuffer(width, height, px_fmt)
```

`width` and `height` are in pixels and are required. `px_fmt` specifies the
pixel format and is optional. By default, a 32bpp RGBA value is used.

On success a drawbuffer usedata value is returned that has methods
for interaction in it's metatable.

On failure, nil and an error message is returned.
