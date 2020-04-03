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

-- load bitmap to drawbuffer
-- TODO: Better path handling for examples
local img_db = ldb.bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")

-- load the mapping of characters to tile-ids
local char_to_tile = dofile("./examples/data/8x8_font_max1220.lua")

-- create the fonts
local fonts = {}
for i=0, 15 do
	local r,g,b = ldb.hsv_to_rgb(i/15, 1, 1)
	local font = ldb.bmpfont.new_bmpfont({
		db = img_db,
		char_w = 8,
		char_h = 8,
		scale_x = (i<3) and i+1 or 1,
		scale_y = (i<4) and i+1 or 1,
		char_to_tile = char_to_tile,
		color = {r,g,b}
	})
	fonts[i+1] = font
end


-- run until cio stops
while not cio.stop do
	db:clear(0,0,0,255)

	-- draw a line of text with every font
	local cy = 0
	local text = "Hello World! "..os.date("%H:%M:%S")
	for i=1, #fonts do
		fonts[i]:draw_text(db, text, i*8, cy)
		cy = cy + fonts[i].char_h*fonts[i].scale_y + 1
	end

	-- draw drawbuffer to output
	cio:update_output(db)
	cio:update_input()
end
