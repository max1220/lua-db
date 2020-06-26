#!/usr/bin/env luajit
local ldb = require("lua-db")

-- load bitmap to drawbuffer
local filepath = assert(arg[1], "Argument 1 must be a file")
local img_db = ldb.bitmap.decode_from_file_drawbuffer(filepath)

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = img_db:width(),
	sdl_height = img_db:height(),
	limit_fps = 10
}, arg)
cio:init()
cio.target_db = img_db

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
