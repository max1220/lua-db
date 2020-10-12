--[[
This file contains various implementations of "pixel functions":
function executed for every pixel to determine the r,g,b value of that pixel.

The different implementations can be automatically selected using the pixel_function.auto function.
It provides a common interface for all implementations.

Because the common interface can't make certains assumptions about it's use it might be slower than
the "native" interfaces. For example, multithread_pixel_function_ffi_shared_buf supports a
zero-copy interface that needs to be supported by the programm using this libray,
and can't be used by this common interface.
The per_pixel_cb and per_frame_cb function supplied to the renderer also supports modifying the
buffer in a more non-linear way(e.g. zero parts of the screen efficiently). This is another
optimization the common interface can't use.

For usage information on the different implementations, see the comments below.

# Notes

 * per_pixel_cb modifies a buffer in all implementations(except the common interface, which uses a wrapper that does).
 * frame_data is always a string of length w*h*bytes_per_pixel,
   expect for multithread_pixel_function_ffi_shared_buf() with the no_string argument. (returns a ffi buffer)
 * the multithreaded implementations also support a sequence number in get_progress, get_frame, render, per_frame_cb
 * the multithreaded implementations only support a single worker_arg(single-threaded supports vararg)
 * the multithread_pixel_function_ffi is never selected by pixel_function.auto unless forced via config
 * as a general rule of thumb, you should install effil and luajit, then use the
   multithread_pixel_function_ffi_shared_buf function for performance.
 * Using the single-threaded implementations can help debugging and optimizing for luajit,
   as it allows using luajit build-in trace functions easily(e.g. use like luajit -jv -jp=lfs3 [lua file]).
]]



-- TODO: Use more generic functions/prototype(lessen code duplication)
-- TODO: send remaining work after stride as one request
-- TODO: benchmark setting pixels in callback vs callback return r,g,b and loop sets values
-- TODO: write micro-benchmark function for selecting the fastest function automatically at runtime


local pixel_function = {}



--[[ single-thread variants ]]

pixel_function.pixel_function_simple = require("lua-db.pixel_function_simple")
-- renderer = pixel_function_simple(w,h, bytes_per_pixel, get_callbacks, ...)
-- w,h,bytes_per_pixel define the pixel data format
--   frame_data = renderer.render_partial()
--   frame_data = renderer.render_timeout(timeout)
--   lines = renderer.get_progress()
--   frame_data = renderer.render()
-- per_pixel_cb, per_frame_cb = get_callbacks(w,h,bytes_per_pixel, ...)
-- per_frame = per_frame_cb()
-- per_pixel_cb(x,y, line_buf,i, per_frame)

pixel_function.pixel_function_ffi = require("lua-db.pixel_function_ffi")
-- renderer = pixel_function_ffi(w,h,bytes_per_pixel, get_callbacks, ...)
-- w,h,bytes_per_pixel define the pixel data format
--   frame_data = renderer.render_partial()
--   frame_data = renderer.render_timeout(timeout)
--   lines = renderer.get_progress()
--   frame_data = renderer.render()
-- per_pixel_cb, per_frame_cb = get_callbacks(w,h,bytes_per_pixel, ...)
-- per_frame = per_frame_cb()
-- per_pixel_cb(x,y, frame_buf,i, per_frame)



--[[ multi-threaded variants ]]

pixel_function.multithread_pixel_function_simple = require("lua-db.multithread_pixel_function_simple")
-- renderer = multithread_pixel_function_simple(w,h,bytes_per_pixel, threads, per_worker)
-- w,h,bytes_per_pixel define the pixel data format
--   renderer.start(worker_arg)
--   renderer.send_requests()
--   lines,seq = renderer.get_progress()
--   frame_data,seq = renderer.get_frame(timeout)
--   frame_data,seq = renderer.render()
-- per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel, worker_arg)
-- per_frame = per_frame_cb(seq)
-- per_pixel_cb(x,y, line_buf,i, per_frame)


pixel_function.multithread_pixel_function_ffi = require("lua-db.multithread_pixel_function_ffi")
-- renderer = multithread_pixel_function_ffi(w,h,bytes_per_pixel, threads,stride, per_worker)
-- w,h,bytes_per_pixel define the pixel data format
--   renderer.start(worker_arg)
--   renderer.send_requests()
--   lines,seq = renderer.get_progress()
--   frame_data,seq = renderer.get_frame(timeout)
--   frame_data,seq = renderer.render()
-- per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel, stride, thread_ffi, worker_arg)
-- per_frame = per_frame_cb(seq)
-- per_pixel_cb(x,y, lines_buf,i, per_frame)


pixel_function.multithread_pixel_function_ffi_shared_buf = require("lua-db.multithread_pixel_function_ffi_shared_buf")
-- renderer = multithread_pixel_function_ffi_shared_buf(w,h, bytes_per_pixel, threads,stride, per_worker, no_string)
-- w,h,bytes_per_pixel define the pixel data format
--   renderer.start(worker_arg)
--   renderer.send_requests()
--   lines,seq = renderer.get_progress()
--   frame_data,seq = renderer.get_frame(timeout)
--   frame_data,seq = renderer.render()
-- per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel, stride, thread_ffi, worker_arg)
-- per_frame = per_frame_cb(seq)
-- per_pixel_cb(x,y, shared_buf,i, per_frame)



