#!/usr/bin/env luajit
local ldb = require("lua-db")
local input = require("lua-input")
local time = require("time")
local sdl2fb = require("sdl2fb")
local perlin = require("perlin")


-- setup drawing
local w = tonumber(arg[2]) or 160
local h = tonumber(arg[3]) or 120
local scale = tonumber(arg[4]) or 3
local sdlfb = sdl2fb.new(w*scale, h*scale, "3D example")
local db = ldb.new(w,h)
local db_scaled
if scale > 1 then
	db_scaled = ldb.new(w*scale,h*scale)
end
db:clear(0,0,0,255)


-- setup input
local input_dev = assert(input.open(arg[1] or "/dev/input/event0", true))





-- translated 3d points etc. will be stored here
local points_cache = {}

-- output 2d points
local points_2d = {}

-- point color index
local colors = {
	{255,  0,  0, 255},
	{  0,255,  0, 255},
	{  0,  0,255, 255},
	{255,255,  0, 255},
	{255,  0,255, 255},
	{  0,255,255, 255},
	{127,255,  0, 255},
	{127,  0,255, 255},
	{  0,127,255, 255},
	{255,127,  0, 255},
	{255,  0,127, 255},
	{  0,255,127, 255},
	{255,255,255, 255}
}

-- source points
local points = {}





-- this table will contain the current key state for the keys listed below.
local keys = {}
for _,key_name in ipairs({"KEY_LEFT", "KEY_RIGHT", "KEY_W", "KEY_S", "KEY_A", "KEY_D", "KEY_Q", "KEY_E", "KEY_Z", "KEY_X", "KEY_LEFTSHIFT"}) do
	local key = { down = false }
	local code = assert(input.event_codes[key_name])
	keys[code] = key
	keys[key_name] = key
end


-- update key table(read keys)
local function update_input()
	local ev = input_dev:read()
	while ev do
		if ev.type == input.event_codes.EV_KEY then
			if keys[ev.code] then
				keys[ev.code].down = (ev.value ~= 0)
			end
		end
		ev = input_dev:read()
	end
end





-- add the offset to each point
local function translate_points(points, dx,dy,dz, new_points)
	local new_points = new_points or {}
	
	for i=1, #points do
		local x,y,z = points[i][1], points[i][2], points[i][3]
		new_points[i] = { x+dx, y+dy, z+dz, points[i][4] }
	end
	
	return new_points
end


-- rotates around the xz-plane
local function rotate_points_xz(points, angle, new_points)
	local new_points = new_points or {}

	for i=1, #points do
		local x,y,z = points[i][1], points[i][2], points[i][3]

		local new_x = x * math.cos(angle) - z * math.sin(angle)
		local new_z = x * math.sin(angle) + z * math.cos(angle)
		
		new_points[i] = {new_x,y,new_z, points[i][4]}
	end

	return new_points
end


-- camera is always at origin(0,0,0)
local function project_3d_to_2d(points_3d, points_2d)
	local points_2d = points_2d or {}

	for i=1, #points_3d do
		local x,y,z = points_3d[i][1], points_3d[i][2], points_3d[i][3]
		local f = 0.8
		local px = x*(f/z)
		local py = y*(f*(w/h)/z)
		points_2d[i] = {px,py,(f/z), points_3d[i][4], math.sqrt(x^2+y^2+z^2)}
	end

	return points_2d
end


