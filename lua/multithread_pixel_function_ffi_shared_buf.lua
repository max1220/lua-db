local wrap_cb = require("lua-db.wrap_cb")

-- multithreaded, ffi and stride, using shared memory(optimized hotloop for luajit, no memory copy)
-- usage is the same as multithread_pixel_function_ffi, except the new parameter no_string.
-- if no_string is truethy the result is not stringified, but returned as the ffi buffer and it's length.
local function multithread_pixel_function_ffi_shared_buf(w,h, bytes_per_pixel, threads, stride, per_worker, no_string)
	local effil = require("effil")

	-- check arguments/use default values
	w,h = assert(tonumber(w)),assert(tonumber(h))
	bytes_per_pixel = assert(tonumber(bytes_per_pixel))
	stride = tonumber(stride) or 24 -- 24 is a good default, because (240, 360, 480, 720, 1080)%24 == 0
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

		-- TODO: write benchmark for this:
		--jit.opt.start("loopunroll=60")
		--jit.opt.start("callunroll=5")
		--jit.opt.start("recunroll=3")
		--jit.opt.start("hotloop=200")
		--jit.opt.start("maxside=200")
		--jit.opt.start("maxsnap=2000")
		--jit.opt.start("maxirconst=100")
		--jit.opt.start("maxrecord=8000")
		--jit.opt.start("maxtrace=2000")

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
			jit.flush()
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
		type = "multithread_pixel_function_ffi_shared_buf",
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

return multithread_pixel_function_ffi_shared_buf
