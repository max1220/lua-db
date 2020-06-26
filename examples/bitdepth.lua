#!/usr/bin/env luajit
local ldb = require("lua-db")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = 640,
	sdl_height = 480,
	limit_fps = 10,
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
local drawbuffers = {}

-- create a drawbuffer for each pixel format, and use draw_colors on it
for _, px_fmt in pairs({"rgb888", "rgb565", "rgb332"}) do
	local drawbuffer = assert(ldb.new_drawbuffer(w,h, ldb.pixel_formats[px_fmt]))
	draw_colors(drawbuffer)
	table.insert(drawbuffers, {px_fmt, drawbuffer})
end

-- create a drawbuffer, use draw_colors on it, then dither to a lower bitdepth
for _, bpp in pairs({16,8,1}) do
	local drawbuffer = assert(ldb.new_drawbuffer(w,h, ldb.pixel_formats.rgb888))
	draw_colors(drawbuffer)
	drawbuffer:floyd_steinberg(bpp)
	table.insert(drawbuffers, {"Dithered to " .. bpp .. "bpp", drawbuffer})
end

-- draw each drawbuffer for 5 seconds
local timeout = 5
local remaining = 0
local i = 1
function cio:on_update(dt)
	remaining = remaining - dt
	if remaining >= 0 then
		return
	end
	remaining = timeout

	io.write(("Showing: %s    \r"):format(drawbuffers[i][1]))
	io.flush()

	-- switch out drawbuffer
	cio.target_db = drawbuffers[i][2]
	i = (i%#drawbuffers)+1
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
