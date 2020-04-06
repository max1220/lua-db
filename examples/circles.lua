#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")


-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "terminal",
	default_terminal_mode = "halfblocks",
	terminal_bpp24 = true
}, arg)
cio:init()


-- create drawbuffer of native display size
local w,h = cio:get_native_size()
local output_db = ldb.new_drawbuffer(w,h)


-- make sure we don't get the same random colors every time
math.randomseed(time.realtime())


-- generate circles of increasing radius, with random colors
local circles = {}
local max_radius = math.sqrt(w*w+h*h)*0.6
local circle_count = 10
for i=1, circle_count do
	table.insert(circles, {
		radius = (i/circle_count)*max_radius,
		color = {
			math.random(1,8)*32-1,
			math.random(1,8)*32-1,
			math.random(1,8)*32-1,
		}
	})
end


local function update_circles(dt)
	-- update circle radius, and reset circle radius if needed
	for i=1, #circles do
		local circle = circles[i]
		circle.radius = circle.radius + dt*20

		if circle.radius >= max_radius then
			-- circle grew to large for screen, reset
			circle.radius = 1
			circle.color = {
				math.random(1,8)*32-1,
				math.random(1,8)*32-1,
				math.random(1,8)*32-1,
			}

			-- make sure render order is preserved!
			table.insert(circles, table.remove(circles, i))
		end
	end
end


local last = time.realtime()
while not cio.stop do
	local now = time.realtime()
	local dt = now - last
	last = now

	output_db:clear(0,0,0,255)

	-- update circles radius
	update_circles(dt)

	-- draw circles to drawbuffer
	for i=1, #circles do
		local circle = circles[i]
		output_db:circle(w/2, h/2, circle.radius, circle.color[1], circle.color[2], circle.color[3], 255)
	end

	-- draw drawbuffer to output
	cio:update_output(output_db)
	cio:update_input()
end
