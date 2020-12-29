local ldb_core = require("ldb_core")
local ldb_fb = require("ldb_fb")
local time = require("time")

local fb = assert(ldb_fb.new_framebuffer("/dev/fb0"))
local vinfo = fb:get_varinfo()
local w,h = vinfo.xres, vinfo.yres
local db = fb:get_drawbuffer()

local duration = 15

local start = time.monotonic()
local run = true
local frames = 0
while run do
	-- directly draw on drawbuffer connected to sdlfb
	--db:clear(255,255,255,255)
	for i=1, 100 do
		db:set_px(math.random(0, w-1), math.random(0, h-1), 255,0,0,255)
	end

	frames = frames + 1
	if time.monotonic()-start > duration then
		run = false
	end
end
local stop = time.monotonic()
local total = (stop-start)
local dt = total/frames
print("Avg. FPS:", 1/dt)
print("Avg. dt:", dt)
print("Time:", total)
print("Frames:", frames)
print("w,h:", w,h)
