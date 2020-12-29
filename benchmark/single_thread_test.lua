#!/usr/bin/env luajit
local ffi = require("ffi")
local time = require("time")

local args_parse = require("lua-db.args_parse")

local byte_per_pixel = 3
local render_w = args_parse.get_arg_num(arg, "render_width", 640)
local render_h = args_parse.get_arg_num(arg, "render_height", 640)
local callback_path = args_parse.get_arg_str(arg, "callback", "./examples/data/callback_basic.lua")

local cdef = [[
void *malloc(size_t size);
void free(void *ptr);
]]
ffi.cdef(cdef)

local len = render_w*render_h*byte_per_pixel
local _buf = ffi.gc(ffi.C.malloc(render_w*render_h*byte_per_pixel), ffi.C.free)
local buf = ffi.cast("uint8_t*", _buf)

local per_pixel_callback,per_frame_callback = dofile(callback_path)(render_w,render_h,byte_per_pixel)

local function render()
	for y=0, render_h-1 do
		for x=0, render_w-1 do
			local r,g,b = per_pixel_callback(x,y)
			local i = y*render_w*byte_per_pixel+x*byte_per_pixel
			buf[i] = r
			buf[i+1] = g
			buf[i+2] = b
		end
	end
end

local seq = 0
local per_frame = {
	t = 0,
	dt = 0,
	interactive = true,
	raymarching_camera_x = 0,
	raymarching_camera_y = -2.5,
	raymarching_camera_z = 3,
	raymarching_camera_fov = 170,
	raymarching_max_iter = 100
}
local start = time.monotonic()
for i=1, 300 do
	local frame_start = time.monotonic()
	if per_frame_callback then
		per_frame_callback(seq, per_frame)
	end
	render()
	local now = time.monotonic()
	local dt = now-frame_start
	per_frame.dt = dt
	per_frame.t = now-start
	seq = seq + 1
	print(("%.4d Frame time: %7.2f (%5.2f FPS, %5.2f MB/s)"):format(i, dt, 1/dt, (1/dt)*len*0.000001 ))
end
print(("Total: %.3fs"):format(time.monotonic()-start))
