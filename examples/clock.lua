#!/usr/bin/env luajit
local ldb = require("lua-db")
local clock = require("lua-db.clock")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = 640,
	sdl_height = 480,
	limit_fps = 10
}, arg)
cio:init()

-- create drawbuffer of native display size
local w,h = cio:get_native_size()

function cio:on_draw(target_db)
	target_db:clear(0,0,0,255)

	-- draw clock with current time to drawbuffer
	local t = os.date("*t")
	clock.draw_clock(target_db, w,h, 0,0, t.hour, t.min, t.sec, 255,255,255)
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
