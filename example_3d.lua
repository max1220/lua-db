#!/usr/bin/env luajit
local ldb = require("lua-db.lua-db")
local time = require("time")
local sdl2fb = require("sdl2fb")
local braile = require("lua-db.braile")


-- add the offset to each point
local function translate_points(points, dx,dy,dz, new_points)
	local new_points = new_points or {}
	
	local j = 1
	for i=1, #points do
		local point = points[i]
		if not point then break end
		local x,y,z,data = point[1], point[2], point[3], point[4]
		new_points[i] = { x+dx, y+dy, z+dz, data }
		j = j + 1
	end
	new_points[j] = nil
	
	return new_points
end


-- rotates around the xz-plane
local function rotate_points_xz(points, angle, new_points)
	local new_points = new_points or {}

	local j = 1
	for i=1, #points do
		local point = points[i]
		if not point then break end
		local x,y,z,data = point[1], point[2], point[3], point[4]
		local new_x = x * math.cos(angle) - z * math.sin(angle)
		local new_z = x * math.sin(angle) + z * math.cos(angle)
		new_points[i] = {new_x,y,new_z, data}
		j = j + 1
	end
	new_points[j] = nil

	return new_points
end


-- translate 3d points to 2d points. camera is always at origin(0,0,0). ar is the aspect ratio(w/h).
local function project_3d_to_2d(points_3d, points_2d, ar, fill)
	local points_2d = points_2d or {}
	
	local j = 1
	for i=1, #points_3d do
		local point = points_3d[i]
		if not point then break end
		local x,y,z,data = point[1], point[2], point[3], point[4]
		local f = 1
		local px = x*(f/z)
		local py = y*(f*ar/z)
		
		if (f/z) < 0 then
			-- point is in front of the camera
			local dist = math.sqrt(x^2 + y^2 + z^2)
			points_2d[j] = {px,py,dist, data}
			j = j + 1
		elseif fill then
			-- if the fill flag is set, we need to keep the indexes valid, and "fill" the empty parts(with false)
			points_2d[j] = false
			j = j + 1
		end
		
	end
	
	points_2d[j] = nil
	return points_2d, j-1
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
		db:set_pixel_alphablend(sx,sy,r,g,b,a)
	end

	-- draw a single line
	local function set_line(db, x1,y1,x2,y2,r,g,b,a,dist)
		db:set_line(x1,y1,x2,y2,r,g,b,a)
		--db:set_line_anti_aliased(x1,y1,x2,y2,r,g,b,0.4+10*(1-math.tanh(dist*dist)))
	end

	-- draws a triangle on the screen
	local function set_triangle(db, x1,y1,x2,y2,x3,y3,r,g,b,a)
		db:fill_triangle(x1,y1,x2,y2,x3,y3,r,g,b,a)
	end

	local _w = db:width()
	local _h = db:height()
	local hw = _w/2
	local hh = _h/2
	local _floor = math.floor

	local triangle_draw_count = 0
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
			local colors = object._colors or object.colors
			local points_2d = object.points_2d
			for i=1, #object.points_2d, 3 do
				local color = colors[(i-1)/3+1] or {255,0,255,255}
				local point_a = points_2d[i]
				local point_b = points_2d[i+1]
				local point_c = points_2d[i+2]
				if not (point_a and point_b and point_c) then break end
				-- TODO: better clipping
				
				triangle_draw_count = triangle_draw_count + 1
				
				local x1,y1,dist1 = point_a[1], point_a[2], point_a[3]
				local x2,y2,dist2 = point_b[1], point_b[2], point_b[3]
				local x3,y3,dist3 = point_c[1], point_c[2], point_c[3]

				set_triangle(db, x1*hw+hw, y1*hh+hh, x2*hw+hw, y2*hh+hh, x3*hw+hw, y3*hh+hh, color[1], color[2], color[3], color[4])
				
				--set_line(db, x1*hw+hw,y1*hh+hh, x2*hw+hw,y2*hh+hh, 255,0,255,255)
				--set_line(db, x2*hw+hw,y2*hh+hh, x3*hw+hw,y3*hh+hh, 255,0,255,255)
				--set_line(db, x1*hw+hw,y1*hh+hh, x3*hw+hw,y3*hh+hh, 255,0,255,255)
				
			end
		elseif object.type == "lines" then
			--for i=1, #object.points_2d, 2 do
			for i=1, 0 do
				local color = object.colors[(i-1)/2+1] or {255,0,255,255}
				local point_a = object.points_2d[i]
				local point_b = object.points_2d[i+1]
				if not (point_a and point_b) then break end
				-- TODO: better clipping
				
				local x1,y1,dist1 = point_a[1], point_a[2], point_a[3]
				local x2,y2,dist2 = point_b[1], point_b[2], point_b[3]

				set_line(db, x1*hw+hw,y1*hh+hh, x2*hw+hw,y2*hh+hh, color[1],color[2],color[3], color[4], (dist1+dist2)/2)
			end
		else
			print("unknown obj", object.type)
		end
		
	end
	
	print("triangle_draw_count", triangle_draw_count)
