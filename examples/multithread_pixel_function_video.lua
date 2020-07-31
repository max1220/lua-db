#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")
local args_parse = require("lua-db.args_parse")
local mt_px_f = require("lua-db.multithread_pixel_function").multithread_pixel_function


-- parse arguments
local w = args_parse.get_arg_num(arg, "render_width", 320)
local h = args_parse.get_arg_num(arg, "render_height", 240)
local duration = args_parse.get_arg_num(arg, "duration", 30)
local fps = args_parse.get_arg_num(arg, "render_fps", 30)
local sdf_path = args_parse.get_arg_str(arg, "sdf", "./examples/data/sdf_simple.lua")
local raw_path = args_parse.get_arg_str(arg, "rawfile", "tmp.raw")


-- create a drabuffer to render to
local target_db = ldb.new_drawbuffer(w,h,ldb.pixel_formats.rgb888)


-- TODO: write done frames directly to ffmpeg stdin
local raw_file = io.open(raw_path, "w")
local frame_count = duration*fps
local render_now = 0
local lines_done = 0
local frames_rendered = 0


-- load font
local img_db = ldb.bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")
local char_to_tile = dofile("./examples/data/8x8_font_max1220.lua")
local font = ldb.bmpfont.new_bmpfont({
	db = img_db,
	char_w = 8,
	char_h = 8,
	scale_x = 1,
	scale_y = 1,
	char_to_tile = char_to_tile,
	color = {255,255,255}
})


-- load the SDF callback function for a width, height
local callback = dofile(sdf_path)(w,h)


-- get a non-blocking render function. When called returns a complete frame, if available.
-- Otherwise, request a new frame
local renderer = mt_px_f(target_db, callback)
renderer.start()


-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = w+100, -- leave some space for the "gui"
	sdl_height = h+200,
	limit_fps = 30
}, arg)
cio:init()


local function seconds_to_str(seconds)
	if seconds > 60*60 then
		local hours = math.floor(seconds/3600)
		local minutes = math.floor(seconds/60) % 60
		seconds = seconds % 60
		return ("%dhours %dminutes %dseconds"):format(hours, minutes, seconds)
	elseif seconds > 60 then
		local remaining_m = math.floor(seconds/60)
		local remaining_s = seconds % 60
		return ("%dminutes %dseconds"):format(remaining_m, remaining_s)
	else
		return ("%dseconds"):format(seconds)
	end
end

function cio:on_draw(db)
	db:clear(32,32,32,32)
	target_db:origin_to_target(db, 50,50)
	font:draw_text(db, "Rendering...", 50, h+100)

	local frame_len = font:draw_text(db,  ("frame:  %.5d/%.5d: "):format(lines_done,h), 50, h+116)
	local frame_pct = lines_done/h
	db:rectangle(50+frame_len, h+116, w-frame_len, 8, 0,0,0,255)
	db:rectangle(50+frame_len+1, h+116+1, frame_pct*(w-frame_len)-2, 6, 255,255,255,255)

	local frames_len = font:draw_text(db, ("frames: %.5d/%.5d: "):format(frames_rendered,frame_count), 50, h+125)
	local frames_pct = frames_rendered/frame_count
	db:rectangle(50+frame_len, h+125, w-frames_len, 8, 0,0,0,255)
	db:rectangle(50+frames_len+1, h+125+1, frames_pct*(w-frames_len)-2, 6, 255,255,255,255)

	local now = time.realtime()
	local elapsed = now-self.started
	local remaining_s = elapsed*(1/frames_pct)-elapsed
	font:draw_text(db, ("Elapsed: %ds"):format(elapsed), 50, h+134)

	local remaining_str = seconds_to_str(remaining_s)
	font:draw_text(db, "Remaining: "..remaining_str, 50, h+143)
end

function cio:on_update()
	local data,_,req = renderer.render_nb(render_now)
	if data then
		render_now = render_now + 1/fps
		target_db:load_data(data)
		raw_file:write(data)
		frames_rendered = frames_rendered + 1
		if frame_count == frames_rendered then
			-- render complete
			self.run = false
		end
	else
		lines_done = h-req
	end
end

function cio:on_close()
	self.run = false
end

cio.run = true
cio.started = time.realtime()
while cio.run do
	cio:update()
end

local elapsed = time.realtime()-cio.started
print("Rendering took", elapsed.."s")
