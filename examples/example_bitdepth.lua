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

-- draw an image filled with saturated colors, where the x axis encode all hue values, and y axis encodes value
local function draw_colors(db)
	local hsv_to_rgb = ldb.hsv_to_rgb
	local width = db:width()
	local height = db:height()
	for y=0, height-1 do
		for x=0, width-1 do
			local r,g,b = hsv_to_rgb(x/(width-1), 1, 1-y/(height-1))
			db:set_px(x,y,r,g,b,255)
		end
	end
end

-- get native display size
local w,h = cio:get_native_size()

-- create a drawbuffer for each pixel format, and use draw_colors on it
local drawbuffers = {}
for _, px_fmt in pairs({"rgb888", "rgb565", "rgb332"}) do
	local drawbuffer = assert(ldb.new_drawbuffer(w,h, ldb.pixel_formats[px_fmt]))
	draw_colors(drawbuffer)
	table.insert(drawbuffers, drawbuffer)
end

-- create a drawbuffer, use draw_colors on it, then dither to a lower bitdepth
for _, bpp in pairs({16,8,1}) do
	local drawbuffer = assert(ldb.new_drawbuffer(w,h, ldb.pixel_formats.rgb888))
	draw_colors(drawbuffer)
	drawbuffer:floyd_steinberg(bpp)
	table.insert(drawbuffers, drawbuffer)
end


-- draw each drawbuffer for 5 seconds
local start = time.realtime()
local i = 1
while not cio.stop do
	if (time.realtime() - start) > 5 then
		start = time.realtime()
		i = (i%#drawbuffers)+1
	end

	-- draw drawbuffer to cio output, handle input events
	cio:update_output(drawbuffers[i])
	cio:update_input()

end