-- proper perspective projection
local function project_3d_to_2d_foo(points_3d, points_2d, camera)
	-- see: https://en.wikipedia.org/wiki/3D_projection#Perspective_projection
	local points_2d = points_2d or {}

	-- camera position and rotation
	local camera_x, camera_y, camera_z, camera_w, camera_h, camera_d = unpack(camera)

	local _sin = math.sin
	local _cos = math.cos

	for i=1, #points_3d do
		local point_x, point_y, point_z = points_3d[i][1], points_3d[i][2], points_3d[i][3]
		
		point_x = point_x - camera_x
		point_y = point_y - camera_y
		point_z = point_z - camera_z
		
		-- camera transform
		local dx = _cos(camera_h) * ( _sin(camera_d)*point_y + _cos(camera_d)*point_x) - _sin(camera_h*point_z )
		local dy = _sin(camera_w) * ( _cos(camera_h)*point_z + _sin(camera_h)*( _sin(camera_d)*point_y + _cos(camera_d)*point_x ) ) + _cos(camera_w)*(_cos(camera_d)*point_y + _sin(camera_d)*point_x)
		local dz = _cos(camera_h) * ( _cos(camera_h)*point_z + _sin(camera_h)*( _sin(camera_d)*point_y + _cos(camera_d)*point_x ) ) - _cos(camera_w)*(_cos(camera_d)*point_y + _sin(camera_d)*point_x)
		
		local ez = 1
		local ex = 0
		local ey = 0
		
		local bx = (ez/dz)*dx+ex
		local by = (ez/dz)*dy+ey
		
		table.insert(points_2d, {bx, by, 1/ez, points_3d[i][4]})
		
	end

	return points_2d
end


-- also normailzes 2d points
local function draw_points(points_2d)
	local _floor = math.floor
	for i=1, #points_2d do
		local x,y,d,color,dist = points_2d[i][1], points_2d[i][2], points_2d[i][3], points_2d[i][4], points_2d[i][5]
		local r,g,b,a = 255,255,255,255
		if points_2d[i][4] then
			r,g,b,a = unpack(colors[points_2d[i][4]])
		end
		local sx = _floor(((x+1)/2)*w)
		local sy = _floor(((y+1)/2)*h)
		if d <= 0 then
			local i = (10/dist*2)
			if dist < 10 then
				db:set_pixel_alphablend(sx,sy,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx-1,sy,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx+1,sy,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx,sy-1,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx,sy+1,r,g,b,math.max(math.min(i*255, 255), 20))
			elseif dist < 20 then
				db:set_pixel_alphablend(sx-1,sy,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx+1,sy,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx,sy-1,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx,sy+1,r,g,b,math.max(math.min(i*255, 255), 20))
			elseif dist < 30 then
				db:set_pixel_alphablend(sx,sy,r,g,b,math.max(math.min(i*255, 255), 20))
				db:set_pixel_alphablend(sx+1,sy+1,r,g,b,math.max(math.min(i*255, 255), 20))
			else
				db:set_pixel_alphablend(sx,sy,r,g,b,math.max(math.min(i*255, 255), 20))
			end
		end
	end
end





-- draw to output
local function output_db(db, set_cursor)
	if scale > 1 then
		db:draw_to_drawbuffer(db_scaled, 0,0,0,0,w,h,scale)
	end
	
	sdlfb:draw_from_drawbuffer(db_scaled or db,0,0)
	local ev = sdlfb:pool_event()
	if ev and ev.type == "quit" then
		sdlfb:close()
		os.exit(0)
	end
end


-- add a cube
local function add_cube(x,y,z, w,h,d, points, color)
	local points = points or {}
	
	table.insert(points, {x+0, y+0, z+0, color})
	table.insert(points, {x+0, y+0, z+d, color})
	table.insert(points, {x+0, y+h, z+0, color})
	table.insert(points, {x+w, y+0, z+0, color})
	table.insert(points, {x+0, y+h, z+d, color})
	table.insert(points, {x+w, y+h, z+0, color})
	table.insert(points, {x+w, y+0, z+d, color})
	table.insert(points, {x+w, y+h, z+d, color})
	
	return points
end


