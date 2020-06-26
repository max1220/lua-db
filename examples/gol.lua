#!/usr/bin/env luajit
local ldb = require("lua-db")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = 320,
	sdl_height = 240,
	sdl_title = "Game of Life",
	limit_fps = 30,
}, arg)
cio:init()
local w,h = cio:get_native_size()

local gol = ldb.gol.new_gol(w,h)
gol:clear(0.1)

function cio:on_update(dt)
	gol:step()
	cio.target_db = gol.cstate
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
