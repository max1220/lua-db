return function(width,height)
	-- see https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
	local vector = require("lua-db.vector")
	local bit = require("bit")
	local vec3 = vector.vector3("float")

	local _sqrt,_min,_max,_rad,_tan,_abs,_huge = math.sqrt,math.min,math.max,math.rad,math.tan,math.abs,math.huge

	local function length2(x,y)
		return _sqrt(x*x+y*y)
	end

	local function length3(x,y,z)
		return _sqrt(x*x+y*y+z*z)
	end

	local function sphere_sdf(p,radius)
		return p:len()-radius
	end

	local function torus_sdf(p, tx,ty)
		--local qx = length2(p.x,p.z)-tx
		--return length2(qx,p.y)-ty
		local qx = _sqrt(p.x*p.x+p.y*p.y)
		return _sqrt(qx*qx+p.y*p.y)
	end

	local function plane_sdf(p, n, h)
		return p:dotp(n) + h
	end

	-- TODO: remove ugly temporary variables, but don't allocate in functions
	local capsule_sdf_tmp_a = vec3()
	local capsule_sdf_tmp_b = vec3()
	local function capsule_sdf(p, a, b,r)
		p:sub_v(a, capsule_sdf_tmp_a)
		b:sub_v(a, capsule_sdf_tmp_b)
		local h = _min(_max(capsule_sdf_tmp_a:dotp(capsule_sdf_tmp_b)/capsule_sdf_tmp_b:dotp(capsule_sdf_tmp_b), 0), 1)
		capsule_sdf_tmp_b:mul_n(h, capsule_sdf_tmp_a)
		capsule_sdf_tmp_a:sub_v(capsule_sdf_tmp_b, capsule_sdf_tmp_a)
		return capsule_sdf_tmp_a:len()-r
	end

	local hcapsule_sdf_tmp = vec3()
	local function hcapsule_sdf(p, h, r)
		p:copy_to(hcapsule_sdf_tmp)
		hcapsule_sdf_tmp.y = hcapsule_sdf_tmp.y - _min(_max(hcapsule_sdf_tmp.y, 0), h)
		return hcapsule_sdf_tmp:len()-r
	end

	local box_sdf_tmp = vec3()
	local function box_sdf(p,d)
		box_sdf_tmp:abs(box_sdf_tmp)
		box_sdf_tmp:sub_v(d, box_sdf_tmp)
		local v = _min(_max(box_sdf_tmp.x, box_sdf_tmp.y, box_sdf_tmp.z), 0.0)
		box_sdf_tmp:max_n(0, box_sdf_tmp)
		return box_sdf_tmp:len()-v
	end

	local torus_p = vec3(-2,0,0)
	local box_p = vec3(2,0,0)
	local box_d = vec3(0.5,0.5,0.5)
	local sphere_p = vec3(0,0,-2)
	local plane_p = vec3(0,0,0)
	local plane_n = vec3(0,1,0)
	local camera_pos = vec3(0,0,0)

	local sdf_element_pos = vec3()
	local function sdf(p)
		local d0 = -sphere_sdf(p, 10) -- sphere

		--p:add_v(torus_p, sdf_element_pos)
		--local d1 = torus_sdf(sdf_element_pos,0.5,0.5)

		--p:add_v(box_p, sdf_element_pos)
		--local d2 = box_sdf(sdf_element_pos,box_d)

		--p:add_v(sphere_p, sdf_element_pos)
		--local d3 = sphere_sdf(sdf_element_pos, 0.5)

		p:add_v(plane_p, sdf_element_pos)
		local d4 = plane_sdf(sdf_element_pos, plane_n, 1)

		--return _min(d0,d1,d2,d3,d4)
		return _min(d0,d4)
	end

	local ray_step = vec3()
	local function sphere_trace(ray_pos, ray_dir, max_iter)
		-- move the ray origin towards the ray direction until distance is roughly 0
		local iter = 0
		local epsilon = 0.001
		local dist = sdf(ray_pos)
		while (dist>epsilon) and (iter<max_iter) do
			-- dist is the minimal distance to the surface from the ray_pos position
			ray_dir:mul_n(dist, ray_step) -- ray_step = ray_dir*dist
			--ray_pos:add_v(ray_step, ray_pos) -- ray_pos = ray_pos + ray_step
			ray_pos:l_add_v(ray_step)
			dist = sdf(ray_pos) -- get scene distance to current ray position
			iter = iter + 1
		end
		return iter
	end

	local function map(ray_pos, ray_dir, dist,iter,max_iter)
		--return (iter/max_iter)*255,0,0
		--return (dist*100)%256,0,0
		local max_dist = 10
		--local r = (dist/max_dist)*255
		--local g = _min(_abs(ray_pos.x*256),_abs(ray_pos.y*256),_abs(ray_pos.z*256))
		--local g = bit.band(_abs(ray_pos.x*64), _abs(ray_pos.y*64), _abs(ray_pos.z*64))
		--local b = (iter/max_iter)*200
		--local g = _bor(_band(ray_pos.x, 3), _band(ray_pos.y, 3), _band(ray_pos.z, 3))*64
		--local g = ray_pos.x*ray_pos.y*ray_pos.z*10

		local r = (ray_pos.x*128)%256 -- 0.5* (1-(iter/max_iter))
		local g = (ray_pos.y*128)%256 -- 0.5* (1-(iter/max_iter))
		local b = (ray_pos.z*128)%256 -- 0.5* (1-(iter/max_iter))

		return r,g,b
		--[[
		if iter==max_iter then
			-- no hit
			return 255,0,255
		else
			-- hit
			--return 0,dist,0--_floor((iter/max_iter)*255)
			return 0,0,iter
		end
		]]
	end

	local camera_f = _tan(_rad(90/2))
	local max_iter = 100
	local function per_frame_callback(seq,state)
		if state.interactive then
			camera_pos.x = tonumber(state.raymarching_camera_x)
			camera_pos.y = tonumber(state.raymarching_camera_y)
			camera_pos.z = tonumber(state.raymarching_camera_z)
			camera_f = _tan(_rad(tonumber(state.raymarching_camera_fov)/2))
			max_iter = tonumber(state.raymarching_max_iter)
		end
	end


	local ray_dir = vec3()
	local ray_pos = vec3()
	local ray_delta = vec3()
	local function per_pixel_callback(x,y,per_frame)
		local px = (((x+0.5)/height)*2-1) * (width/height)
		local py = ((y+0.5)/height)*2-1

		camera_pos:copy_to(ray_pos)
		-- hard-coded simple forward-facing view
		ray_dir.x = px*camera_f
		ray_dir.y = -py*camera_f
		ray_dir.z = 1
		ray_dir:normalize(ray_dir)

		local iter = sphere_trace(ray_pos, ray_dir, max_iter)
		--camera_pos:sub_v(ray_pos, ray_delta)
		local dist = 0--ray_delta:len()
		return map(ray_pos, ray_dir, dist,iter,max_iter) -- get color for distance
	end

	return per_pixel_callback,per_frame_callback
end
