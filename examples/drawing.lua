#!/usr/bin/env luajit
local ldb = require("lua-db")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "terminal",
	default_terminal_mode = "halfblocks",
	terminal_bpp24 = true
}, arg)
cio:init()

-- create drawbuffer of native display size
local w,h = cio:get_native_size()
local db = ldb.new_drawbuffer(w,h)


-- run until cio stops
while not cio.stop do
	db:clear(0,0,0,255)

	--[[
	db:set_px(0,0,255,0,255,255)
	db:set_px(w-1,0,255,0,255,255)
	db:set_px(0,h-1,255,0,255,255)
	db:set_px(w-1,h-1,255,0,255,255)

	db:triangle(1,1, 1,h-2, w/2,h/2, 64,0,0,255)
	db:triangle(w-2,1, w-2,h-2, w/2,h/2, 0,64,0,255)
	db:triangle(1,h-2, w-2,h-2, w/2,h/2, 0,0,64,255)
	db:triangle(1,1, w-2,1, w/2,h/2, 64,0,64,255)

	db:line(w-2,1,1,h-2,255,255,255,255)
	db:line(10,1,w-10,h-2,255,255,255,128, true)
	db:line(1,1,w-2,h-2,255,255,255,128, 5)

	db:circle(20,h/2, 15, 255,0,255,255)
	db:circle(60,h/2, 15, 255,0,255,255, true)
	]]

	db:rectangle(1,1,3,3,255,0,255,255, true, false)


	-- draw drawbuffer to output
	cio:update_output(db)
	cio:update_input()
end
