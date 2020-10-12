local wrap_cb = require("lua-db.wrap_cb")

-- multithreaded, no ffi, no stride(simple implementation, compatible with PUC Lua)
-- per_pixel_cb, per_frame_cb = per_worker(w,h,bytes_per_pixel,worker_arg)
-- px_str = per_pixel_cb(x,y,buf,i,per_frame) -- put at buf[i] a 3-byte string(r,g,b)
local function multithread_pixel_function_simple(w,h, bytes_per_pixel, threads, per_worker)
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
		local line_buf = {}

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
				per_pixel_cb(x,y,line_buf,x+1,per_frame)
			end

			-- push result
			ret_channel:push(y,table.concat(line_buf),seq)
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
		type = "multithread_pixel_function_simple",
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

return multithread_pixel_function_simple
