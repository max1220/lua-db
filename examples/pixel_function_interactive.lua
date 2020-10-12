#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")
local effil = require("effil")
local args_parse = require("lua-db.args_parse")
local px_f = require("lua-db.pixel_function")

-- parse arguments
local render_w = args_parse.get_arg_num(arg, "render_width", 320)
local render_h = args_parse.get_arg_num(arg, "render_height", 240)
local callback_path = args_parse.get_arg_str(arg, "callback", "./examples/data/callback_sdf_shape.lua")
local threads = args_parse.get_arg_num(arg, "threads", effil.hardware_threads()+1)
local stride = args_parse.get_arg_num(arg, "stride", 32)
local method = args_parse.get_arg_str(arg, "method","ffi_shared_buf")
if not ((method == "simple") or (method == "ffi") or (method == "ffi_shared_buf")) then
	error("Unknown method selected:" .. method)
end

local log,logf = args_parse.logger_from_args(arg, "info","warn","err","debug")

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = render_w, -- leave some space for the "gui"
	sdl_height = render_h,
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

local output_scale = 1 --cio.output_scale_x

-- create a drabuffer to render to
local render_db = ldb.new_drawbuffer(render_w,render_h,ldb.pixel_formats.rgb888)

local state = effil.table()
state.t = 0
state.dt = 0
state.interactive = true
state.mandel_x = 0
state.mandel_y = 0
state.mandel_zoom = 1
state.raymarching_camera_x = 0
state.raymarching_camera_y = 0
state.raymarching_camera_z = -5
state.raymarching_camera_fov = 90
state.raymarching_max_iter = 100
state.raymarching_max_dist = 6

logf("info","render parameters: width=%d height=%d threads=%d stride=%d method=%s",render_w,render_h,threads,stride,method)
logf("info","config parameters: output_scale=%f callback_path=%q",output_scale, callback_path)

local function per_worker_simple(w,h,bpp,worker_arg)
	local per_pixel_callback,per_frame_callback = dofile(callback_path)(w,h,bpp) -- load the callback function for a width, height, bpp
	local function per_frame_cb(seq)
		if per_frame_callback then
			return per_frame_callback(seq,state)
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
	local per_pixel_callback,per_frame_callback = dofile(callback_path)(w,h,bpp) -- load the callback function for a width, height, bpp
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
	renderer = px_f.multithread_pixel_function_simple(render_w,render_h,3,threads,per_worker_simple)
elseif method == "ffi" then
	renderer = px_f.multithread_pixel_function_ffi(render_w,render_h,3,threads,stride,per_worker_ffi)
elseif method == "ffi_shared_buf" then
	renderer = px_f.multithread_pixel_function_ffi_shared_buf(render_w,render_h,3,threads,stride,per_worker_ffi)
end
renderer.start()





local mouse = {x=0,y=0,lmb=false,rmb=false,mmb=false}
local keys = {}
function cio:on_event(ev)
	if ev.type == "mousemotion" then
		mouse.x = ev.x
		mouse.y = ev.y
		mouse.xrel = ev.xrel
		mouse.yrel = ev.yrel
	elseif ev.type == "mousebuttondown" then
		if ev.button == 1 then
			mouse.lmb = true
		end
	elseif ev.type == "mousebuttonup" then
		if ev.button == 1 then
			mouse.lmb = false
		end
	elseif ev.type == "keydown" then
		keys[ev.key] = true
	elseif ev.type == "keyup" then
		keys[ev.key] = false
	end
end

function cio:on_draw(target_db)
	-- upscale the render_db content to the target_db
	render_db:origin_to_target(target_db, nil,nil,nil,nil,nil,nil,output_scale,output_scale)
	self.font:draw_text(target_db, ("%6.2fFPS"):format(1/state.dt),0,0)
end

local start = time.monotonic()
function cio:on_update(dt)
	logf("debug", "Frame time: %.2fms (%.2f FPS)", dt*1000, 1/dt)
	-- update renderer state
	state.t = time.monotonic() - start
	state.dt = dt
	state.mouse_x = mouse.x
	state.mouse_y = mouse.y
	state.mouse_lmb = mouse.lmb

	local raymarching = true
	if raymarching then
		if keys.W then
			state.raymarching_camera_z = dt + state.raymarching_camera_z
		elseif keys.S then
			state.raymarching_camera_z = -dt + state.raymarching_camera_z
		end
		if keys.A then
			state.raymarching_camera_x = -dt + state.raymarching_camera_x
		elseif keys.D then
			state.raymarching_camera_x = dt + state.raymarching_camera_x
		end
		if keys.Q then
			state.raymarching_camera_y = dt + state.raymarching_camera_y
		elseif keys.E then
			state.raymarching_camera_y = -dt + state.raymarching_camera_y
		end
		logf("debug", "raymarching_camera_x=%.2f, raymarching_camera_z=%.2f, raymarching_camera_y=%.2f, raymarching_camera_fov=%.2f", state.raymarching_camera_x, state.raymarching_camera_z, state.raymarching_camera_y, state.raymarching_camera_fov)
	end

	local mandel = true
	if mandel then
		if keys.Left then
			state.mandel_x = math.min(math.max(-dt*state.mandel_zoom + state.mandel_x, 0), 1)
		elseif keys.Right then
			state.mandel_x = math.min(math.max(dt*state.mandel_zoom + state.mandel_x, 0), 1)
		end
		if keys.Up then
			state.mandel_y = math.min(math.max(-dt*state.mandel_zoom + state.mandel_y, 0), 1)
		elseif keys.Down then
			state.mandel_y = math.min(math.max(dt*state.mandel_zoom + state.mandel_y, 0), 1)
		end
		if keys["+"] then
			state.mandel_zoom = state.mandel_zoom + state.mandel_zoom*dt
			state.raymarching_camera_fov = -dt*5 + state.raymarching_camera_fov
		elseif keys["-"] then
			state.mandel_zoom = state.mandel_zoom - state.mandel_zoom*dt
			state.raymarching_camera_fov = dt*5 + state.raymarching_camera_fov
		end
	end

	--local frame = renderer.get_frame(0)
	--if frame then -- non-blocking check for a frame
	--	render_db:load_data(frame) -- load the returned rendered image data into the render_db
	--	renderer.send_requests() -- send request for a new frame
	--end

	-- render the frame
	local frame = renderer.get_frame() -- blocking wait for a frame
	renderer.send_requests() -- send request for a new frame
	render_db:load_data(frame) -- load the returned rendered image data into the render_db
end

function cio:on_close()
	self.run = false
end

-- send the initial frame rendering request
renderer.send_requests()

cio.run = true
cio.started = time.realtime()
while cio.run do
	cio:update()
end

local elapsed = time.realtime()-cio.started
logf("info","Stopped after %.2fs", elapsed)