-- select a pixel function based on the current Lua installation and configuration.
-- renderer = pixel_function.auto(w,h,bytes_per_pixel, per_px_cb, per_frame_cb, config)
--   renderer.start(worker_arg)
--   renderer.send_requests()
--   lines = renderer.get_progress()
--   frame_data = renderer.get_frame(timeout)
--   frame_data = renderer.render()
-- w,h,bytes_per_pixel define the pixel data format
-- r,g,b = per_px_cb(x,y,per_frame)
-- per_frame = per_frame_cb()
-- config = {
--   force_luajit=true/false/nil,
--   force_smp=true/false/nil,
--   threads=hardware_threads/number,
--   stride=24/number,
--   force_[implementation_name]=true/nil,
-- }
function pixel_function.auto(w,h,bytes_per_pixel, per_px_cb, per_frame_cb, config)
	local has_effil,effil = pcall(require,"effil")
	local do_smp = has_effil and (effil.hardware_threads() > 1)
	local is_luajit = type(jit) == "table"

	if config.force_luajit~=nil then is_luajit = config.force_luajit end
	if config.force_smp~=nil then do_smp = has_effil and config.force_smp end
	local threads = tonumber(config.threads) or (has_effil and (effil.hardware_threads()+1) or 1)
	local stride = tonumber(config.stride) or 24

	-- TODO: Implement the per_px wrapper for more bpp's
	assert(bytes_per_pixel==3, "Currently only 24bpp RGB supported!")

	local function wrap_per_px_ffi(x,y,buf,i,per_frame)
		local r,g,b = per_px_cb(x,y,per_frame)
		buf[i+0] = r
		buf[i+1] = g
		buf[i+2] = b
	end

	local _min,_max,_floor,_char = math.min,math.max,math.floor,string.char
	local function wrap_per_px_simple(x,y,buf,i,per_frame)
		local r,g,b = per_px_cb(x,y,per_frame)
		r = _max(_min(_floor(r),255),0)
		g = _max(_min(_floor(g),255),0)
		b = _max(_min(_floor(b),255),0)
		buf[i] = _char(r,g,b)
	end

	local function per_worker_ffi()
		return wrap_per_px_ffi, per_frame_cb
	end

	local function per_worker_simple()
		return wrap_per_px_simple, per_frame_cb
	end

	local function get_callbacks_ffi()
		return wrap_per_px_ffi, per_frame_cb
	end

	local function get_callbacks_simple()
		return wrap_per_px_simple, per_frame_cb
	end

	-- TODO: utilize wrapped functions, call .start() if needed
	local renderer
	if (do_smp and is_luajit) or config.force_multithread_pixel_function_ffi_shared_buf then
		-- threads, luajit
		renderer = pixel_function.multithread_pixel_function_ffi_shared_buf(w,h, bytes_per_pixel, threads,stride, per_worker_ffi)
	elseif (do_smp and (not is_luajit)) or config.force_multithread_pixel_function_simple then
		-- threads, no luajit
		renderer = pixel_function.multithread_pixel_function_simple(w,h, bytes_per_pixel, threads, per_worker_simple)
	elseif config.force_multithread_pixel_function_ffi then
		-- threads, luajit, no shared memory
		renderer = pixel_function.multithread_pixel_function_ffi(w,h, bytes_per_pixel, threads,stride, per_worker_ffi)
	elseif ((not do_smp) and is_luajit) or config.force_pixel_function_ffi then
		-- no threads, luajit
		renderer = pixel_function.pixel_function_ffi(w,h, bytes_per_pixel, get_callbacks_ffi)
	else
		-- no threads, no luajit
		renderer = pixel_function.pixel_function_simple(w,h, bytes_per_pixel, get_callbacks_simple)
	end

	-- some implementations don't require initialization(at least for now), so...
	if not renderer.start then
		-- ... use dummy start function.
		function renderer.start() end
	end

	-- some implementations don't require sending work requests(at least for now), so...
	if not renderer.send_requests then
		-- ... use dummy send_requests() function.
		function renderer.send_requests() end
	end

	-- emulate the get_frame behaviour(wait for a complete work request) by using....
	if not renderer.get_frame then
		function renderer.get_frame(timeout)
			-- .. the render_timeout function (does not need send_requests).
			return renderer.render_timeout(timeout)
		end
	end

	-- renderer now should at least have the following functions available:
	--   renderer.start(worker_arg)
	--   renderer.send_requests()
	--   lines = renderer.get_progress()
	--   frame_data = renderer.get_frame(timeout)
	--   frame_data = renderer.render()

	-- return common renderer interface
	return renderer
end

return pixel_function
