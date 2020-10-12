#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")
local effil = require("effil")
local args_parse = require("lua-db.args_parse")
local px_f = require("lua-db.multithread_pixel_function")

-- parse arguments
local w = args_parse.get_arg_num(arg, "render_width", 320)
local h = args_parse.get_arg_num(arg, "render_height", 240)
local duration = args_parse.get_arg_num(arg, "duration", 30)
local fps = args_parse.get_arg_num(arg, "render_fps", 30)
local callback_path = args_parse.get_arg_str(arg, "callback", "./examples/data/callback_sdf_shape.lua")
local raw_path = args_parse.get_arg_str(arg, "rawfile", "tmp.raw")
local preview_scale = args_parse.get_arg_num(arg, "preview_scale", 1)
local threads = args_parse.get_arg_num(arg, "threads", effil.hardware_threads()+1)
local stride = args_parse.get_arg_num(arg, "stride", 32)
local method = args_parse.get_arg_str(arg, "method","simple")
local disable_preview = args_parse.get_arg_flag(arg, "disable_preview")
if not ((method == "simple") or (method == "ffi") or (method == "ffi_shared_buf")) then
	error("Unknown method selected:" .. method)
end

local log,logf = args_parse.logger_from_args(arg, "info","warn","err","debug")

-- create a drabuffer to render to
local target_db = ldb.new_drawbuffer(w,h,ldb.pixel_formats.rgb888)


-- TODO: write done frames directly to ffmpeg stdin
local raw_file
if (raw_path=="stdout") or (raw_path=="-") then
	raw_file = io.stdout
	log("info","raw output to stdout")
elseif raw_path~="" then
	raw_file = io.open(raw_path, "w")
	logf("info","raw output to %q",raw_path)
else
	log("warn","not saving raw output!")
end
local frame_count = duration*fps
local lines_done = 0
local frames_rendered = 0
local border = 50
local gui_h = 120
local frame_w,frame_h = w*preview_scale,h*preview_scale
if disable_preview then
	frame_w,frame_h = 500,0
	gui_h = gui_h-border
	logf("info","preview disabled")
end
local state = effil.table()
state.render_now = 0

logf("info","video parameters: width=%d height=%d duration=%d fps=%d frame_count=%d", w,h,duration,fps,frame_count)
logf("info","render parameters: threads=%d stride=%d method=%s",threads,stride,method)
logf("info","config parameters: preview_scale=%f callback_path=%q raw_path=%q",preview_scale, callback_path, raw_path)


local function per_worker_simple(w,h,bpp,worker_arg)
	local per_pixel_callback,per_frame_callback = dofile(callback_path)(w,h,bpp) -- load the callback function for a width, height
	local function per_frame_cb(seq)
		if per_frame_callback then
			return per_frame_callback(seq, state)
		end
	end
	local _min,_max,_floor,_char=math.min,math.max,math.floor,string.char
	local function per_pixel_cb(x,y,buf,i,per_frame)
		local r,g,b = per_pixel_callback(x,y,per_frame)
		r = _max(_min(_floor(r),255),0)
		g = _max(_min(_floor(g),255),0)
		b = _max(_min(_floor(b),255),0)
		buf[i] = _char(r,g,b)
	end
	return per_pixel_cb,per_frame_cb
end
local function per_worker_ffi(w,h,bpp,stride,ffi,worker_arg)
	local per_pixel_callback,per_frame_callback = dofile(callback_path)(w,h,bpp) -- load the callback function for a width, height
	local function per_frame_cb(seq)
		if per_frame_callback then
			return per_frame_callback(seq,state)
		end
	end
	local function per_pixel_cb(x,y,buf,i,per_frame)
		local r,g,b = per_pixel_callback(x,y,per_frame)
		buf[i+0] = r
		buf[i+1] = g
		buf[i+2] = b
	end
	return per_pixel_cb,per_frame_cb
end


local renderer
if method == "simple" then
	renderer = px_f.multithread_pixel_function_simple(w,h,3,threads,per_worker_simple)
elseif method == "ffi" then
	renderer = px_f.multithread_pixel_function_ffi(w,h,3,threads,stride,per_worker_ffi)
elseif method == "ffi_shared_buf" then
	renderer = px_f.multithread_pixel_function_ffi_shared_buf(w,h,3,threads,stride,per_worker_ffi)
end
renderer.start()



-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = frame_w+border*2, -- leave some space for the "gui"
	sdl_height = frame_h+border*2+gui_h,
	limit_fps = 30
}, arg)
cio:init()


-- load font
local img_db = ldb.bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")
local char_to_tile = dofile("./examples/data/8x8_font_max1220.lua")
cio.font = ldb.bmpfont.new_bmpfont({
	db = img_db,
	char_w = 8,
	char_h = 8,
	scale_x = 1,
	scale_y = 1,
	char_to_tile = char_to_tile,
	color = {255,255,255}
})
cio.font_lg = ldb.bmpfont.new_bmpfont({
	db = img_db,
	char_w = 8,
	char_h = 8,
	scale_x = 2,
	scale_y = 2,
	char_to_tile = char_to_tile,
	color = {255,255,255}
})



