local ldb_core = require("ldb_core")
local ldb_sdl = require("ldb_sdl")
local time = require("time")

local w,h = 1280,1024
local sdlfb = assert(ldb_sdl.new_sdl2fb(w,h))
local db = sdlfb:get_drawbuffer()

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

	-- update content
	sdlfb:update_drawbuffer()

	local ev = sdlfb:pool_event()
	while ev do
		ev = sdlfb:pool_event()
		if ev and (ev.type == "quit") then
			run = false
		end
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
