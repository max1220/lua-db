#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")


-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "framebuffer",
	framebuffer_dev = "/dev/fb0"
}, arg)
cio:init()

-- get native display size
local w,h = cio:get_native_size()
local now = time.realtime()
local start, last, dt, running = now, now, 0, 0


local _min,_max,_sin,_cos,_tanh,_pi = math.min,math.max,math.sin,math.cos,math.tanh,math.pi


-- create a drawbuffer for each pixel format, and use draw_colors on it
local output_db = ldb.new_drawbuffer(w,h, ldb.pixel_formats.abgr8888)

local function new_element(parent)
	local element = {}
	element.type = "element"
	element.children = {}
	element.translate_x = 0
	element.translate_y = 0
	element.rotation = nil
	element.parent = parent
	if parent then
		table.insert(parent.children, element)
	end

	function element:translate_point(x,y)
		x = x - self.translate_x
		y = y - self.translate_y
		if self.rotation then
			local sin = _sin(self.rotation)
			local cos = _cos(self.rotation)
			x = cos*x + sin*y
			y = cos*y - sin*x
		end
		return x,y
	end

	function element:distance_union(dist1, dist2)
		return _min((dist1 or math.huge), (dist2 or math.huge))
	end

	function element:get_distance(x,y)
		x,y = self:translate_point(x,y)
		local dist
		if self.distance then
			dist = self:distance(x,y)
		end
		for i=1, #self.children do
			dist = self:distance_union(dist, self.children[i]:get_distance(x,y))
		end
		return dist
	end

	return element
end

local function new_subtraction(parent)
	local subtraction_element = new_element(parent)
	subtraction_element.type = "subtraction_element"

	function subtraction_element:distance_union(dist1, dist2)
		return math.max(-(dist1 or -math.huge), (dist2 or -math.huge))
	end

	return subtraction_element
end

local function new_intersection(parent)
	local intersection_element = new_element(parent)
	intersection_element.type = "intersection_element"

	function intersection_element:distance_union(dist1, dist2)
		return math.max((dist1 or -math.huge), (dist2 or -math.huge))
	end

	return intersection_element
end

local function new_circle(parent, _radius)
	local circle_element = new_element(parent)
	circle_element.radius = assert(tonumber(_radius))

	function circle_element:distance(x,y)
		x,y = self:translate_point(x,y)
		return math.sqrt(x*x+y*y)-self.radius
	end

	return circle_element
end

local moving_circles = {}
local function union_test(parent, r)
	local still_circle = new_circle(parent, r)
	local moving_circle = new_circle(parent, r)
	table.insert(moving_circles, moving_circle)
end
local function union_test_update()
	for _, moving_circle in ipairs(moving_circles) do
		moving_circle.translate_x = math.sin(running)*moving_circle.radius
	end
end


local scene = new_element()

local normal = new_element(scene)
normal.translate_x = w*0.15
normal.translate_y = h*0.1
union_test(normal, w*0.05)

local subtraction = new_subtraction(scene)
subtraction.translate_x = w*0.15
subtraction.translate_y = h*0.3
union_test(subtraction, w*0.05)

local intersection = new_intersection(scene)
intersection.translate_x = w*0.15
intersection.translate_y = h*0.5
union_test(intersection, w*0.05)



local function get_color(dist)
	local r,g,b,a = 0,0,0,255
	if dist > 0 then
		--r = (_sin(dist*_pi*0.5)+1)*_tanh(10/dist)*127
		--r = 255
		r = _tanh(dist)*255
	else
		--g = (_sin(dist*_pi*0.5)+1)*127
		--g = 255
		g = _tanh(-dist)*255
	end
	return r,g,b,a
end

local function get_pixel(x,y)
	local dist = scene:get_distance(x,y)
	return get_color(dist)
end


while not cio.stop do
	-- draw drawbuffer to cio output, handle input events
	now = time.realtime()
	dt = now-last
	last = now
	running = now-start
	print("dt:",dt,"fps:",1/dt,"running",running, "mem:",collectgarbage("count"))
	--print("get_pixel", get_pixel(0,0))
	--print("distance", normal:get_distance(0,0))

	union_test_update()

	if running > 10 then
		return
	end

	output_db:pixel_function(get_pixel)

	cio:update_output(output_db)
	cio:update_input()
end
