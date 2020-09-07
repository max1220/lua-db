return function(w,h)

	-- callback for every pixel on a drawbuffer of format rgb888
	local function get_pixel(x,y,per_frame)
		return x,y,0
	end

	return get_pixel
end
