#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")
local sdl2fb = require("sdl2fb")


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


-- camera is always at origin(0,0,0)
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
	local function set_line(db, x1,y1,x2,y2,r,g,b,a,dist)
		db:set_line(x1,y1,x2,y2,r,g,b,a)
	end

	-- draws a triangle on the screen
	local function set_triangle(db, x1,y1,x2,y2,x3,y3,r,g,b,a)
		db:fill_triangle(x1,y1,x2,y2,x3,y3,r,g,b,a)
	end

	local _w = db:width()
	local _h = db:height()
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
			local hw = _w/2
			local hh = _h/2
			local colors = object._colors or object.colors
			local points_2d = object.points_2d
			for i=1, #object.points_2d, 3 do
				local color = colors[(i-1)/3+1] or {255,0,255,255}
				local point_a = points_2d[i]
				local point_b = points_2d[i+1]
				local point_c = points_2d[i+2]
				if not (point_a and point_b and point_c) then break end
				-- TODO: better clipping
				
				local x1,y1,dist1 = point_a[1], point_a[2], point_a[3]
				local x2,y2,dist2 = point_b[1], point_b[2], point_b[3]
				local x3,y3,dist3 = point_c[1], point_c[2], point_c[3]

				set_triangle(db, x1*hw+hw, y1*hh+hh, x2*hw+hw, y2*hh+hh, x3*hw+hw, y3*hh+hh, color[1], color[2], color[3], color[4])
				
				--set_line(db, x1*hw+hw,y1*hh+hh, x2*hw+hw,y2*hh+hh, 255,0,255,255)
				--set_line(db, x2*hw+hw,y2*hh+hh, x3*hw+hw,y3*hh+hh, 255,0,255,255)
				--set_line(db, x1*hw+hw,y1*hh+hh, x3*hw+hw,y3*hh+hh, 255,0,255,255)
				
			end
		elseif object.type == "lines" then
			for i=1, #object.points_2d, 2 do
				local color = object.colors[(i-1)/2+1] or {255,0,255,255}
				local point_a = object.points_2d[i]
				local point_b = object.points_2d[i+1]
				if not (point_a and point_b) then break end
				-- TODO: better clipping
				
				local x1,y1,dist1 = point_a[1], point_a[2], point_a[3]
				local x2,y2,dist2 = point_b[1], point_b[2], point_b[3]

				set_line(db, x1,y1, x2,y2)
				
			end
		else
			print("unknown obj", object.type)
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
local function object_cube_lines(x,y,z,w,h,d,r,g,b)
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
	
	local cube_obj = {
		type = "lines",
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
		{w,0,0},
		{w,0,d},
		{0,0,d},
	}
	local color = {r,g,b,a}
	local triangle = object_triangle(x,y,z, points, {color, color})
	return triangle
end


-- load the wavefront .obj file into an object at the specified coordinates
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
	
	local object = {
		type = "triangles",
		colors = colors,
		points = points,
		position = { x,y,z }
	}
	
	return object
	
end


-- take a heightmap, and generates a triangles object for that heightmap.
local function object_ground_from_heightmap(heights, x,y,z, step, height, r,g,b,a)

	local function get_height(x,y)
		return (heights[y] or {})[x]
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
			table.insert(points, { px2, heights[2], pz1 })
			table.insert(points, { px1, heights[1], pz1 })
			table.insert(points, { px1, heights[3], pz2 })
			local b = math.random(128,192)
			table.insert(colors, {b,b,b,255})
			table.insert(points, { px2, heights[2], pz1 })
			table.insert(points, { px1, heights[3], pz2 })
			table.insert(points, { px2, heights[4], pz2 })
			b = math.random(192,255)
			table.insert(colors, {b,b,b,255})
		end
	end
	
	local object = {
		type = "triangles",
		position = {x,y,z},
		points = points,
		colors = colors
	}
	
	return object
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
		table.insert(tmp_points, {z, point_a, point_b, point_c, color})
	end
	table.sort(tmp_points, function(a,b)
		return a[1] < b[1]
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
		
		-- translate global coordinates to camera coordinates
		translate_points(points_cache, cx, cy, cz, points_cache)
		
		-- rotate points around origin by camera rotation
		rotate_points_xz(points_cache, r, points_cache)
		
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





--[[ Add test scene ]]

-- source objects(this will contain the scene objects)
local objects = {}

-- cube centered at 0,0,0 in pink
--table.insert(objects, object_cube_points(0,0,0,1,1,1,255,0,255))



-- coordinate points
local a,b,c,d,e,f = object_coordinate_marker(50, 1)
table.insert(objects, a)
table.insert(objects, b)
table.insert(objects, c)
table.insert(objects, d)
table.insert(objects, e)
table.insert(objects, f)



table.insert(objects, object_cube_lines(0,0,0,1,1,1,255,0,255))



-- test triangle and plane
--table.insert(objects, object_triangle(0,0,0, {{0,0,0}, {1,0,0}, {0,0,1}}, {{255,0,255,255}}))
--table.insert(objects, object_plane_xz(0, 0, 0, 10, 10, 64,64,64,255))


-- load the teapot obj
local teapot_obj = object_from_obj("../teapot.obj", -7, 0, -10)
teapot_obj.rotation = 0
table.insert(objects, teapot_obj)


-- add a ground plane with random heights
local perlin = require("perlin")
local heights = {}
for y=1, 50 do
	local cline = {}
	for x=1, 50 do
		local v = perlin.noise2d(x,y,0.05, 8, math.random(1,1^24))
		cline[x] = v
	end
	heights[y] = cline
end
local ground_obj = object_ground_from_heightmap(heights, 0, 0, 0, 3, 10)
-- ground_obj.type = "points"
-- ground_obj.color = {255,0,255,255}
ground_obj.rotation = 0
--table.insert(objects, ground_obj)


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
		left(camera, dt, speed)
	elseif keys_down["X"] then
		right(camera, dt, speed)
	end
	
	-- rotate teapot
	teapot_obj.rotation = teapot_obj.rotation + dt
end


local last = time.realtime()
while true do
	local dt = time.realtime() - last
	last = time.realtime()
	
	-- start with a clean canvas
	db:clear(0,0,0,0)
		
	-- handle input events(mouse/keys)
	handle_sdl_events()
	
	-- update the camera, teapot
	update(dt)
	
	-- calculate 2d screen positions for each object
	points_2d = objects_to_screen(objects, camera.x, camera.y, camera.z, camera.r_xz, w/h)
	
	-- draw each object to the drawbuffer
	draw_objects(db, objects)
	
	-- draw to sdl
	output_db(db, true)
	
	-- io.write(("FPS: %8.2f    \r"):format(1/dt))
end




