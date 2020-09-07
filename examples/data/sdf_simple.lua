return function(w,h)

	local _abs,_min,_max,_sqrt,_sin,_cos,_pi = math.abs,math.min,math.max,math.sqrt,math.sin,math.cos,math.pi

	-- distance of x,y to a circle
	local function circle_sdf(px,py,radius)
		return _sqrt(px*px+py*py)-radius
	end

	-- distance of x,y to a box of width bw and height bh
	local function box_sdf(px,py,bw,bh)
		local dx = _abs(px)-bw
		local dy = _abs(py)-bh
		local d = _sqrt(_max(dx,0)^2+_max(dy,0)^2) + _min(_max(dx,dy),0.0)
		return d
	end

	-- map a distance value to grey value(0-1)
	local function map_v(px,py,d,t)
		local p = 1/h
		local border = p*2
		local v = 1
		if _abs(d)<border then
			-- we're inside the border region
			v = d/border
		elseif d<0 then
			-- inside the shape
			v = 0
		end
		return v
	end

	-- get the distance to the "scene"
	local function sdf(px,py, t)
		-- 0.5x0.5 rounded box centered at 0,0
		local d1 = (box_sdf(px,py, 0.4,0.4)-0.1)

		-- move circle along x-axis with time
		local circle_x = px + t*0.25*_pi
		-- repeat the circle on the x-axis
		local s = 1/1.5 -- how large the repetition domain is
		circle_x = (((circle_x*s+0.5)%1)-0.5)/s
		local d2 = circle_sdf(circle_x,py, 0.5)

		-- orbit around the circle
		local orbit_x = px+_sin(t)
		local orbit_y = py+_cos(t)
		orbit_x = orbit_x + t*0.25*_pi
		orbit_x = (((orbit_x*s+0.5)%1)-0.5)/s
		local d3 = circle_sdf(orbit_x,orbit_y,0.2)

		-- "subtract" d2 from d1, normal union for d3
		return _min(_max(d1,-d2),d3)
	end

	--[[
	local function clamp_rgb_range(r,g,b)
		r = _min(_max(_floor(r*255),0),255)
		g = _min(_max(_floor(g*255),0),255)
		b = _min(_max(_floor(b*255),0),255)
		return r,g,b
	end
	]]

	-- callback for every pixel on a drawbuffer of format rgb888
	local function get_pixel(x,y,per_frame)
		local t = per_frame
		local px,py = ((x/w)*2-1)*(w/h),(y/h)*2-1
		local d = sdf(px,py,t)
		local v = map_v(px,py,d,t)
		--return clamp_rgb_range(v,v,v)
		return v*255,v*255,v*255
	end

	return get_pixel
end