-- load the .obj file into a set of points
local function load_obj(filename, points, color, ox, oy, oz)
	local ox = tonumber(ox) or 0
	local oy = tonumber(oy) or 0
	local oz = tonumber(oz) or 0
	local points = points or {}
	for line in io.lines(filename) do
		local x,y,z = line:match("^v%s+(.+)%s+(.+)%s+(.+)$")
		if x and y and z then
			x = tonumber(x) + ox
			y = tonumber(y) + oy
			z = tonumber(z) + oz
			table.insert(points, {x,y,z,color})
		end
	end
	return points
end


-- add coordinate markers
for i=0, 30, 0.5 do
	table.insert(points, {i,0,0,1})
	table.insert(points, {0,i,0,2})
	table.insert(points, {0,0,i,3})
	table.insert(points, {-i,0,0,4})
	table.insert(points, {0,-i,0,5})
	table.insert(points, {0,0,-i,6})
end


-- add ground
math.randomseed(os.time())
local seed = math.random(1, 2^16)
for z=1, 100,1 do
	for x=1, 100,1 do
		local v = perlin.noise2d(x,z, 0.05, 8, seed)
		v = (v * 1.9)^3
		table.insert(points, {x-50, v*3-2, z-50, 6})
	end
end


-- add cubes
for i=1, 30 do
	local s = 2^math.random(2,5)
	add_cube(math.random(-100,100),math.random(50,100),math.random(-100,100), s, s, s, points, math.random(1,#colors))
end


-- add stars
for i=1, 100 do
	table.insert(points, { math.random(-10000, 10000), math.random(500, 10000), -10000,  13 })
	table.insert(points, { math.random(-10000, 10000), math.random(500, 10000), 10000,   13 })
	
	table.insert(points, { -10000, math.random(500, 10000), math.random(-10000, 10000),  13 })
	table.insert(points, { 10000, math.random(500, 10000), math.random(-10000, 10000),   13 })
end


-- add -obj
load_obj("../teapot.obj", points, 7, 0, 10, 0)





-- update point locations
local ctime = 0
local cx = 0
local cy = 0
local cz = -4
local speed = 4
local angle = 0
local function update_points(dt)
	ctime = ctime + dt

	-- translate to camera position
	
	if keys.KEY_LEFTSHIFT.down then
		speed = 8
	else
		speed = 4
	end
	
	if keys.KEY_A.down then
		cx = cx - dt*speed
	elseif keys.KEY_D.down then
		cx = cx + dt*speed
	end
	
	if keys.KEY_W.down then
		cz = cz + math.cos(angle*math.pi) * dt * speed
		cx = cx + math.sin(angle*math.pi) * dt * speed
	elseif keys.KEY_S.down then
		cz = cz - math.cos(angle*math.pi) * dt * speed
		cx = cx - math.sin(angle*math.pi) * dt * speed
	end
	
	
	if keys.KEY_Q.down then
		cy = cy + dt*speed
	elseif keys.KEY_E.down then
		cy = cy - dt*speed
	end
	
	
	if keys.KEY_Z.down then
		angle = angle - dt*0.5
	elseif keys.KEY_X.down then
		angle = angle + dt*0.5
	end
	
	-- move world so that the camera is at 0,0,0
	translate_points(points, cx, cy, cz, points_cache)
	
	-- apply x-z rotation
	rotate_points_xz(points_cache, angle*math.pi, points_cache)
	
	-- convert to 2d
	project_3d_to_2d(points_cache, points_2d)
	-- project_3d_to_2d_foo(points_cache, points_2d, {0,0,0, 0,0,0})
end

local last = time.realtime()
while true do
	local dt = time.realtime() - last
	last = time.realtime()
	
	db:clear(0,0,0,255)
	
	update_input()
	update_points(dt)
	draw_points(points_2d)
	
	output_db(db, true)
	
	io.write(("   FPS: %.3f  \t  #points: %.3f   \n"):format(1/dt, #points))
	-- io.write(("   cx: %3.3f   cy: %3.3f   cz: %3.3f   a: %2.2f   \n"):format(cx,cy,cz,angle))
end




