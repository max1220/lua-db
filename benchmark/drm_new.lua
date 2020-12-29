local ldb_core = require("ldb_core")
local ldb_drm = require("ldb_drm")
local time = require("time")

local card = assert(ldb_drm.new_card("/dev/dri/card0"))
card:prepare()
local info = card:get_info()
local dbs,ws,hs = {},{},{}
for i=1, #info do
	local db = assert(card:get_drawbuffer(i))
	dbs[i] = db
	ws[i] = db:width()-1
	hs[i] = db:height()-1
end


local duration = 15

local start = time.monotonic()
local run = true
local frames = 0
while run do
	-- directly draw on drawbuffer connected to sdlfb
	--db:clear(255,255,255,255)
	for i=1, #info do
		for _=1, 100 do
			dbs[i]:set_px(math.random(0, ws[i]), math.random(0, hs[i]), 255,0,0,255)
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
