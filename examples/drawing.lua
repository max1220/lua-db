#!/usr/bin/env luajit
local ldb = require("lua-db")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_title = "Drawing primitives example",
	sdl_width = 640,
	sdl_height = 480,
	limit_fps = 10
}, arg)
cio:init()

-- create drawbuffer of native display size
local w,h = cio:get_native_size()

function cio:on_draw(target_db)
	target_db:clear(0,0,0,255)

	target_db:set_px(0,0,255,0,255,255)
	target_db:set_px(w-1,0,255,0,255,255)
	target_db:set_px(0,h-1,255,0,255,255)
	target_db:set_px(w-1,h-1,255,0,255,255)

	target_db:triangle(1,1, 1,h-2, w/2,h/2, 64,0,0,255)
	target_db:triangle(w-2,1, w-2,h-2, w/2,h/2, 0,64,0,255)
	target_db:triangle(1,h-2, w-2,h-2, w/2,h/2, 0,0,64,255)
	target_db:triangle(1,1, w-2,1, w/2,h/2, 64,0,64,255)

	target_db:line(w-2,1,1,h-2,255,255,255,255)
	target_db:line(10,1,w-10,h-2,255,255,255,128, true)
	target_db:line(1,1,w-2,h-2,255,255,255,128, 5)

	target_db:circle(20,h/2, 15, 255,0,255,255)
	target_db:circle(60,h/2, 15, 255,0,255,255, true)
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
