#!/usr/bin/env luajit
local ldb = require("lua-db")
local input = require("lua-input")
local time = require("time")
local sdl2fb = require("sdl2fb")
local perlin = require("perlin")


math.randomseed(os.time())

-- setup drawing
local w = tonumber(arg[1]) or 160
local h = tonumber(arg[2]) or 120
local scale = tonumber(arg[3]) or 3
local sdlfb = sdl2fb.new(w*scale, h*scale, "3D example")
local db = ldb.new(w,h)
local db_scaled
if scale > 1 then
	db_scaled = ldb.new(w*scale,h*scale)
end
db:clear(0,0,0,0)


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

-- source objects
local objects = {}

-- this table will contain the current key state for the keys listed below.
local keys_down = {}




-- add the offset to each point
local function translate_points(points, dx,dy,dz, new_points)
	local new_points = new_points or {}
	
	for i=1, #points do
		local point = points[i]
		if not point then break end
		local x,y,z,data = point[1], point[2], point[3], point[4]
		new_points[i] = { x+dx, y+dy, z+dz, data }
	end
	new_points[#points + 1] = nil
	
	return new_points
end


-- rotates around the xz-plane
local function rotate_points_xz(points, angle, new_points)
	local new_points = new_points or {}

	for i=1, #points do
		local point = points[i]
		if not point then break end
		local x,y,z,data = point[1], point[2], point[3], point[4]
		local new_x = x * math.cos(angle) - z * math.sin(angle)
		local new_z = x * math.sin(angle) + z * math.cos(angle)
		new_points[i] = {new_x,y,new_z, data}
	end
	new_points[#points + 1] = nil

	return new_points
end


-- camera is always at origin(0,0,0)
local function project_3d_to_2d(points_3d, points_2d, points_2d_offset, fill)
	local points_2d = points_2d or {}

	local j = 1+(tonumber(points_2d_offset) or 0)
	for i=1, #points_3d do
		local point = points_3d[i]
		if not point then break end
		local x,y,z,data = point[1], point[2], point[3], point[4]
		local f = 0.8
		local px = x*(f/z)
		local py = y*(f*(w/h)/z)
		
		if (f/z) < 0 then
			points_2d[j] = {px,py,math.sqrt(x^2 + y^2 + z^2), data}
			j = j + 1
		elseif fill then
			points_2d[j] = false
			j = j + 1
		end
		
	end
	points_2d[j] = nil
	return points_2d, j-1
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
		local point = points_2d[i]
		if not point then break end
		
		local x,y,dist,data = point[1], point[2], point[3], point[4]
		local r,g,b,a = 255,0,255,255
		if data then
			if data.color then
				r,g,b,a = colors[data.color][1],colors[data.color][2],colors[data.color][3]
			end
		end
		local sx = _floor(((x+1)/2)*w)
		local sy = _floor(((y+1)/2)*h)
		--if d <= 0 then
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
		--end
	end
end


-- draws all objects to the screen
local function draw_objects(db, objects)

	-- draw a single point based on it's distance
	local function set_point(db, sx,sy,r,g,b,dist)
		local i = (10/dist*2)
		local max = math.max
		local min = math.min
		local min_a = 20
		local max_a = 255
		local a = max(min(i, 1), 0)*(max_a-min_a)+min_a
		if dist < 10 then
			db:set_pixel_alphablend(sx,sy,r,g,b,a)
			db:set_pixel_alphablend(sx-1,sy,r,g,b,a)
			db:set_pixel_alphablend(sx+1,sy,r,g,b,a)
			db:set_pixel_alphablend(sx,sy-1,r,g,b,a)
			db:set_pixel_alphablend(sx,sy+1,r,g,b,a)
		elseif dist < 20 then
			db:set_pixel_alphablend(sx-1,sy,r,g,b,a)
			db:set_pixel_alphablend(sx+1,sy,r,g,b,a)
			db:set_pixel_alphablend(sx,sy-1,r,g,b,a)
			db:set_pixel_alphablend(sx,sy+1,r,g,b,a)
		elseif dist < 30 then
			db:set_pixel_alphablend(sx,sy,r,g,b,a)
			db:set_pixel_alphablend(sx+1,sy+1,r,g,b,a)
		else
			db:set_pixel_alphablend(sx,sy,r,g,b,a)
		end
	end

	-- draw a single line
	local function set_line(db, x1,y1,x2,y2,r,g,b,a)
		
	end

	-- draws a triangle on the screen
	local function set_triangle(db, x1,y1,x2,y2,x3,y3,r,g,b,a)
		db:fill_triangle(x1,y1,x2,y2,x3,y3,r,g,b,a)
	end

	local _w = w
	local _h = h
	local _floor = math.floor

	for i=1, #objects do
		local object = objects[i]
		if not object then break end
		
		if object.type == "points" then
			local r,g,b,a = object.color[1], object.color[2], object.color[3], object.color[4]
			for i=1, #object.points_2d do
				local point_2d = object.points_2d[i]
				if not point_2d then break end
				
				local x,y,dist = point_2d[1], point_2d[2], point_2d[3]
				local sx = _floor(((x+1)/2)*_w)
				local sy = _floor(((y+1)/2)*_h)
				
				set_point(db, sx,sy,r,g,b,dist)
				
			end
		elseif object.type == "triangles" then
			local hw = w/2
			local hh = h/2
			for i=1, #object.points_2d, 3 do
				local color = object.colors[(i-1)/3+1] or {255,0,255,255}
				local point_a = object.points_2d[i]
				local point_b = object.points_2d[i+1]
				local point_c = object.points_2d[i+2]
				if not (point_a and point_b and point_c) then break end
				-- TODO: better clipping
				
				local x1,y1,dist1 = point_a[1], point_a[2], point_a[3]
				local x2,y2,dist1 = point_b[1], point_b[2], point_b[3]
				local x3,y3,dist1 = point_c[1], point_c[2], point_c[3]

				set_triangle(db, x1*hw+hw, y1*hh+hh, x2*hw+hw, y2*hh+hh, x3*hw+hw, y3*hh+hh, color[1], color[2], color[3], color[4])
				
			end
		end
		
	end
end


-- generate a cube object
local function object_cube_points(x,y,z,w,h,d,r,g,b)
	local x = assert(tonumber(x))
	local y = assert(tonumber(y))
	local z = assert(tonumber(z))
	local w = assert(tonumber(w))
	local h = assert(tonumber(h))
	local d = assert(tonumber(d))
	
	local hw = w/2
	local hh = h/2
	local hd = d/2
	
	local cube_points = {
		{ -hw, -hh, -hd },
		{ -hw, -hh,  hd },
		{ -hw,  hh, -hd },
		{  hw, -hh, -hd },
		{ -hw,  hh,  hd },
		{  hw,  hh, -hd },
		{  hw, -hh,  hd },
		{  hw,  hh,  hd }
	}
	
	local cube_obj = {
		type = "points",
		color = { r,g,b,255 },
		position = { x,y,z },
		dimensions = { w,h,d },
		points = cube_points
	}
	
	return cube_obj
end


-- return 6 objects for the coordinate markers
local function object_coordinate_marker(len, step)
	
	local x_obj = {
		type = "points",
		color = {255,0,0,255},
		position = { 0,0,0 },
		points = {}
	}
	local y_obj = {
		type = "points",
		color = {0,255,0,255},
		position = { 0,0,0 },
		points = {}
	}
	local z_obj = {
		type = "points",
		color = {0,0,255,255},
		position = { 0,0,0 },
		points = {}
	}
	local xn_obj = {
		type = "points",
		color = {128,0,0,255},
		position = { 0,0,0 },
		points = {}
	}
	local yn_obj = {
		type = "points",
		color = {0,128,0,255},
		position = { 0,0,0 },
		points = {}
	}
	local zn_obj = {
		type = "points",
		color = {0,0,128,255},
		position = { 0,0,0 },
		points = {}
	}
	
	for i=0, len, step do
		table.insert(x_obj.points, { i, 0, 0 })
		table.insert(y_obj.points, { 0, i, 0 })
		table.insert(z_obj.points, { 0, 0, i })
		table.insert(xn_obj.points, { -i, 0, 0 })
		table.insert(yn_obj.points, {  0,-i, 0 })
		table.insert(zn_obj.points, {  0, 0,-i })
	end
	
	return x_obj, y_obj, z_obj, xn_obj, yn_obj, zn_obj
end


-- generate a single triangle object by all of it's coordiantes
local function object_triangle(x,y,z, points, colors)
	local triangle = {
		type = "triangles",
		position = { x,y,z },
		points = points,
		colors = colors
	}
	return triangle
end


-- generate a plane(2 triangles) on the xz-plane at the specified coordinates
local function object_plane_xz(x,y,z, w,d, r,g,b,a)
	local points = {
		{0,0,0},
		{w,0,0},
		{0,0,d},
		{w,0,d},
		{w,0,0},
		{0,0,d},
	}
	local color = {r,g,b,a}
	local triangle = object_triangle(x,y,z, points, {color, color})
	return triangle
end


local function object_from_obj(filename, x, y, z, r,g,b,a)
	
	local vertices = {}
	local points = {}

	for line in io.lines(filename) do
		local x,y,z = line:match("^v%s+(.+)%s+(.+)%s+(.+)$")
		if x and y and z then
			table.insert(vertices, {tonumber(x),tonumber(y),tonumber(z)})
		end
		
		local v1,v2,v3 = line:match("^f%s+(.+)%s+(.+)%s+(.+)$")
		if v1 and v2 and v3 then
			local p1 = assert(vertices[tonumber(v1)])
			local p2 = assert(vertices[tonumber(v2)])
			local p3 = assert(vertices[tonumber(v3)])
			table.insert(points, p1)
			table.insert(points, p2)
			table.insert(points, p3)
		end
	end
	
	local colors = {}
	for i=1, #points/3 do
		local b = math.random(128,255)
		--table.insert(colors, {math.random(0,255), math.random(0,255),math.random(0,255), 255})
		table.insert(colors, {b,b,b, 255})
	end
	
	print("object from obj:", #vertices, #points, #colors)
	
	local object = {
		type = "triangles",
		colors = colors,
		points = points,
		position = { x,y,z }
	}
	
	return object
	
end


-- get 2d positions for each object
local function objects_to_screen(objects, cx,cy,cz,r)
	for i=1, #objects do
		local object = objects[i]
		if not object then break end
		
		-- TODO: Check if object is in range
		
		local points = object.points
		local points_cache = object.points_cache or {}
		local points_2d = object.points_2d or {}
		
		
		if object.rotation then
			-- rotate object around it's local origin
			rotate_points_xz(points, object.rotation, points_cache)
			if object.position then
				-- translate object coordinates to global coordinates
				translate_points(points_cache, object.position[1], object.position[2], object.position[3], points_cache)
			end
		else
			if object.position then
				-- translate object coordinates to global coordinates
				translate_points(points, object.position[1], object.position[2], object.position[3], points_cache)
			end
		end
		
		
		-- translate global coordinates to camera coordinates
		translate_points(points_cache, cx, cy, cz, points_cache)
		
		-- rotate points around origin by camera rotation
		rotate_points_xz(points_cache, r, points_cache)
		
		-- project 3d points to 2d screen points with color information, also does clipping
		if object.type == "points" then
			project_3d_to_2d(points_cache, points_2d, offset)
		elseif object.type == "triangles" then
			-- triangles require the length of points to remain the same after clipping
			project_3d_to_2d(points_cache, points_2d, offset, true)
		end
		
		object.points_cache = points_cache
		object.points_2d = points_2d
		
	end
	return _points_2d
end


-- handle all outstanding SDL events
local function handle_sdl_events()
	local ev = sdlfb:pool_event()
	while ev do
		if ev.type == "quit" then
			sdlfb:close()
			os.exit(0)
		elseif ev.type == "keydown" then
			keys_down[ev.key] = true
		elseif ev.type == "keyup" then
			keys_down[ev.key] = false
		end
		ev = sdlfb:pool_event()
	end
end


-- scale and draw to SDL
local function output_db(db, set_cursor)
	if scale > 1 then
		db:draw_to_drawbuffer(db_scaled, 0,0,0,0,w,h,scale)
	end
	sdlfb:draw_from_drawbuffer(db_scaled or db,0,0)
end


-- add a cube to the points table
local function add_cube(x,y,z, w,h,d, points, color)
	local points = points or {}
	local data = {color=color}
	
	table.insert(points, {x+0, y+0, z+0, data})
	table.insert(points, {x+0, y+0, z+d, data})
	table.insert(points, {x+0, y+h, z+0, data})
	table.insert(points, {x+w, y+0, z+0, data})
	table.insert(points, {x+0, y+h, z+d, data})
	table.insert(points, {x+w, y+h, z+0, data})
	table.insert(points, {x+w, y+0, z+d, data})
	table.insert(points, {x+w, y+h, z+d, data})
	
	return points
end


-- load the .obj file into a points table
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
local seed = math.random(1, 2^16)
for z=1, 100,0.5 do
	for x=1, 100,0.5 do
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


table.insert(objects, object_cube_points(0,0,0,1,1,1,255,0,255))

local a,b,c,d,e,f = object_coordinate_marker(50, 1)
table.insert(objects, a)
table.insert(objects, b)
table.insert(objects, c)
table.insert(objects, d)
table.insert(objects, e)
table.insert(objects, f)


table.insert(objects, object_triangle(0,0,0, {{0,0,0}, {1,0,0}, {0,0,1}}, {{255,0,255,255}}))
table.insert(objects, object_plane_xz(-10, 0, -10, 3, 3, 64,0,64,255))


local teapot_obj = object_from_obj("../teapot.obj", -7, 0, -10)
teapot_obj.rotation = 0
table.insert(objects, teapot_obj)

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
	
	if keys_down["Left Shift"] then
		speed = 8
	else
		speed = 4
	end
	
	if keys_down["A"] then
		cz = cz + math.cos((angle-math.pi/2)) * dt * speed
		cx = cx + math.sin((angle-math.pi/2)) * dt * speed
	elseif keys_down["D"] then
		cz = cz - math.cos((angle-math.pi/2)) * dt * speed
		cx = cx - math.sin((angle-math.pi/2)) * dt * speed
	end
	
	if keys_down["W"] then
		cz = cz + math.cos(angle) * dt * speed
		cx = cx + math.sin(angle) * dt * speed
	elseif keys_down["S"] then
		cz = cz - math.cos(angle) * dt * speed
		cx = cx - math.sin(angle) * dt * speed
	end
	
	
	if keys_down["Q"] then
		cy = cy + dt*speed
	elseif keys_down["E"] then
		cy = cy - dt*speed
	end
	
	if keys_down["Y"] then
		angle = angle - dt*0.5
	elseif keys_down["X"] then
		angle = angle + dt*0.5
	end
	
	teapot_obj.rotation = teapot_obj.rotation + dt
	
	-- move world so that the camera is at 0,0,0
	--translate_points(points, cx, cy, cz, points_cache)
	
	-- apply x-z rotation
	--rotate_points_xz(points_cache, angle*math.pi, points_cache)
	
	-- convert to 2d
	-- points_2d = {}
	--project_3d_to_2d(points_cache, points_2d)
	-- project_3d_to_2d_foo(points_cache, points_2d, {0,0,0, 0,0,0})
	
	points_2d = objects_to_screen(objects, cx,cy,cz,angle)
	
end

local last = time.realtime()
while true do
	local dt = time.realtime() - last
	last = time.realtime()
	
	db:clear(0,0,0,255)
	
	handle_sdl_events()
	update_points(dt)
	
	-- draw generated list of 2d points to screen
	-- draw_points(points_2d)
	
	draw_objects(db, objects)
	
	output_db(db, true)
	
	-- io.write(("   FPS: %.3f  \t  2d points: %d   \n"):format(1/dt, #points_2d))
	-- io.write(("   cx: %3.3f   cy: %3.3f   cz: %3.3f   a: %2.2f   \n"):format(cx,cy,cz,angle))
end




