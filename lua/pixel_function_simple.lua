
-- simple Lua implementation of a pixel function. No optimizations besides making functions local(for PUC Lua)
local function pixel_function_simple(w,h, bytes_per_pixel, get_callbacks, ...)
	local time = require("time")
	local _concat = table.concat

	-- get the callback functions for rendering
	local per_pixel_cb, per_frame_cb = get_callbacks(w,h,bytes_per_pixel, ...)

	local line_buf = {} -- contains the line currently beeing worked on
	local frame_buf = {} -- contains the frame currently beeing worked on

	-- render a single line
	local function render_line(y, per_frame)
		for x=0, w-1 do
			per_pixel_cb(x,y,line_buf,x+1, per_frame)
		end
		return _concat(line_buf)
	end

	-- render a frame one line at a time(returns nil if no frame is ready yet, frame otherwise)
	local partial_y = 0
	local partial_per_frame
	local function render_partial()
		if not partial_per_frame then
			partial_per_frame = per_frame_cb()
		end
		frame_buf[partial_y+1] = render_line(partial_y, partial_per_frame)
		partial_y = partial_y + 1
		if partial_y == h then
			partial_per_frame = nil
			partial_y = 0
			return _concat(frame_buf)
		end
	end

	-- render untill a frame is completed or the timeout is reached
	local function render_timeout(timeout)
		local start = time.monotonic()
		while (time.monotonic()-start >= timeout) do
			local frame = render_partial()
			if frame then
				return frame
			end
		end
	end

	-- render a complete frame(blocking)
	local function render()
		local per_frame = per_frame_cb()
		for y=0, h-1 do
			frame_buf[y+1] = render_line(y, per_frame)
		end
		return _concat(frame_buf)
	end

	-- get the progress in the current frame(For render_partial and render_timeout)
	local function get_progress()
		return partial_y
	end

	return {
		type = "pixel_function_simple",
		render_timeout = render_timeout,
		render_partial = render_partial,
		get_progress = get_progress,
		render = render,
		render_line = render_line,
		frame_buf = frame_buf,
		line_buf = line_buf,
	}
end

return pixel_function_simple
