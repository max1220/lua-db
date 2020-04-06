#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")

math.randomseed(time.realtime())

local cio = ldb.input_output.new_from_args({
	default_mode = "terminal",
}, arg)
cio:init()
local w,h = cio:get_native_size()
local db = ldb.new_drawbuffer(w,h)


local colors = {}
local function random_colors()
	colors = {}
	for i=1, 5 do
		table.insert(colors, {math.random(1,16)*16-1, math.random(1,16)*16-1, math.random(1,16)*16-1})
	end
end
random_colors()

local cx,cy = w/2,h/2
local i = 0
while true do

	local c = math.random(1, #colors)
	db:triangle(0,0,w-1,0,cx,cy-i, colors[c][1], colors[c][2], colors[c][3],255)

	c = math.random(1, #colors)
	db:triangle(0,0,0,h-1,cx-i,cy, colors[c][1], colors[c][2], colors[c][3],255)

	c = math.random(1, #colors)
	db:triangle(0,h-1,w-1,h-1,cx,cy+i, colors[c][1], colors[c][2], colors[c][3],255)

	c = math.random(1, #colors)
	db:triangle(w-1,0,w-1,h-1,cx+i,cy, colors[c][1], colors[c][2], colors[c][3],255)

	--cx = (cx + math.random()*2-1) % w
	--cy = (cy + math.random()*2-1) % h

	i = i + math.min(w,h)*(1/10)

	if (i>w*0.5) and (i>h*0.5) then
		i = 0
		db:clear(0,0,0,255)
		random_colors()
	end

	-- draw drawbuffer to output
	cio:update_output(db)
	cio:update_input()

	--sleep between draws
	time.sleep(0.1)
end
