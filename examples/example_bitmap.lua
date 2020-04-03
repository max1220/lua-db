#!/usr/bin/env luajit
local ldb = require("lua-db")
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
local output_db = ldb.new_drawbuffer(w,h)


-- load bitmap to drawbuffer
local filepath = assert(arg[1], "Argument 1 must be a file")
local img_db = ldb.bitmap.decode_from_file_drawbuffer(filepath)

-- run until cio stops
while not cio.stop do
	output_db:clear(0,0,0,255)

	-- copy the loaded bitmap to the output db with alphablending
	img_db:origin_to_target(output_db)

	-- draw drawbuffer to cio output, handle input events
	cio:update_output(output_db)
	cio:update_input()

	-- no need to show a bitmap with more FPS than this...
	-- TODO: Lock to fixed FPS in input_output
	time.sleep(0.1)
end