end


-- generate a cube made of lines at the specified coordinates and size
local function object_cube_lines(x,y,z,w,h,d,r,g,b,a)
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
		{  hw, -hh, -hd },
		{ -hw, -hh, -hd },
		{ -hw,  hh, -hd },
		{ -hw,  hh, -hd },
		{  hw,  hh, -hd },
		{  hw,  hh, -hd },
		{  hw, -hh, -hd },

		{ -hw, -hh,  hd },
		{  hw, -hh,  hd },
		{ -hw, -hh,  hd },
		{ -hw,  hh,  hd },
		{ -hw,  hh,  hd },
		{  hw,  hh,  hd },
		{  hw,  hh,  hd },
		{  hw, -hh,  hd },

		{ -hw, -hh, -hd },
		{ -hw, -hh,  hd },
		{  hw, -hh, -hd },
		{  hw, -hh,  hd },
		{ -hw,  hh, -hd },
		{ -hw,  hh,  hd },
		{  hw,  hh, -hd },
		{  hw,  hh,  hd },
	}
	
	local colors = {}
	for i=1, #cube_points do
		colors[i] = {r,g,b,a}
	end
	
	local cube_obj = {
		type = "lines",
		colors = colors,
		position = { x,y,z },
		dimensions = { w,h,d },
		points = cube_points
	}
	
	return cube_obj
end


