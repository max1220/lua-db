#!/usr/bin/env luajit
-- no external dependencies
local ldb_core = require("ldb_core")
local ldb_gfx = require("ldb_gfx")
local ldb_bitmap = require("lua-db.bitmap")
local ldb_bmpfont = require("lua-db.bmpfont")
local ldb_fb = require("ldb_fb")

local function gettime()
	return require("time").monotonic()
	--return os.time()
end

local fb = ldb_fb.new_framebuffer("/dev/fb0")

local font_db = ldb_bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")
local font = ldb_bmpfont.new_bmpfont({
	db = font_db,
	char_w = 8,
	char_h = 8,
	scale_x = 2,
	scale_y = 2,
	char_to_tile = dofile("./examples/data/8x8_font_max1220.lua"),
	color = {255,255,255}
})


local vinfo = fb:get_varinfo()
local w,h = vinfo.xres, vinfo.yres
local drawbuffer = fb:get_drawbuffer()
drawbuffer:clear(0,0,0,0)
print("Prepared drawbuffers for output", drawbuffer)

local start = gettime()
local iter = 0
local now = start
local last = now
while now-start < 15 do
	local dt = now-last
	local running = now-start
	drawbuffer:clear(ldb_gfx.hsv_to_rgb((running*0.33)%1, 1, 1))
	font:draw_text(drawbuffer, ("Framebuffer: %s"):format(tostring(fb)), 16, 16)
	font:draw_text(drawbuffer, ("FPS: %7.2f"):format(1/dt), 16, 32)
	font:draw_text(drawbuffer, ("Current time: %7.2f"):format(running), 16, 48)
	iter = iter + 1
	last = now
	now = gettime()
end

local elapsed = gettime()-start
print(("%d iterations in %d seconds. (avg. FPS: %d)"):format(iter, elapsed, iter/elapsed))
print("Bye!")
fb:close()
