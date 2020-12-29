local ldb_core = require("ldb_core")
local ldb_drm = require("ldb_drm")
local time = require("time")

local card = assert(ldb_drm.new_card("/dev/dri/card0"))
card:prepare()
local info = card:get_info()
local w,h = info[1].width,info[1].height
local db = ldb_core.new_drawbuffer(w,h)

local duration = 15

local start = time.monotonic()
local run = true
local frames = 0
while run do
	-- directly draw on drawbuffer connected to sdlfb
	--db:clear(255,255,255,255)
	for _=1, 100 do
		db:set_px(math.random(0, w-1), math.random(0, h-1), 255,0,0,255)
	end

	card:copy_from_db(db, 1)

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
