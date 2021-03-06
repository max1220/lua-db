#!/usr/bin/env luajit
-- no external dependencies
local ldb_core = require("ldb_core")
local ldb_gfx = require("ldb_gfx")
local ldb_bitmap = require("lua-db.bitmap")
local ldb_bmpfont = require("lua-db.bmpfont")
local ldb_drm = require("ldb_drm")

local function gettime()
	return require("time").monotonic()
	--return os.time()
end

local card = ldb_drm.new_card("/dev/dri/card0")
card:prepare()

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

local info = card:get_info()
local drawbuffers = {}
for k,entry in ipairs(info) do
	local w,h = entry.width, entry.height
	print(("Preparing monitor %d for resolution %dx%d"):format(k,w,h))
	--local db = ldb_core.new_drawbuffer(w,h)
	local db = card:get_drawbuffer(k)
	drawbuffers[k] = db
end
print(("Prepared %d drawbuffers for output"):format(#drawbuffers))

local start = gettime()
local iter = 0
local now = start
local last = now
while now-start < 15 do
	local dt = now-last
	-- draw a different output to all outputs
	for i,db in ipairs(drawbuffers) do
		local running = now-start
		db:clear(ldb_gfx.hsv_to_rgb(((i/(#drawbuffers+1))+running*0.33)%1, 0.7, 0.7))
		font:draw_text(db, ("DRM output: %d"):format(i), 16, 16)
		font:draw_text(db, ("FPS: %7.2f"):format(1/dt), 16, 32)
		font:draw_text(db, ("Current time: %7.2f"):format(running), 16, 48)
	end
	iter = iter + 1
	last = now
	now = gettime()
end

local elapsed = gettime()-start
print(("%d iterations in %d seconds. (avg. FPS: %d)"):format(iter, elapsed, iter/elapsed))
print("Bye!")
card:close()
