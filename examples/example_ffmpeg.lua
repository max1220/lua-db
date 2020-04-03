#!/usr/bin/env luajit
local ldb = require("lua-db")
local args_parse = require("lua-db.args_parse")

-- parse arguments
local dither
if args_parse.get_arg_flag(arg, "dither_8") then
	dither = 1
elseif args_parse.get_arg_flag(arg, "dither_256") then
	dither = 8
end
local dev = assert(arg[1], "Argument 1 should be a device(e.g. /dev/video0) or video file(e.g. ./video.mp4)")
local video_width = assert(tonumber(arg[2]), "Argument 2 should be a width(e.g. 640)")
local video_height = assert(tonumber(arg[3]), "Argument 3 should be a height(e.g. 480)")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = video_width,
	sdl_height = video_height,
}, arg)
cio:init()

-- create drawbuffer of native display size
local w,h = cio:get_native_size()
local output_db = ldb.new_drawbuffer(w,h, ldb.pixel_formats.rgb888)
output_db:clear(0,0,0,255)

-- open video stream
local video_db = ldb.new_drawbuffer(video_width, video_height, ldb.pixel_formats.rgb888)
video_db:clear(0,0,0,255)
local video = ldb.ffmpeg.open_v4l2(dev, video_width, video_height)
if not dev:match("^/dev/video") then
	video = ldb.ffmpeg.open_file(dev, video_width, video_height, nil, true)
end

video:start()
while not cio.stop do
	-- read frame & render to drawbuffer
	local frame = video:read_frame()
	if frame then
		--video:draw_frame_to_db(video_db, frame)
		video_db:load_data(frame)
		if dither then
			video_db:floyd_steinberg(dither)
		end
	end
	video_db:origin_to_target(output_db)

	cio:update_output(output_db)
	cio:update_input()
end
