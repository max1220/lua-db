local wrap_cb = require("lua-db.wrap_cb")

-- multithreaded, ffi and stride(optimized hotloop for luajit)
-- per_pixel_cb,per_frame_cb,buf,len = per_worker(w,h,bytes_per_pixel,stride,ffi,worker_arg)
-- buf is a ffi buffer of len bytes
-- per_pixel_cb(x,y,o,per_frame) modifies this buffer at the global position x,y+o(buffer local position x,o)
local function multithread_pixel_function_ffi(w,h, bytes_per_pixel, threads, stride, per_worker)
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
		local lines_buf = thread_ffi.new("uint8_t[?]", len)

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
					per_pixel_cb(x,y+o,lines_buf,i,per_frame)
				end
			end

			-- push generated lines as string to collector thread
			ret_channel:push(y,line_count,thread_ffi.string(thread_ffi.cast("char*",lines_buf), len), seq)
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
		type = "multithread_pixel_function_ffi",
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

return multithread_pixel_function_ffi
