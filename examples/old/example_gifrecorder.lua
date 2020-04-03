#!/usr/bin/env luajit
local ldb = require("lua-db")
local ffmpeg = ldb.ffmpeg

-- check arguments
local dev = assert(arg[1], "Argument 1 should be a device(e.g. /dev/video0) or video file")
local width = assert(tonumber(arg[2]), "Argument 2 should be a width(e.g. 320)")
local height = assert(tonumber(arg[3]), "Argument 3 should be a height(e.g. 240)")
local filename = assert(arg[4], "Argument 4 should be the output file name")
local framecount = assert(tonumber(arg[5]), "Argument 5 should be the ammount of frames to grab")
local framerate = assert(tonumber(arg[6]), "Argument 6 should be the output file framerate")

-- open webcam
local video = ffmpeg.open_v4l2(dev, width, height)
video:start()

-- record video frames
local frames = {}
for i=1, framecount do
	local frame = video:read_frame()
	if frame then
		local frame_db = ldb.new(width, height)
		frame_db:clear(0,0,0,0)
		video:draw_frame_to_db(frame_db, frame)
		table.insert(frames, frame_db)
	end
end

-- stop recording
video:close()

-- convert collected frames to to gif
ffmpeg.write_gif(filename, width, height, framerate, frames)
