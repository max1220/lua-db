return function(w,h)

	-- distance of x,y to a circle
	local function circle_sdf(px,py,radius)
		return math.sqrt(px*px+py*py)-radius
	end

	-- distance of x,y to a box of width bw and height bh
	local function box_sdf(px,py,bw,bh)
		local dx = math.abs(px)-bw
		local dy = math.abs(py)-bh
		local d = math.sqrt(math.max(dx,0)^2+math.max(dy,0)^2) + math.min(math.max(dx,dy),0.0)
		return d
	end

	-- map a distance value to a color
	local function map(px,py,d,t)
		local p = 1/h
		local border = p*2
		local v = 1
		if math.abs(d)<border then
			-- we're inside the border region
			v = d/border
		elseif d<0 then
			-- inside the shape
			v = 0
		end
		return v,v,v
	end

	-- get the distance to the "scene"
	local function sdf(px,py, t)
		-- 0.5x0.5 rounded box centered at 0,0
		local d1 = (box_sdf(px,py, 0.4,0.4)-0.1)

		-- move circle along x-axis with time
		local circle_x = px + t*0.25*math.pi
		-- repeat the circle on the x-axis
		local s = 1.5 -- how large the repetition domain is
		circle_x = (((circle_x*(1/s)+0.5)%1)-0.5)/(1/s)
		local d2 = circle_sdf(circle_x,py, 0.5)

		-- orbit around the circle
		local orbit_x = px+math.sin(t)
		local orbit_y = py+math.cos(t)
		orbit_x = orbit_x + t*0.25*math.pi
		orbit_x = (((orbit_x*(1/s)+0.5)%1)-0.5)/(1/s)
		local d3 = circle_sdf(orbit_x,orbit_y,0.2)

		-- "subtract" d2 from d1, normal union for d3
		return math.min(math.max(d1,-d2),d3)
	end

	-- convert a r,g,b value in the range 0-1 to a pixel value in the rgb888 format
	local function to_pixel_rgb888(r,g,b)
		r = math.min(math.max(math.floor(r*255),0),255)
		g = math.min(math.max(math.floor(g*255),0),255)
		b = math.min(math.max(math.floor(b*255),0),255)
		return string.char(r,g,b)
	end

	-- callback for every pixel on a drawbuffer of format rgb888
	local function callback_rgb888(x,y,_,per_frame)
		local t = per_frame
		local px,py = ((x/w)*2-1)*(w/h),(y/h)*2-1
		local d = sdf(px,py,t)
		local r,g,b = map(px,py,d,t)
		return to_pixel_rgb888(r,g,b)
	end

	return callback_rgb888
end
