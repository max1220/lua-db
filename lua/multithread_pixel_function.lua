local multithread_pixel_function = {}
--[[
This file implements multiple ways to execute a function for every pixel on
a drawbuffer using multiple threads.

# Implementation

Each thread has a sepereate Lua state shares data with the calling thread via channels.
The effil Lua threading library is used for this.
For best performance, use with luaJIT.

There are 3 implementations:

	* multithread_pixel_function
	* multithread_pixel_function_ffi
	* multithread_pixel_function_ffi_shared_buf

multithread_pixel_function_ffi and multithread_pixel_function_ffi_shared_buf
are the same from a usage standpoint and only differ in implementation.

## multithread_pixel_function_simple

`multithread_pixel_function_simple(w,h, bytes_per_pixel, threads, per_worker)` is the simplest implementation, intended for Lua
implementations that don't support JIT compilation or the FFI library(e.g. PUC Lua).

```
per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel,worker_arg) -- this function returns 2 functions:
per_frame_cb(seq) -- called once per frame for per-frame initialization
per_pixel_cb(x,y,buf,i,per_frame) -- called to put at buf[i] a 3-byte string(r,g,b) representing this pixel
```

send_requests() pushes a work request(y,seq) to the req_channel for every line.
Each worker pops a request of the req_channel, calls the per_pixel_cb for every pixel,
and pushes a result(y,buf_str,seq) to the ret_channel.
The collector thread collects a complete frame, and pushes a complete frame to the frame_channel,
and status updates on the status_channel.

get_progress() gets the last known progress value(the last-pushed value on status_channel).

get_frame(timeout) waits for a single frame.
If timeout is nil, wait indefinitly(blocking).
If timeout is 0, return immediatly(non-blocking).
Otherwise, wait at most for timeout seconds(blocking).
When a frame was returned(no timeout), the request_ready flag is reset,
and a new request can be made using send_requests().


per_worker is used to initialize every rendering thread.
This function must return 2 functions, per_pixel_cb, per_frame_cb.
per_pixel_cb is called for every pixel on every frame and returns the new pixel data.
per_frame is called every frame. It's return value is passed to every per_pixel_cb call.

    per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel,worker_arg)
	per_frame = per_frame_cb() -- called every frame
    px_str = per_pixel_cb(x,y,per_frame) -- #px_str must be bytes_per_pixel



# multithread_pixel_function_ffi(w,h, bytes_per_pixel, threads, stride, per_worker)


TODO: Use more generic functions, to lessen code duplication
TODO: separate to different files?
TODO: send remaining work after stride as one request
TODO: single-threaded fallback implementations
TODO: benchmark setting pixels in callback vs callback return r,g,b and loop sets values
]]



local function pack(...)
	return {...}
end

-- catch errors in thread functions using xpcall
-- TODO: Generic form of this? Without hard-coded output to stderr
local function wrap_cb_xpcall(fn)
	return function(...)
		local ret = pack(xpcall(fn, function(err)
			io.stderr:write("\n\027[31m", ("-"):rep(80), "\n")
			io.stderr:write("xpcall error: ", tostring(err), "\n")
			io.stderr:write(debug.traceback(), "\n")
			io.stderr:write(("-"):rep(80), "\027[0m\n")
			io.stderr:flush()
		end, ...))
		local ok = table.remove(ret, 1)
		if ok then
			return unpack(ret)
		end
	end
end

-- catch errors in thread functions using pcall
local function wrap_cb_pcall(fn)
	return function(...)
		local ret = pack(pcall(fn, ...))
		local ok = table.remove(ret, 1)
		if not ok then
			io.stderr:write("\n\027[31m", ("-"):rep(80), "\n")
			io.stderr:write("pcall error: ", tostring(ret), "\n")
			io.stderr:write(("-"):rep(80), "\027[0m\n")
			io.stderr:flush()
			return
		end
		return unpack(ret)
	end
end

-- catch errors in thread functions using xpcall or pcall as fallback
local function wrap_cb(fn)
	if xpcall then
		return wrap_cb_xpcall(fn)
	else
		return wrap_cb_pcall(fn)
	end
