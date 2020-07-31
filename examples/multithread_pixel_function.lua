#!/usr/bin/env luajit
local time = require("time")
local ldb = require("lua-db")
local mt_px_f = require("lua-db.multithread_pixel_function").multithread_pixel_function

-- create input and output handler for application
local w,h = tonumber(arg[1]) or 320, tonumber(arg[2]) or 240
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = w,
	sdl_height = h,
	--limit_fps = 30
}, arg)
cio:init()
cio.target_format = "rgb888"
cio:target_resize()
function cio:on_close()
	self.run = false
end

-- get the SDF callback function for a width, height
local callback_path = arg[3] or "./examples/data/sdf_simple.lua"
local callback = dofile(callback_path)(w,h)

-- get a function that runs the callback function for every pixel on db when called
local renderer = mt_px_f(cio.target_db, callback)
renderer.start()

cio.run = true
local start = time.realtime()
local last = time.realtime()
cio.target_db:clear(0,0,0,0)
while cio.run do
	local now = time.realtime()
	local dt = now - last
	local elapsed = now-start
	last = now

	io.write(("Frame time: %8.2fms    \r"):format(dt*1000))
	io.flush()

	renderer.render(elapsed)
	cio:update()
end
