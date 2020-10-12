return function(w,h,bpp)
	local hw,hh = w/2,h/2
	local minhd = math.min(hw,hh)


	local _sin,_cos,_min,_max,_floor,_pi = math.sin,math.cos,math.min,math.max,math.floor,math.pi
	local function map(d)
		local v = d/100
		if d==100 then
			return 255,255,255
		end
		local r = _sin(v*2*_pi)*0.5+0.5
		local g = _sin(v*3*_pi)*0.5+0.5
		local b = _sin(v*4*_pi)*0.5+0.5
		r = _min(_max(_floor(r*256),0),255)
		g = _min(_max(_floor(g*256),0),255)
		b = _min(_max(_floor(b*256),0),255)
		return r,g,b
	end

	local xoff,yoff,zoom = 0,0,1
	local function per_pixel_callback(x,y,per_frame)
		local xpct = (x/w)*zoom + xoff
		local ypct = (y/h)*zoom + yoff
		local px,py = xpct*2-1, ypct*2-1

		-- iterate the mandelbrot set
		local x0 = xpct*3.5-2.5
		local y0 = ypct*2-1
		local ix,iy = 0,0
		local iter,max_iter = 0, 100
		while ((ix*ix+iy*iy<=4) and (iter<max_iter)) do
			ix,iy = ix*ix-iy*iy+x0, 2*ix*iy+y0
			iter = iter + 1
		end

		-- get a color based on the iteration count
		local r,g,b = map(iter)
		return r,g,b
	end

	local function per_frame_callback(seq,state)
		if state.interactive then
			xoff = tonumber(state.mandel_x) or 0
			yoff = tonumber(state.mandel_y) or 0
			zoom = tonumber(state.mandel_zoom) or 1
		end
	end

	return per_pixel_callback,per_frame_callback
end
