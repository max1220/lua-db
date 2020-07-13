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
local drawbuffer = ldb.new_drawbuffer(width, height, px_fmt)
```

On success a drawbuffer usedata value is returned that has methods
for interaction in it's metatable.

You can now interact with these methods, for example:

`drawbuffer:set_px(0,0, 255,0,0,255)`

This would set the top-left pixel to red, full alpha.

Because all drawbuffers share the same metatable, you can easily overload a
function for all drawbuffers:

```
function draw_diagonal(db, len)
	-- draw a pink diagonal line of specified length
	for i=0, len-1 do
		db:set_px(i,i, 255,0,0,255)
	end
end
local mt = getmetatable(drawbuffer) -- get metatable of any drawbuffer
mt.__index["draw_diagonal"] = draw_diagonal -- put into metatable for all drawbuffers
drawbuffer:draw_diagonal(100) -- this works on all drawbuffers now
```

This is used in this library in `init.lua` to combine the different C modules
and Lua modules to a unified interface.
