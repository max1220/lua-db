#!/usr/bin/env luajit
local ldb = require("lua-db")
local clock = require("lua-db.clock")
local time = require("time")


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

	-- draw clock with current time to drawbuffer
	local t = os.date("*t")
	clock.draw_clock(db, w,h, 0,0, t.hour, t.min, t.sec, 255,255,255)

	-- draw drawbuffer to cio output, handle input events
	cio:update_output(db)
	cio:update_input()

	-- no need to update a clock with more FPS than this...
	time.sleep(0.1)
end