-- generate a cube made of triangle faces at the specified coordinates and size with the specified colors
local function object_cube_faces(x,y,z,w,h,d,colors)
	local x = assert(tonumber(x))
	local y = assert(tonumber(y))
	local z = assert(tonumber(z))
	local w = assert(tonumber(w))
	local h = assert(tonumber(h))
	local d = assert(tonumber(d))
	assert((#colors == 6) or (#colors == 12))
	
	local hw = w/2
	local hh = h/2
	local hd = d/2
	
	local cube_points = {}
	local function triangle(x1,y1,z1, x2,y2,z2, x3,y3,z3)
		local _x1 = (x1==1) and hw or -hw
		local _y1 = (y1==1) and hh or -hh
		local _z1 = (z1==1) and hd or -hd
		local _x2 = (x2==1) and hw or -hw
		local _y2 = (y2==1) and hh or -hh
		local _z2 = (z2==1) and hd or -hd
		local _x3 = (x3==1) and hw or -hw
		local _y3 = (y3==1) and hh or -hh
		local _z3 = (z3==1) and hd or -hd
		table.insert(cube_points, { _x1, _y1, _z1 })
		table.insert(cube_points, { _x2, _y2, _z2 })
		table.insert(cube_points, { _x3, _y3, _z3 })
	end
	
	triangle(0,0,1, 0,0,0, 1,0,0)
	triangle(0,0,1, 1,0,0, 1,0,1)
	
	triangle(1,1,0, 0,1,0, 0,1,1)
	triangle(1,1,1, 1,1,0, 0,1,1)
	
	
	triangle(1,0,0, 0,0,0, 0,1,0)
	triangle(0,1,0, 1,1,0, 1,0,0)
	
	triangle(0,0,1, 1,0,1, 0,1,1)
	triangle(1,1,1, 0,1,1, 1,0,1)
	
	
	triangle(0,0,0, 0,0,1, 0,1,0)
	triangle(0,0,1, 0,1,1, 0,1,0)
	
	triangle(1,0,1, 1,0,0, 1,1,0)
	triangle(1,1,1, 1,0,1, 1,1,0)
	
	
	if #colors == 6 then
		local _colors = {}
		for i, color in ipairs(colors) do
			table.insert(_colors, color)
			table.insert(_colors, color)
		end
		colors = _colors
	end
	
	local cube_obj = {
		type = "triangles",
		colors = colors,
		position = { x,y,z },
		dimensions = { w,h,d },
		points = cube_points
	}
	
	return cube_obj
	
end


-- return 6 objects for the coordinate markers
local function object_coordinate_marker(len, step)
	
	local x_obj = {
		type = "lines",
		colors = {},
		position = { 0,0,0 },
		points = {}
	}
	local y_obj = {
		type = "lines",
		colors = {},
		position = { 0,0,0 },
		points = {}
	}
	local z_obj = {
		type = "lines",
		colors = {},
		position = { 0,0,0 },
		points = {}
	}
	local xn_obj = {
		type = "lines",
		colors = {},
		position = { 0,0,0 },
		points = {}
	}
	local yn_obj = {
		type = "lines",
		colors = {},
		position = { 0,0,0 },
		points = {}
	}
	local zn_obj = {
		type = "lines",
		colors = {},
		position = { 0,0,0 },
		points = {}
	}
	
	for i=1, len, step do
		table.insert(x_obj.points, { i, 0, 0 })
		table.insert(y_obj.points, { 0, i, 0 })
		table.insert(z_obj.points, { 0, 0, i })
		table.insert(xn_obj.points, { -i, 0, 0 })
		table.insert(yn_obj.points, {  0,-i, 0 })
		table.insert(zn_obj.points, {  0, 0,-i })
		
		table.insert(x_obj.colors, { 255, 0, 0, 255 })
		table.insert(y_obj.colors, { 0, 255, 0, 255 })
		table.insert(z_obj.colors, { 0, 0, 255, 255 })
		table.insert(xn_obj.colors, {64, 0, 0, 255 })
		table.insert(yn_obj.colors, {  0,64, 0, 255 })
		table.insert(zn_obj.colors, {  0, 0,64, 255 })
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
		{w,0,0},
		{w,0,d},
		{0,0,d},
	}
	local color = {r,g,b,a}
	local triangle = object_triangle(x,y,z, points, {color, color})
	return triangle
end


-- load the wavefront .obj file into an object at the specified coordinates
local function object_from_obj(filename, x, y, z)
	
	local vertices = {}
	local points = {}

	local x_max, y_max, z_max = 0,0,0
	local x_min, y_min, z_min = math.huge,math.huge,math.huge


	for line in io.lines(filename) do
		local x,y,z = line:match("^v%s+(.+)%s+(.+)%s+(.+)$")
		if x and y and z then
			x_max = math.max(x_max, x)
			y_max = math.max(y_max, y)
			z_max = math.max(z_max, z)
			x_min = math.min(x_min, x)
			y_min = math.min(y_min, y)
			z_min = math.min(z_min, z)
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
	
	print("x_min, x_max", x_min, x_max)
	print("y_min, y_max", y_min, y_max)
	print("z_min, z_max", z_min, z_max)
	
	local w = x_max - x_min
	local h = y_max - y_min
	local d = z_max - z_min
	
	translate_points(points, 0, -h/2, 0, points)
	
	for i=1, #points do
		local p = points[i]
	end
	
	local object = {
		type = "triangles",
		colors = colors,
		points = points,
		position = { x,y,z },
		dimensions = { w,h,d }
	}
	
	return object
	
end


-- take a heightmap, and generates a triangles object for that heightmap.
local function object_ground_from_heightmap(heights, x,y,z, step, height, r,g,b,a)

	local max_h = 0
	local min_h = math.huge
	local hw = #heights[1]*step*0.5
	local hh = #heights*step*0.5

	local function get_height(x,y)
		local height = (heights[y] or {})[x]
		max_h = math.max(max_h, height)
		min_h = math.min(min_h, height)
		return height
	end

	local function get_heights(x,y)
		return {
			(get_height(  x,   y) or 0)*height,
			(get_height(x+1,   y) or 0)*height,
			(get_height(  x, y+1) or 0)*height,
			(get_height(x+1, y+1) or 0)*height
		}
	end

	local points = {}
	local colors = {}
	
	for y=1, #heights-1 do
		for x=1, #heights[y]-1 do
			local px1 = (x-1)*step
			local pz1 = (y-1)*step
			local px2 = x*step
			local pz2 = y*step
			local heights = get_heights(x,y)
			table.insert(points, { px2-hw, heights[2], pz1-hh })
			table.insert(points, { px1-hw, heights[1], pz1-hh })
			table.insert(points, { px1-hw, heights[3], pz2-hh })
			local b = math.random(32,64)
			table.insert(colors, {b,b,b,255})
			table.insert(points, { px2-hw, heights[2], pz1-hh })
			table.insert(points, { px1-hw, heights[3], pz2-hh })
			table.insert(points, { px2-hw, heights[4], pz2-hh })
			b = math.random(64,128)
			table.insert(colors, {b,b,b,255})
		end
	end
	
	local d = (math.abs(min_h) + math.abs(max_h)) * height
	local object = {
		type = "triangles",
		position = {x,y,z},
		dimensions = {hw*2,d,hh*2},
		points = points,
		colors = colors
	}
	
	return object
end


-- create a bunch of cubes from a heightmap
local function cubes_from_heightmap(heights, x,y,z, s, height)
	local cubes = {}

	local max_h = 0
	for x=1, #heights-1 do
		for z=1, #heights[x]-1 do
			local height = math.floor(heights[x][z] * height)
			max_h = math.max(max_h, height)
			for y=1, height do
				local b = math.random(32,255)
				local colors = {
					{b,b,b,255},
					{b,b,b,255},
					{b,b,b,255},
					{b,b,b,255},
					{b,b,b,255},
					{b,b,b,255}
				}
				local cube = object_cube_faces(x*s,y*s,z*s, s,s,s, colors)
				table.insert(cubes, cube)
			end
		end
	end
	
	local points = {}
	local colors = {}
	for i=1, #cubes do
		for j=1, #cubes[i].points do
			local point = cubes[i].points[j]
			local position = cubes[i].position
			point[1] = point[1] + position[1]
			point[2] = point[2] + position[2]
			point[3] = point[3] + position[3]
			table.insert(points, point)
		end
		for j=1, #cubes[i].colors do
			table.insert(colors, cubes[i].colors[j])
		end
	end
	
	local w = (#heights-1)*s
	local h = max_h
	local d = (#heights[1]-1)*s
	
	translate_points(points, -(w/2)-(s/2), -s, -(d/2)-(s/2), points)
	
	local cube = {
		type = "triangles",
		position = {x,y,z},
		dimensions = {w,h,d},
		colors = colors,
		points = points
	}
	
	return cubes, cube
end


local function cubes_from_function(callback, x,y,z, w,h,d, s)
	
	local t = {}
	local function callback_cache(cx,cy,cz)
		if (cx>0) and (cy>0) and (cz>0) and (cx<=w) and (cy<=h) and (cz<=d) then
			local index = cx..":"..cy..":"..cz
			if t[index] then
				return t[index]
			else
				local set = callback(cx,cy,cz)
				t[index] = set
				return set
			end
		else
			return false
		end
	end
	
	local hw = w/2
	local hh = h/2
	local hd = d/2
	local points = {}
	local colors = {}
	local function triangle(x1,y1,z1, x2,y2,z2, x3,y3,z3, ox,oy,oz, b)
		--[[
		local _x1 = (x1==1) and hw or -hw
		local _y1 = (y1==1) and hh or -hh
		local _z1 = (z1==1) and hd or -hd
		local _x2 = (x2==1) and hw or -hw
		local _y2 = (y2==1) and hh or -hh
		local _z2 = (z2==1) and hd or -hd
		local _x3 = (x3==1) and hw or -hw
		local _y3 = (y3==1) and hh or -hh
		local _z3 = (z3==1) and hd or -hd
		]]
		local _x1 = (x1==1) and s or -s
		local _y1 = (y1==1) and s or -s
		local _z1 = (z1==1) and s or -s
		local _x2 = (x2==1) and s or -s
		local _y2 = (y2==1) and s or -s
		local _z2 = (z2==1) and s or -s
		local _x3 = (x3==1) and s or -s
		local _y3 = (y3==1) and s or -s
		local _z3 = (z3==1) and s or -s
		table.insert(points, { _x1+ox, _y1+oy, _z1+oz })
		table.insert(points, { _x2+ox, _y2+oy, _z2+oz })
		table.insert(points, { _x3+ox, _y3+oy, _z3+oz })
		table.insert(colors, {b,b,b,255})
	end
	
	local function cube(left, right, top, bottom, front, back, sx,sy,sz)
		local b = math.random(32, 192)
		if left then
			triangle(0,0,0, 0,0,1, 0,1,0, sx+s*2,sy,sz, b)
			triangle(0,0,1, 0,1,1, 0,1,0, sx+s*2,sy,sz, b)
		end
		if right then
			triangle(1,0,1, 1,0,0, 1,1,0, sx,sy,sz, b)
			triangle(1,1,1, 1,0,1, 1,1,0, sx,sy,sz, b)
		end
		if top then
			triangle(1,1,0, 0,1,0, 0,1,1, sx,sy+s*2,sz, b)
			triangle(1,1,1, 1,1,0, 0,1,1, sx,sy+s*2,sz, b)
		end
		if bottom then
			triangle(0,0,1, 0,0,0, 1,0,0, sx,sy,sz, b)
			triangle(0,0,1, 1,0,0, 1,0,1, sx,sy,sz, b)
		end
		if front then
			triangle(1,0,0, 0,0,0, 0,1,0, sx,sy,sz+s*2, b)
			triangle(0,1,0, 1,1,0, 1,0,0, sx,sy,sz+s*2, b)
		end
		if back then
			triangle(0,0,1, 1,0,1, 0,1,1, sx,sy,sz, b)
			triangle(1,1,1, 0,1,1, 1,0,1, sx,sy,sz, b)
		end
	end
	
	

	for cz=0, d do
		for cy=0, h do
			for cx=0, w do
				-- add x axis faces
				local sx = cx*s*2
				local sy = cy*s*2
				local sz = cz*s*2
				
				
				local a = callback_cache(cx,cy,cz)
				local b = callback_cache(cx+1,cy,cz)
				local left = (not a) and b
				local right = a and (not b)
								
				-- add y axis faces
				a = callback_cache(cx,cy,cz)
				b = callback_cache(cx,cy+1,cz)
				local top = (not a) and b
				local bottom = a and (not b)
				
				-- add z axis faces
				a = callback_cache(cx,cy,cz)
				b = callback_cache(cx,cy,cz+1)
				local front = (not a) and b
				local back = a and (not b)
				
				cube(left, right, top, bottom, front, back, sx,sy,sz)
			end
		end
	end
	
	return {
		type = "triangles",
		points = points, 
		colors = colors,
		position = {x,y,z},
		dimensions = {w*s,h*s,d*s}
	}
end


-- filter a list of triangle positions by checking if they're visible based on their normals
local function backface_culling(points, colors, new_points, new_colors)
	local new_points = new_points or {}
	local new_colors = new_colors or {}
	
	local i = 1
	for j=1, #points, 3 do
		local point_a = points[j]
		local point_b = points[j+1]
		local point_c = points[j+2]
		local color = colors[(j-1)/3+1]
		local point_a_x, point_a_y, point_a_z = point_a[1], point_a[2], point_a[3]
		local point_b_x, point_b_y, point_b_z = point_b[1], point_b[2], point_b[3]
		local point_c_x, point_c_y, point_c_z = point_c[1], point_c[2], point_c[3]
		if not (point_a and point_b and point_c) then break end
		
		-- calculate normal of triangle
		local ux = point_b_x - point_a_x
		local uy = point_b_y - point_a_y
		local uz = point_b_z - point_a_z
		local vx = point_c_x - point_a_x
		local vy = point_c_y - point_a_y
		local vz = point_c_z - point_a_z
		local normal_x = (uy*vz) - (uz*vy)
		local normal_y = (uz*vx) - (ux*vz)
		local normal_z = (ux*vy) - (uy*vx)
		local normal_len = math.sqrt(normal_x^2 + normal_y^2 + normal_z^2)
		
		-- calculate centroid of triangle
		local center_x = (point_a_x + point_b_x + point_c_x) / 3
		local center_y = (point_a_y + point_b_y + point_c_y) / 3
		local center_z = (point_a_z + point_b_z + point_c_z) / 3
		local center_len = math.sqrt(center_x^2 + center_y^2 + center_z^2)
		
		local dotp = (normal_x/normal_len)*(center_x/center_len)+(normal_y/normal_len)*(center_y/center_len)+(normal_z/normal_len)*(center_z/center_len)
		if dotp <= 0 then
			new_points[i] = point_a
			new_points[i+1] = point_b
			new_points[i+2] = point_c
			new_colors[(i-1)/3+1] = color
			i = i + 3
		end
	end
	new_points[i] = nil
	return new_points, new_colors
end


-- resort points of a triangle
local function resort_triangles(points, colors, new_points, new_colors)
	local new_points = new_points or {}
	local new_colors = new_colors or {}

	local tmp_points = {}
	for i=1, #points, 3 do
		local point_a = points[i+0]
		local point_b = points[i+1]
		local point_c = points[i+2]
		if not (point_a and point_b and point_c) then break end
		
		local color = colors[(i-1)/3+1]
		local z = math.min(point_a[3], point_b[3], point_c[3])
		table.insert(tmp_points, {z, point_a, point_b, point_c, color, i})
	end
	table.sort(tmp_points, function(a,b)
		if a[1] == b[1] then
			return a[6] < b[6]
		else
			return a[1] < b[1]
		end
	end)
	local j = 1
	for i=1, #tmp_points do
		new_points[j+0] = tmp_points[i][2]
		new_points[j+1] = tmp_points[i][3]
		new_points[j+2] = tmp_points[i][4]
		new_colors[(j-1)/3+1] = tmp_points[i][5]
		j = j + 3
	end
	new_points[j] = nil
	-- new_colors[j] = nil
	
	return new_points, new_colors
end


-- depth-sort the objects list by the AABB boundaries
local function resort_objects(objects, camera)
	table.sort(objects, function(a,b)
	
		-- the points we test
		local points = {
			a.position,
			b.position
		}
		
		-- translate global coordinates to camera relative coordinates
		translate_points(points, camera.x, camera.y, camera.z, points)
		rotate_points_xz(points, camera.r_xz, points)
		
		-- sort by z value of translated points (draw from back to front)
		-- but also draw from bottom to top, if the z value is to close
		if points[1][3] == points[2][3] then
			return points[1][2] < points[2][2]
		else
			return points[1][3] < points[2][3]
		end
	end)
end


-- get 2d points from 3d points for each object
local function objects_to_screen(objects, cx,cy,cz,r, ar)
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
		
		if not object.disable_camera_translation then
			-- translate global coordinates to camera coordinates
			translate_points(points_cache, cx, cy, cz, points_cache)
			
			-- rotate points around origin by camera rotation
			rotate_points_xz(points_cache, r, points_cache)
		end
		
		-- project 3d points to 2d screen points with color information
		if object.type == "points" then
			project_3d_to_2d(points_cache, points_2d, ar)
		elseif object.type == "triangles" then
			-- remove surfaces not pointed towards the camera(Because afterwards some triangles have been removed, the indexes in colors have also changed
			local _, tmp_colors = backface_culling(points_cache, object.colors, points_cache, object._colors)
			
			-- resort points_cache by z(also changes color indexes)
			local _, sort_colors = resort_triangles(points_cache, tmp_colors, points_cache)
			object._colors = sort_colors
			
			-- triangles require the length of points to remain the same after clipping
			project_3d_to_2d(points_cache, points_2d, ar, true)
		elseif object.type == "lines" then
			project_3d_to_2d(points_cache, points_2d, ar)
		end
		
		object.points_cache = points_cache
		object.points_2d = points_2d
		
	end
		
	return _points_2d
end



-- get parameters
local w = tonumber(arg[1]) or 160
local h = tonumber(arg[2]) or 120
local scale = tonumber(arg[3]) or 3

-- create SDL window
local sdlfb = sdl2fb.new(w*scale, h*scale, "3D example")

-- create db for rendering
local db = ldb.new(w,h)
db:clear(0,0,0,0)

-- if we need to scale, also create a db with the scaled dimensions
local db_scaled
if scale > 1 then
	db_scaled = ldb.new(w*scale,h*scale)
end


-- handle all outstanding SDL events
local mouse_down = false
local mouse_motion = nil
local keys_down = {}
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
		elseif ev.type == "mousemotion" then
			if mouse_motion then
				mouse_motion(mouse_down, ev.xrel, ev.yrel)
			end
		elseif ev.type == "mousebuttondown" then
			sdlfb:set_mouse_grab(true)
			mouse_down = true
		elseif ev.type == "mousebuttonup" then
			sdlfb:set_mouse_grab(false)
			mouse_down = false
		end
		ev = sdlfb:pool_event()
	end
end


-- scale and draw to SDL
local function output_db(db)
	if scale > 1 then
		db_scaled:clear(0,0,0,0)
		db:draw_to_drawbuffer(db_scaled, 0,0,0,0,w,h,scale, false)
	end
	
	sdlfb:draw_from_drawbuffer(db_scaled or db,0,0)
end


local function add_AABB_boxes(objects)
	local boxes = {}
	for i=1, #objects do
		local obj = objects[i]
		if not obj then break end
		local pos = obj.position
		local dim = obj.dimensions
		if pos and dim then
			print("Adding bounding box to:", obj.type, pos[1], pos[2], pos[3], "-", dim[1], dim[2], dim[3])
			table.insert(boxes, object_cube_lines(pos[1], pos[2], pos[3], dim[1], dim[2], dim[3], 255,0,255,255))
		end
	end
	for i=1, #boxes do
		table.insert(objects, boxes[i])
	end
end



--[[ Add test scene ]]

-- source objects(this will contain the scene objects)
local objects = {}


-- add a ground plane with random heights
local perlin = require("perlin")
local heights = {}
for y=1, 20 do
	local cline = {}
	for x=1, 20 do
		local v = perlin.noise2d(x,y,0.1, 8, math.random(1,1^24))^2
		cline[x] = v
	end
	heights[y] = cline
end
local ground_obj = object_ground_from_heightmap(heights, 0, -10, 0, 5, 20)
--table.insert(objects, ground_obj)
--ground_obj.type = "lines"
--ground_obj.color = {255,0,255,255}
--ground_obj.rotation = 0


-- coordinate points
local a,b,c,d,e,f = object_coordinate_marker(50, 1)
table.insert(objects, a)
table.insert(objects, b)
table.insert(objects, c)
table.insert(objects, d)
table.insert(objects, e)
table.insert(objects, f)
table.insert(objects, {
	type = "points",
	color = {255,255,255,255},
	position = { 0,0,0 },
	points = { { 0,0,0 } }
})


--[[
table.insert(objects, object_cube_faces(0, 0, 0, 0.5,0.5,0.5, {
	{0,64,0,255},
	{0,255,0,255},
	{0,0,64,255},
	{0,0,255,255},
	{64,0,0,255},
	{255,0,0,255},
}))
]]


-- load the teapot obj
local teapot_obj = object_from_obj("../teapot.obj", 0, 0, 0)
teapot_obj.rotation = 0
--table.insert(objects, teapot_obj)


local teapots = {}
for z=0, 2 do
	for x=0, 2 do
		local teapot = object_from_obj("../teapot.obj", x*5+5, 0, z*5+5)
		teapot.rotation = math.random()*math.pi*2
		table.insert(teapots, teapot)
		--table.insert(objects, teapot)
	end
end


local _, megacube = cubes_from_heightmap(heights, 0,0,0, 1, 3)
--table.insert(objects, megacube)
--for k,v in ipairs(cubes_from_heightmap(heights, 0,0,0, 0.1, 5, 255,0,255)) do
	-- table.insert(objects, v)
--end

local cubes = cubes_from_function(function(x,y,z)
	if (x%5 == 0) or (y%5 == 0) or (z%5 == 0)then
		return true
	end
	return false
end, 0,0,0, 10,10,10, 1)
table.insert(objects, cubes)


add_AABB_boxes(objects)


-- move camera object
local function forward(camera, dt, speed)
	camera.z = camera.z + math.cos(camera.r_xz) * dt * speed
	camera.x = camera.x + math.sin(camera.r_xz) * dt * speed
end
local function backward(camera, dt, speed)
	camera.z = camera.z - math.cos(camera.r_xz) * dt * speed
	camera.x = camera.x - math.sin(camera.r_xz) * dt * speed
end
local function strafe_left(camera, dt, speed)
	camera.z = camera.z + math.cos((camera.r_xz-math.pi/2)) * dt * speed
	camera.x = camera.x + math.sin((camera.r_xz-math.pi/2)) * dt * speed
end
local function strafe_right(camera, dt, speed)
	camera.z = camera.z - math.cos((camera.r_xz-math.pi/2)) * dt * speed
	camera.x = camera.x - math.sin((camera.r_xz-math.pi/2)) * dt * speed
end
local function up(camera, dt, speed)
	camera.y = camera.y + dt*speed
end
local function down(camera, dt, speed)
	camera.y = camera.y - dt*speed
end
local function left(camera, dt, speed)
	camera.r_xz = camera.r_xz - dt*speed
end
local function right(camera, dt, speed)
	camera.r_xz = camera.r_xz + dt*speed
end


-- the current camera configuration
local camera = {
	x = 0,
	y = 0,
	z = 0,
	r_xz = 0
}


-- on mouse movement, if the mouse is down then rotate the camera
mouse_motion = function(mouse_down, xrel, yrel)
	if mouse_down then
		camera.r_xz = camera.r_xz + xrel/1000
	end
end


-- update the game state(handle keys for camera, rotate teapot)
local speed = 4
local function update(dt)
	if keys_down["Escape"] then
		os.exit(0)
	end
	
	-- increase speed if shift is down
	if keys_down["Left Shift"] then
		speed = 12
	else
		speed = 4
	end
	
	-- movement
	if keys_down["W"] then
		forward(camera, dt, speed)
	elseif keys_down["S"] then
		backward(camera, dt, speed)
	end
	if keys_down["A"] then
		strafe_left(camera, dt, speed)
	elseif keys_down["D"] then
		strafe_right(camera, dt, speed)
	end
	if keys_down["Q"] then
		up(camera, dt, speed)
	elseif keys_down["E"] then
		down(camera, dt, speed)
	end
	if keys_down["Y"] then
		left(camera, dt, 1)
	elseif keys_down["X"] then
		right(camera, dt, 1)
	end
	
	-- rotate teapot
	--teapot_obj.rotation = teapot_obj.rotation + dt
	-- teapot_obj.position[2] = math.sin(time.realtime())
	
	for i=1, #teapots do
		local teapot = teapots[i]
		teapot.rotation = teapot.rotation + dt
	end
	
end


local last = time.realtime()
local target = 1/30 -- target fps
local dts = {}
while true do
	local dt = time.realtime() - last
	last = time.realtime()
	
	-- start with a clean canvas
	db:clear(0,0,0,255)

	-- handle input events(mouse/keys)
	handle_sdl_events()
	
	-- update the camera, teapot
	update(dt)
	
	-- resort objects by z value
	resort_objects(objects, camera)
	
	-- calculate 2d screen positions for each object
	objects_to_screen(objects, camera.x, camera.y, camera.z, camera.r_xz, w/h)
	
	-- draw each object to the drawbuffer
	draw_objects(db, objects)
	
	-- draw to sdl
	output_db(db, true)
	
	if #dts > 30 then
		local min = math.huge
		local max = 0
		local avg = 0
		for i=1, #dts do
			avg = avg + dts[i]
			min = math.min(min, dts[i])
			max = math.max(max, dts[i])
		end
		avg = avg / #dts
		print(("FPS statistics:  max: %6.2ffps(%.5fdt)   avg: %6.2ffps(%.5fdt)   min: %6.2ffps(%.5fdt)"):format(1/min, min, 1/avg,avg, 1/max,max))
		dts = {}
	else
		table.insert(dts, dt)
	end
	
	if dt < target then
		local rem = (target - dt)*0.99
		time.sleep(rem)
	end
	
end




