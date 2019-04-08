#!/usr/bin/env luajit
local ldb = require("ldb")
local term = require("term")
local ffmpeg = require("ffmpeg")


local dev = assert(arg[1], "Argument 1 should be a device(e.g. /dev/video0) or video file")
local width = assert(tonumber(arg[2]), "Argument 2 should be a width(e.g. 1920)")
local height = assert(tonumber(arg[3]), "Argument 3 should be a height(e.g. 1080)")


-- open output
local lfb, sdl2fb, braile, blocks
local output
if arg[4] == "sdl" then
	sdl2fb = require("sdl2fb")
elseif arg[4] == "fb" then
	lfb = require("lfb")
elseif arg[4] == "braile" then
	braile = require("braile")
	-- use 24-bit colors
	if arg[5] == "24bpp" then
		braile.get_color_code_fg = braile.get_color_code_fg_24bit
		--braile.get_color_code_bg = braile.get_color_code_bg_24bit
	end
elseif arg[4] == "blocks" then
	blocks = require("blocks")
	if arg[5] == "24bpp" then
		blocks.get_color_code_bg = term.rgb_to_ansi_color_bg_24bpp
	end
else
	error("No valid output specified! Chose from: sdl, fb, braile")
end


-- open video stream
local video = ffmpeg.open_v4l2(dev, width, height)
if not dev:match("^/dev/video") then
	video = ffmpeg.open_file(dev, width, height)
end


-- get upper-left coodinate of a centered box on the terminal
local next_update = 0
local center_x, center_y
local function get_center(out_w, out_h)
	if os.time() >= next_update then
		local term_w,term_h = term.get_screen_size()
		local _center_x = math.floor((term_w - out_w) / 2)
		local _center_y = math.floor((term_h - out_h) / 2)
		if center_x == _center_x and center_y == _center_y then
			return _center_x, _center_y
		end
		center_x = _center_x
		center_y = _center_y
		
		-- clear screen(to remove artifacts)
		io.write(term.clear_screen())
		
		-- only update screen size every 5s
		next_update = os.time() + 5
	end
	return center_x, center_y
end


local target_db = ldb.new(width, height)
local fb, sdlfb
if sdl2fb then
	sdlfb = sdl2fb.new(width, height, "ffmpeg example")
end
if lfb then
	fb = lfb.new("/dev/fb0")
end
if braile or blocks then
	io.stdout:setvbuf("full")
end



video:start()
while true do
	
	-- read frame & render to drawbuffer
	local frame = video:read_frame()
	video:draw_frame_to_db(target_db, frame)
	
	-- update sdl output & handle sdl events
	if sdl then
		sdlfb:draw_from_drawbuffer(target_db,0,0)
		local ev = sdlfb:pool_event()
		if ev and ev.type == "quit" then
			sdlfb:close()
			break
		end
	end
	
	-- update sdl output	
	if sdl2fb then
		sdlfb:draw_from_drawbuffer(target_db, 0, 0)
	end
	
	-- update lua-fb output
	if lfb then
		fb:draw_from_drawbuffer(target_db, 0, 0)
	end
	
	-- update braile output
	if braile then
		local center_x, center_y = get_center(math.floor(target_db:width()/2), math.floor(target_db:height()/4))
		local lines = braile.draw_db(target_db, 45, true, arg[5] == "24bpp")
		for i, line in ipairs(lines) do
			io.write(term.set_cursor(center_x, center_y+i-1))
			io.write(line)
			io.write(term.reset_color())
			io.write("\n")
		end
		io.flush()
	end
	
	-- update blocks output
	if blocks then
		local center_x, center_y = get_center(target_db:width(), target_db:height())
		local lines = blocks.draw_db(target_db)
		for i, line in ipairs(lines) do
			io.write(term.set_cursor(center_x, center_y+i-1))
			io.write(line)
			io.write(term.reset_color())
			io.write("\n")
		end
		io.flush()
	end
	
end
