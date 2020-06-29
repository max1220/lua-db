#!/usr/bin/env luajit
-- this example draws the Lua logo(Using graphics primitives)
local ldb = require("lua-db")


-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = 600,
	sdl_height = 600,
	output_scale_x = 1,
	output_scale_y = 1,
	sdl_title = "Lua!",
	limit_fps = 10,
}, arg)
cio:init()
local w,h = cio:get_native_size()
local min_d = math.min(w,h)
local min_hd = min_d/2

-- text lines
local lines = {
	-- x0, y0, x1, y1 in range 0-80

	-- L
	{21,36, 21,54},
	{21,54, 31,54},

	-- u
	{35,41, 35,52},
	{44,41, 44,54},
	{35,52, 37,54},
	{37,54, 41,54},
	{44,51, 41,54},

	-- a
	{50,52, 52,54},
	{52,54, 56,54},
	{59,51, 56,54},
	{50,52, 50,50},
	{50,50, 53,47},
	{53,47, 59,47},
	{59,44, 59,54},
	{59,44, 56,41},
	{56,41, 53,41},
	{53,41, 51,43}
}

-- background circles
local circles = {
	--x,y(in range 0-80), radius, r,g,b,a
	{40,40, 29,   0,  0,127,255},
	{70,10,  8,   0,  0,127,255},
	{52,28,  8, 255,255,255,255}
}


local bg_color = {255,255,255,255}
local text_radius = (1.1/80)*min_d
local text_color = {255,255,255,255}

local dotted_angle = 1.5
local dotted_divs = 36
local dotted_radius = min_hd*0.95
local dotted_width = (0.8/80)*min_hd
local dotted_cutoff_min = 30
local dotted_cutoff_max = 33
local dotted_speed = 4
local dotted_color = {127,127,127,155}

local t = 0
function cio:on_update(dt)
	t = t + dt
end

function cio:on_draw(db)
	-- clear screen
	db:clear(unpack(bg_color))

	-- draw background circles
	for _, circle in ipairs(circles) do
		local x,y,radius,r,g,b,a =  circle[1],circle[2], circle[3], circle[4],circle[5],circle[6],circle[7]
		x = (x/80)*min_d
		y = (y/80)*min_d
		radius = (radius/80)*min_d
		db:circle(x,y,radius,r,g,b,a,false, true)
	end

	-- draw text lines
	local text_r,text_g,text_b,text_a = unpack(text_color)
	for _, line in ipairs(lines) do
		local x0, y0, x1, y1 = line[1], line[2], line[3], line[4]
		x0 = (x0/80)*min_d
		y0 = (y0/80)*min_d
		x1 = (x1/80)*min_d
		y1 = (y1/80)*min_d
		db:line(x0, y0, x1, y1, text_r,text_g,text_b,text_a, text_radius)
	end

	-- draw dotted outline, skip doted line in upper-right corner
	local div_deg = 360/dotted_divs
	local div_deg_h = div_deg/2
	local dotted_r,dotted_g,dotted_b,dotted_a = unpack(dotted_color)
	for ideg=div_deg_h, 360-div_deg_h, div_deg do
		local deg = (ideg+t*dotted_speed)%360
		if not ((deg > dotted_cutoff_min*div_deg) and (deg<dotted_cutoff_max*div_deg)) then
			local x0 = min_hd + math.cos(math.rad(deg+dotted_angle))*dotted_radius
			local y0 = min_hd + math.sin(math.rad(deg+dotted_angle))*dotted_radius
			local y1 = min_hd + math.sin(math.rad(deg-dotted_angle))*dotted_radius
			local x1 = min_hd + math.cos(math.rad(deg-dotted_angle))*dotted_radius
			db:line(x0,y0,x1,y1, dotted_r,dotted_g,dotted_b,dotted_a, dotted_width)
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
