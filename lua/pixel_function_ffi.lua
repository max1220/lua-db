local time = require("time")

-- FFI implementation of a pixel function. Hotloop optimized for LuaJIT
-- TODO: Implement no_string argument like in ffi_shared_buf
local function pixel_function_ffi(w,h, bytes_per_pixel, get_callbacks, ...)
	local ffi = require("ffi")
	local cdef = [[
		void *malloc(size_t size);
		void *calloc(size_t nmemb, size_t size);
		void free(void *ptr);
	]]
	ffi.cdef(cdef)

	local function new_buf(type, count)
		return ffi.cast(type, ffi.gc(ffi.C.calloc(count, ffi.sizeof(type)), ffi.C.free))
	end

	-- get the callback functions for rendering
	local per_pixel_cb, per_frame_cb = get_callbacks(w,h,bytes_per_pixel, ...)

	local frame_buf_len = w*h*bytes_per_pixel
	local frame_buf = new_buf("uint8_t", frame_buf_len) -- contains the frame currently beeing worked on

	-- render a single line
	local function render_line(y, per_frame)
		for x=0, w-1 do
			local i = y*w*bytes_per_pixel+x*bytes_per_pixel
			per_pixel_cb(x,y,frame_buf,i, per_frame)
		end
	end

	-- render a frame one line at a time(returns nil if no frame is ready yet, frame otherwise)
	local partial_y = 0
	local partial_per_frame
	local function render_partial()
		if not partial_per_frame then
			partial_per_frame = per_frame_cb()
		end
		render_line(partial_y, partial_per_frame)
		partial_y = partial_y + 1
		if partial_y == h then
			partial_per_frame = nil
			partial_y = 0
			return ffi.string(frame_buf, frame_buf_len) -- TODO: no_string
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
		return ffi.string(frame_buf, frame_buf_len) -- TODO: no_string
	end

	-- get the progress in the current frame(For render_partial and render_timeout)
	local function get_progress()
		return partial_y
	end

	return {
		type = "pixel_function_ffi",
		render_timeout = render_timeout,
		render_partial = render_partial,
		get_progress = get_progress,
		render = render,
		render_line = render_line,
		frame_buf = frame_buf,
	}
end

return pixel_function_ffi