end






-- no ffi, no stride(simple implementation)
-- per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel,worker_arg)
-- px_str = per_pixel_cb(x,y,buf,i,per_frame) -- put at buf[i] a 3-byte string(r,g,b)
function multithread_pixel_function.multithread_pixel_function_simple(w,h, bytes_per_pixel, threads, per_worker)
	local effil = require("effil")

	w,h = assert(tonumber(w)), assert(tonumber(h))
	bytes_per_pixel = assert(tonumber(bytes_per_pixel))
	threads = tonumber(threads) or effil.hardware_threads()+1
	assert(type(per_worker)=="function")

	-- create channels for inter-thread communication
	local req_channel = effil.channel()
	local ret_channel = effil.channel()
	local frame_channel = effil.channel()
	local progress_channel = effil.channel()

	-- worker thread reads from the req_channel, calls the callback function func,
	-- and pushes the result to the ret_channel
	local function worker(worker_arg)
		local per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel,worker_arg)
		local buf = {}

		local last_seq,per_frame
		while true do
			-- wait for an y position and a line of pixel data,
			-- write an y position and new line of pixel data

			-- if seq has changed, get the new per_frame data from per_frame_cb
			local y,seq = req_channel:pop()
			if seq ~= last_seq then
				per_frame = per_frame_cb(seq)
				last_seq = seq
			end

			-- call pixel callback
			for x=0, w-1 do
				per_pixel_cb(x,y,buf,x+1,per_frame)
			end

			-- push result
			ret_channel:push(y,table.concat(buf),seq)
		end
	end

	-- collection thread reads from the ret_channel and assembles complete frames
	local function collector()
		local frame = {}
		while true do
			-- collect the correct ammount of lines,
			-- then return the completed frame as pixel data
			local lines,last_seq = 0
			while lines<h do
				local y,line,seq = ret_channel:pop()
				frame[y+1] = line
				last_seq = seq
				lines = lines + 1
				progress_channel:push(lines,seq)
			end
			frame_channel:push(table.concat(frame),last_seq)
		end
	end

	-- send a work request for every line
	local seq = 0
	local request_ready = true
	local function send_requests()
		if request_ready then
			for y=0, h-1 do
				req_channel:push(y,seq)
			end
			seq = seq + 1
			request_ready = false
		end
	end

	-- get the last rendering progress
	local last_progress,last_seq
	local function get_progress()
		while progress_channel:size()>0 do -- if there is a new progress update
			last_progress,last_seq = progress_channel:pop() -- update last_progress(this should never block)
		end
		return last_progress,last_seq
	end

	-- get a single frame_data from the stack(timeout=nil is wait, timeout=0 is nonblocking)
	local function get_frame(timeout)
		local frame_data,frame_seq = frame_channel:pop(timeout)
		if frame_data then
			request_ready = true
		end
		return frame_data,frame_seq
	end

	-- render a single frame, blocking
	local function render()
		-- push the data to be proccessed into a work queue into the data_channel
		send_requests()

		-- pop the returned completed frame from frame_channel
		return get_frame()
	end

	local collector_t
	local worker_ts = {}
	local running = false
	local function start(worker_arg)
		if running then
			return
		end
		running = true

		-- start a worker thread for every hardware thread + 1
		for _=1, threads do
			local worker_t = effil.thread(wrap_cb(worker))(worker_arg)
			worker_ts[#worker_ts+1] = worker_t
		end

		-- start a single collector thread
		collector_t = effil.thread(wrap_cb(collector))()
	end

	return {
		start = start,
		send_requests = send_requests,
		get_progress = get_progress,
		get_frame = get_frame,
		render = render,
		collector_t = collector_t,
		worker_ts = worker_ts,
		req_channel = req_channel,
		ret_channel = ret_channel,
		frame_channel = frame_channel,
		progress_channel = progress_channel
	}
end


-- ffi and stride(optimized hotloop for luajit)
-- per_pixel_cb,per_frame_cb,buf,len = per_worker(w,h,bytes_per_pixel,stride,ffi,worker_arg)
-- buf is a ffi buffer of len bytes
-- per_pixel_cb(x,y,o,per_frame) modifies this buffer at the global position x,y+o(buffer local position x,o)
function multithread_pixel_function.multithread_pixel_function_ffi(w,h, bytes_per_pixel, threads, stride, per_worker)
	local effil = require("effil")

	-- check arguments/use default values
	w,h = assert(tonumber(w)),assert(tonumber(h))
	bytes_per_pixel = assert(tonumber(bytes_per_pixel))
	stride = tonumber(stride) or 32
	threads = tonumber(threads) or effil.hardware_threads()+1
	assert(type(per_worker)=="function")

	-- create channels for inter-thread communication
	local req_channel = effil.channel() -- push a y value and a line count on here to request work
	local ret_channel = effil.channel() -- after work request, pop y value+line count+pixel data(in collector)
	local frame_channel = effil.channel() -- after all work request, pop a complete frame from here
	local progress_channel = effil.channel() -- channel for progress reports from collector thread

	-- worker thread function. Gets the callbacks returned from per_worker and runs work requests.
	local function worker(worker_arg)
		local thread_ffi = require("ffi")

		local per_pixel_cb,per_frame_cb = per_worker(w,h,bytes_per_pixel,stride,thread_ffi,worker_arg)
		local len = w*bytes_per_pixel*stride
		local buf = thread_ffi.new("uint8_t[?]", len)

		-- thread main loop
		local last_seq, per_frame
		while true do
			-- wait for work request
			local y,line_count,seq = req_channel:pop()

			-- if seq has changed, get the new per_frame data from per_frame_cb
			if seq ~= last_seq then
				per_frame = per_frame_cb(seq)
				last_seq = seq
			end

			-- perform line_count ammount of work and call per_pixel_cb for every pixel in work segment
			for o=0, line_count-1 do
				for x=0, w-1 do
					-- call per_pixel_cb for every pixel in every line
					-- TODO: optimize this into a single loop? e.g. for y do for x do buf[i]=px; i++; end end
					local i = o*w*bytes_per_pixel+x*bytes_per_pixel
					per_pixel_cb(x,y+o,buf,i,per_frame)
				end
			end

			-- push generated lines as string to collector thread
			ret_channel:push(y,line_count,thread_ffi.string(thread_ffi.cast("char*",buf), len), seq)
		end
	end

	-- collection thread reads from the ret_channel and assembles complete frames
	local function collector()
		local thread_ffi = require("ffi")
		--print("collector thread", effil.thread_id())
		local line_len = w*bytes_per_pixel
		local len = h*line_len
		local frame_buf = thread_ffi.new("uint8_t[?]", len)
		while true do
			-- collect the correct ammount of lines,
			-- then return the completed frame as pixel data
			local lines,last_seq = 0,0
			while lines<h do
				local y,line_count,line_buf,seq = ret_channel:pop()
				local index = y*line_len
				local cp_len = line_count*line_len
				if not (index+cp_len > len) then
					thread_ffi.copy(frame_buf+index, line_buf, cp_len)
				end
				lines = lines + line_count
				last_seq = seq
				progress_channel:push(lines,seq)
			end
			frame_channel:push(thread_ffi.string(frame_buf, len),last_seq)
		end
	end

	-- send requests to req_channel in groups of stride(increase seq for every call)
	local seq = 0
	local request_ready = true
	local function send_requests()
		if request_ready then
			local last_y = 0
			for y=0, (h/stride)-1 do
				req_channel:push(y*stride, stride, seq)
				last_y = y*stride+stride-1
			end
			for y=last_y+1, h-1 do
				req_channel:push(y, 1, seq)
			end
			seq = seq + 1
			request_ready = false
		end
	end

	-- get the last rendering progress
	local last_progress,last_seq
	local function get_progress()
		while progress_channel:size()>0 do -- if there is a new progress update
			last_progress,last_seq = progress_channel:pop() -- update last_progress(this should never block)
		end
		return last_progress,last_seq
	end

	-- get a single frame_data from the stack(timeout=nil is wait, timeout=0 is nonblocking)
	local function get_frame(timeout)
		local frame_data,frame_seq = frame_channel:pop(timeout)
		if frame_data then
			request_ready = true
		end
		return frame_data,frame_seq
	end

	-- request and wait for a single frame(returns frame)
	local function render()
		-- push the lines to the req_channel
		send_requests()

		-- pop the returned completed frame from frame_channel
		return get_frame() -- blocking
	end


	local running = false
	local collector_t
	local worker_ts = {}
	local function start(worker_arg)
		if running then
			return
		end
		running = true

		-- start a worker thread for every hardware thread + 1
		for _=1, threads do
			local th = effil.thread(wrap_cb(worker))(worker_arg)
			table.insert(worker_ts, th)
		end

		-- start a single collector thread
		collector_t = effil.thread(wrap_cb(collector))()
	end

	return {
		start = start,
		send_requests = send_requests,
		get_progress = get_progress,
		get_frame = get_frame,
		render = render,
		collector_t = collector_t,
		worker_ts = worker_ts,
		req_channel = req_channel,
		ret_channel = ret_channel,
		frame_channel = frame_channel,
		progress_channel = progress_channel
	}
end


-- ffi and stride, using shared memory(optimized hotloop for luajit, no memory copy)
-- usage is the same as multithread_pixel_function_ffi, except the new parameter no_string.
-- if no_string is truethy the result is not stringified, but returned as the ffi buffer and it's length.
function multithread_pixel_function.multithread_pixel_function_ffi_shared_buf(w,h, bytes_per_pixel, threads, stride, per_worker, no_string)
	local effil = require("effil")

	-- check arguments/use default values
	w,h = assert(tonumber(w)),assert(tonumber(h))
	bytes_per_pixel = assert(tonumber(bytes_per_pixel))
	stride = tonumber(stride) or 32
	threads = tonumber(threads) or effil.hardware_threads()+1
	assert(type(per_worker)=="function")

	-- create channels for inter-thread communication
	local req_channel = effil.channel() -- push a y value and a line count on here to request work
	local ret_channel = effil.channel() -- after work request, pop line count(in collector)
	local frame_channel = effil.channel() -- after all work request completed true is pushed(buffer is ready for reading)
	local progress_channel = effil.channel() -- channel for progress reports from collector thread

	local cdef = [[
	void *malloc(size_t size);
	void *calloc(size_t nmemb, size_t size);
	void free(void *ptr);
	typedef struct { uintptr_t ptr; } tmp_t;
	]]

	local function pointer_to_str(_ffi, ptr)
		local tmp = _ffi.new("tmp_t")
		tmp.ptr = _ffi.cast("uintptr_t", ptr)
		return _ffi.string(_ffi.cast("tmp_t*", tmp), _ffi.sizeof(tmp))
	end

	local function str_to_pointer(_ffi, str, type)
		local tmp = _ffi.new("tmp_t")
		_ffi.copy(_ffi.cast("tmp_t*", tmp), str, _ffi.sizeof(tmp))
		return _ffi.cast(type or "void*", tmp.ptr)
	end

	local ffi = require("ffi")
	ffi.cdef(cdef)

	local function calloc_buf(len, type)
		local ptr = ffi.C.calloc(len, ffi.sizeof(type))
		local type_ptr = ffi.cast(type.."*", ptr)
		local buf = ffi.gc(type_ptr, ffi.C.free)
		if buf == ffi.NULL then error("calloc fauiled") end
		return buf
	end

	local buf_len = w*h*bytes_per_pixel
	local buf_ptr = calloc_buf(buf_len, "uint8_t")
	local buf_ptr_str = pointer_to_str(ffi, buf_ptr)

	-- return the buffer content as a lua string
	local function buffer_to_str()
		return ffi.string(buf_ptr, buf_len)
	end

	-- call per_worker to get the per_pixel callback, per_frame callback and buffer info
	local function worker(worker_arg)
		local thread_ffi = require("ffi")
		thread_ffi.cdef(cdef)


		-- get a pointer to the shared memory by deserializing the buf_ptr_str upvalue to share FFI pointers across threads
		local thread_buf_ptr = str_to_pointer(thread_ffi, buf_ptr_str, "uint8_t*")

		local per_pixel_cb,per_frame_cb = per_worker(w,h,bytes_per_pixel,stride,thread_ffi,worker_arg)

		-- thread main loop
		local last_seq, per_frame
		while true do
			-- wait for work request
			local y,line_count,seq = req_channel:pop()

			-- if seq has changed, get the new per_frame data from per_frame_cb
			if seq ~= last_seq then
				per_frame = per_frame_cb(seq)
				last_seq = seq
			end

			-- perform line_count ammount of work and call per_pixel_cb for every pixel in work segment
			for o=0, line_count-1 do
				for x=0, w-1 do
					-- call per_pixel_cb for every pixel in every line
					-- TODO: optimize this into a single loop? e.g. for y do for x do buf[i]=px; i++; end end
					local i = (y+o)*w*bytes_per_pixel+x*bytes_per_pixel
					per_pixel_cb(x,y+o,thread_buf_ptr,i,per_frame)
				end
			end

			-- push generated lines as string to collector thread
			ret_channel:push(line_count,seq)
		end
	end

	-- collection thread reads from the ret_channel and pushes a message to frame_channel when a complete frame is ready
	local function collector()
		while true do
			-- collect the correct ammount of lines, then push to frame_channel
			local lines,last_seq = 0,0
			while lines<h do
				local line_count,seq = ret_channel:pop() -- TODO: Multiple frames by seq? Difficult using only shared memory
				lines = lines + line_count
				progress_channel:push(lines,seq)
			end
			frame_channel:push(true,last_seq)
		end
	end

	-- send requests to req_channel in groups of stride(increase seq for every call)
	local seq = 0
	local request_ready = true
	local function send_requests()
		if request_ready then
			local last_y = 0
			for y=0, (h/stride)-1 do
				req_channel:push(y*stride, stride, seq)
				last_y = y*stride+stride-1
			end
			for y=last_y+1, h-1 do
				req_channel:push(y, 1, seq)
			end
			seq = seq + 1
			request_ready = false
		end
	end

	-- get the last rendering progress
	local last_progress,last_seq
	local function get_progress()
		while progress_channel:size()>0 do -- if there is a new progress update
			last_progress,last_seq = progress_channel:pop() -- update last_progress(this should never block)
		end
		return last_progress,last_seq
	end

	-- get a single frame_data from the stack(timeout=nil is wait, timeout=0 is nonblocking)
	local function get_frame(t)
		local frame_ready,frame_seq = frame_channel:pop(t)
		if frame_ready then
			request_ready = true
			if no_string then
				return buf_ptr,buf_len,frame_seq -- return only ffi ptr
			else
				return buffer_to_str(),frame_seq -- serialize buffer as str
			end
		end
	end

	-- render a single frame, blocking
	local function render()
		-- push work requests to the req_channel
		send_requests()

		return get_frame()
	end

	local running = false
	local collector_t
	local worker_ts = {}
	local function start(worker_arg)
		if running then
			return
		end
		running = true

		-- start a worker thread for every hardware thread + 1
		for _=1, threads do
			local th = effil.thread(wrap_cb(worker))(worker_arg)
			table.insert(worker_ts, th)
		end

		-- start a single collector thread
		collector_t = effil.thread(wrap_cb(collector))()
	end

	return {
		start = start,
		send_requests = send_requests,
		get_progress = get_progress,
		get_frame = get_frame,
		render = render,
		collector_t = collector_t,
		worker_ts = worker_ts,
		req_channel = req_channel,
		ret_channel = ret_channel,
		frame_channel = frame_channel,
		progress_channel = progress_channel,
		buffer_to_str = buffer_to_str,
		buf_ptr = buf_ptr -- this is important:
		-- if this reference is deleted the main thread GC thinks there is no
		-- reference to buf_ptr anymore and calls it's __gc metamethod that
		-- calls free() on the buf_ptr while the worker threads are still
		-- writing to the memory(results in segfaults). The memory now is only
		-- free() if there is no more reference to the returned pixel function table.
	}
end


return multithread_pixel_function
