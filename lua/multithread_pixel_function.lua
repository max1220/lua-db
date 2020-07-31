local multithread_pixel_function = {}
--[[
`local render_fn = multithread_pixel_function(db, func)`

This function returns a function(`render_fn(per_frame, do_data)`)
that calls the function `pixel = func(x,y,spixel,per_frame)` for every pixel
in the drawbuffer `db` using multiple threads to archive better performance.

The `per_frame` argument is passed to the `func` callback. Because it crosses
thread boundaries, effil conversion rules apply.

If `do_data` is set, the `func` callback gets the previous pixel value passed
as an argument(`spixel`).

The returned `pixel` value must be a string containing the bytes for the
returned pixel in the same format as specified for the drawbuffer.
No pixel "unpacking" is performed for performance reasons.

The `spixel` is the previous value for this pixel(only available if do_data is set)



Implementation
===============

Work is split into serveral task to perform actions in parralel in multiple
threads using the effil Lua threading library.

When the `multithread_pixel_function`function is called,
all threads are started. All threads do blocking waits on their input channels.

The returned function pushes a dump of the drawbuffers current content onto
`data_channel`, then waits for pixel data in the `frame_channel`, and writes
it to the drawbuffer.

The `reader()` thread pops whole drawbuffer dumps from the `data_channel`.
It then splits the frames into lines, and pushes those lines onto the
`req_channel`.

The `worker()` threads pop a line and y value from the req_channel and
executes the callback function `func` for every pixel in that line to obtain
a new line. It pushes the new line and y value onto the ret_channel.

The `collector()` thread pops a line and y value from the ret_channel and
collects the lines in a table. Once it has collected all lines, it pushes
the combined pixel data onto the frame_channel.
]]

local effil = require("effil")

function multithread_pixel_function.multithread_pixel_function(_db, _func)
	local db = assert(_db)
	local func = assert(_func)

	local w,h = db:width(),db:height()
	local byte_len = db:bytes_len()
	local bytes_per_pixel = math.ceil(byte_len/(w*h))
	local line_len = w*bytes_per_pixel

	-- create channels for inter-thread communication
	local data_channel = effil.channel()
	local req_channel = effil.channel()
	local ret_channel = effil.channel()
	local frame_channel = effil.channel()

	-- reader thread reads a complete drawbuffer from data_channel, and
	-- pushes work requests to the req_channel
	local function reader()
		--print("reader thread", effil.thread_id())
		while true do
			-- wait for a complete pixel data dump, and write a request
			-- containing an y poisiton and a line of pixel data to the req_channel
			local db_data,per_frame = data_channel:pop()
			for y=0, h-1 do
				local i = y*line_len+1
				local line = false
				if db_data then
					line = db_data:sub(i,i+line_len-1)
				end
				req_channel:push(y,line,per_frame)
			end
		end
	end

	-- worker thread reads from the req_channel, calls the callback function func,
	-- and pushes the result to the ret_channel
	local function worker()
		--print("worker thread", effil.thread_id())
		while true do
			-- wait for an y position and a line of pixel data,
			-- write an y position and new line of pixel data
			local y,line,per_frame = req_channel:pop()
			local ret = {}
			for x=0, w-1 do
				local i = x*bytes_per_pixel+1
				local pixel
				if line then
					pixel = line:sub(i,i+bytes_per_pixel-1)
				end
				pixel = func(x,y,pixel,per_frame)
				ret[#ret+1] = pixel
			end
			local ret_str = table.concat(ret)
			ret_channel:push(y,ret_str)
		end
	end

	-- collection thread reads from the ret_channel and assembles complete frames
	local function collector()
		--print("collector thread", effil.thread_id())
		while true do
			-- collect the correct ammount of lines,
			-- then return the completed frame as pixel data
			local frame = {}
			local count = 0
			while count<h do
				local y,line = ret_channel:pop()
				frame[y+1] = line
				count = count + 1
			end
			local frame_data = table.concat(frame)
			frame_channel:push(frame_data)
		end
	end

	-- catch errors in thread functions
	local function wrap_cb(fn)
		return function()
			local ok,err = pcall(fn)
			if not ok then
				print("\027[31m"..("-"):rep(80))
				print("Error:", tostring(err))
				print(debug.traceback())
				print(("-"):rep(80), "\027[0m")
			end
		end
	end

	-- render a single frame, blocking
	local function render(per_frame, do_data)
		-- we can't share a drawbuffer accross threads(it's a userdata value)
		local data = false
		if do_data then
			-- load data from drawbuffer
			data = db:dump_data()
		end

		-- push the data to be proccessed into a work queue into the data_channel
		data_channel:push(data, per_frame)

		-- pop the returned completed frame from frame_channel
		data = frame_channel:pop()

		-- load data back to drawbuffer
		db:load_data(data)
	end

	-- render a single frame, non-blocking
	local ready = true
	local function render_nb(per_frame, data)
		-- if we have a frame ready, return it
		local frame_data = frame_channel:pop(0)
		if frame_data then
			ready = true
			return frame_data
		end

		-- no outstanding request
		if (not data) or (data and not (#data==byte_len)) then
			-- don't pass data if it's the wrong size or missing
			data = false
		end

		-- push request
		if ready then
			ready = false
			data_channel:push(data, per_frame)
		end

		-- no result yet
		return false,ret_channel:size(),req_channel:size()
	end

	local reader_t, collector_t
	local worker_ts = {}
	local running = false
	local function start()
		if running then
			return
		end
		running = true

		-- start a single reader thread
		reader_t = effil.thread(wrap_cb(reader))()

		-- start a worker thread for every hardware thread + 1
		for _=1, effil.hardware_threads()+1 do
			local worker_t = effil.thread(wrap_cb(worker))()
			worker_ts[#worker_ts+1] = worker_t
		end

		-- start a single collector thread
		collector_t = effil.thread(wrap_cb(collector))()
	end

	-- pause all work
	local function pause()
		reader_t:pause()
		collector_t:pause()
		for i=1, #worker_ts do
			worker_ts[i]:pause()
		end
	end

	-- resume all work
	local function resume()
		reader_t:resume()
		collector_t:resume()
		for i=1, #worker_ts do
			worker_ts[i]:resume()
		end
	end

	return {
		start = start,
		pause = pause,
		resume = resume,
		render = render,
		render_nb = render_nb
	}
end

return multithread_pixel_function
