#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")

math.randomseed(time.realtime())

local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = 640,
	sdl_height = 480,
	sdl_title = "Rectangles example",
	limit_fps = 30
}, arg)
cio:init()
local w,h = cio:get_native_size()
local db = ldb.new_drawbuffer(w,h)
cio.target_db = db

local cw,ch = w,h
local cx,cy = 0,0
local dir_x = true
local dir_y = true

local timeout = 0.1
local remaining = 0

function cio:on_update(dt)
	remaining = remaining - dt
	if remaining >= 0 then
		return
	end
	remaining = timeout

	db:rectangle(cx,cy,cw,ch,math.random(1,16)*16-1,math.random(1,16)*16-1,math.random(1,16)*16-1,255)
	local nx,ny = cx,cy
	local nw,nh = cw,ch

	if cw>ch then
		local f = 1/(math.random(1,2)*2)
		if dir_x then
			nx = nx + cw*f
		end
		nw = nw *f
	else
		local f = 1/(math.random(1,2)*2)
		if dir_y then
			ny = ny + ch*f
		end
		nh = nh *f
	end

	cx,cy = nx,ny
	cw,ch = nw,nh

	if (cw<1) and (ch<1) then
		cw,ch = w,h
		cx,cy = 0,0
		if math.random(1,2)==1 then
			dir_x = not dir_x
		end
		if math.random(1,2)==1 then
			dir_y = not dir_y
		end
	end

end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
