return function(w,h,bpp)

	-- callback for every pixel on a drawbuffer of format rgb888
	local function per_pixel_callback(x,y,per_frame)
		return x,y,0
	end

	return per_pixel_callback
end