-- called in cio:on_update() when a new frame is available
local last_frame = time.monotonic()
local function on_new_frame(data)
	local dt = time.monotonic() - last_frame
	logf("debug","frame %d completed in %.2f ms", frames_rendered,dt*1000)

	last_frame = time.monotonic()
	state.render_now = state.render_now + 1/fps
	target_db:load_data(data)
	if raw_file then
		raw_file:write(data)
	end
	frames_rendered = frames_rendered + 1
	lines_done = 0
	if frame_count == frames_rendered then
		-- render complete
		cio.run = false
	else
		-- request new frame
		renderer.send_requests()
	end
end

-- convert a duration to a human-readable string like "12minutes 34seconds"
local function seconds_to_str(seconds, aberviate)
	if seconds > 60*60 then
		local hours = math.floor(seconds/3600)
		local minutes = math.floor(seconds/60) % 60
		seconds = seconds % 60
		if aberviate then
			return ("%dhrs %dmin %dsec"):format(hours, minutes, seconds)
		else
			return ("%dhours %dminutes %dseconds"):format(hours, minutes, seconds)
		end
	elseif seconds > 60 then
		local remaining_m = math.floor(seconds/60)
		local remaining_s = seconds % 60
		if aberviate then
			return ("%dmin %dsec"):format(remaining_m, remaining_s)
		else
			return ("%dminutes %dseconds"):format(remaining_m, remaining_s)
		end
	else
		if aberviate then
			return ("%dsec"):format(seconds)
		else
			return ("%dseconds"):format(seconds)
		end
	end
end

function cio:on_event(ev)
end

function cio:on_draw(db)
	db:clear(32,32,32,255)

	if not disable_preview then
		db:rectangle(border-1,border-1,frame_w+1,frame_h+1, 0,0,0,255)
		if preview_scale>=1 then
			target_db:origin_to_target(db, border,border, nil,nil,nil,nil,preview_scale,preview_scale)
		elseif preview_scale>0 then
			for y=0, frame_h do
				for x=0,frame_w do
					local r,g,b,a = target_db:get_px(x*(1/preview_scale),y*(1/preview_scale))
					db:set_px(x+border,y+border,r,g,b,a)
				end
			end
		end
	end

	local lo = frame_h+border*2
	if disable_preview then
		lo = border
	end
	local lx = border
	local l1y,l2y,l3y,l4y,l5y,l6y = 0+lo,17+lo,35+lo,44+lo,53+lo,62+lo

	self.font_lg:draw_text(db, "Rendering",lx, l1y)

	self.font:draw_text(db, ("w=%d h=%d duration=%ds fps=%d"):format(w,h,duration,fps), lx, l2y)

	local frame_len = self.font:draw_text(db,  ("frame:  %4d/%4d:"):format(lines_done,h), border, l3y)
	local frame_pct = lines_done/h
	local frame_bar_width = frame_w-frame_len
	local frame_bar_len = frame_pct*(frame_w-frame_len)-2
	db:rectangle(lx+frame_len, l3y, frame_bar_width, 8, 0,0,0,255)
	db:rectangle(lx+frame_len+1, l3y+1, frame_bar_len, 6, 255,255,255,255)

	local frames_len = self.font:draw_text(db, ("frames: %4d/%4d:"):format(frames_rendered,frame_count), border, l4y)
	--local total_pct = (frames_rendered*h+lines_done)/(frame_count*h)
	local total_pct = frames_rendered/frame_count
	local total_bar_width = frame_w-frames_len
	local total_bar_len = total_pct*(frame_w-frames_len)-2
	db:rectangle(lx+frames_len, l4y, total_bar_width, 8, 0,0,0,255)
	db:rectangle(lx+frames_len+1, l4y+1, total_bar_len, 6, 255,255,255,255)

	local now = time.realtime()
	local elapsed = now-self.started
	local remaining = elapsed*(1/total_pct)-elapsed
	self.font:draw_text(db, "Elapsed: "..seconds_to_str(elapsed, true), border, l5y)
	self.font:draw_text(db, "Remaining: "..seconds_to_str(remaining, true), border, l6y)
end

function cio:on_update(dt)
	while true do
		local frame = renderer.get_frame(0)
		if frame then
			on_new_frame(frame)
		else
			break
		end
	end
	lines_done = renderer.get_progress() or 0
end

function cio:on_close()
	self.run = false
end

-- send requst for first frame(on_new_frame sends new requests)
renderer.send_requests()

cio.run = true
cio.started = time.realtime()
while cio.run do
	cio:update()
end

local elapsed = time.realtime()-cio.started
logf("info","Rendering took %.2fs", elapsed)
