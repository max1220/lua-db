#!/usr/bin/env luajit
local ldb = require("lua-db")

local dev = assert(arg[1], "Argument 1 should be a device(e.g. /dev/video0) or video file(e.g. ./video.mp4)")
local video_width = assert(tonumber(arg[2]), "Argument 2 should be a width(e.g. 640)")
local video_height = assert(tonumber(arg[3]), "Argument 3 should be a height(e.g. 480)")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = video_width,
	sdl_height = video_height,
	sdl_title = "lua-db FFMPEG: " .. dev,
}, arg)
cio:init()

-- open video stream
local video_db = ldb.new_drawbuffer(video_width, video_height, ldb.pixel_formats.rgb888)
cio.target_db = video_db
video_db:clear(0,0,0,255)

local video = ldb.ffmpeg.open_v4l2(dev, video_width, video_height)
if not dev:match("^/dev/video") then
	video = ldb.ffmpeg.open_file(dev, video_width, video_height, nil, true)
end

function cio:on_close()
	self.run = false
end

function cio:sleep(seconds)
	-- HACK: because frames on stdout of ffmpeg would "pile up" when limiting FPS,
	-- try to read frames when the engine should sleep. This is mostly not a
	-- busy wait because reading from stdin should block.
	local start = self:realtime()
	local elapsed = self:realtime()-start
	while elapsed<seconds do
		local frame = video:read_frame()
		if frame then
			video_db:load_data(frame)
		end
		elapsed = self:realtime()-start
	end
end

video:start()

cio.run = true
while cio.run do
	cio:update()
	local frame = video:read_frame()
	if frame then
		video_db:load_data(frame)
	end
end
