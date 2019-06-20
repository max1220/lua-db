local ffmpeg = {}


-- A basic version of io.popen that is non-blocking.
-- returned "file" table only supports :read(with an optional size argument, no mode etc.) and :close
local function non_blocking_popen(cmd, read_buffer_size)
	local ffi = require("ffi")

	-- C functions that we need
	ffi.cdef([[
		void* popen(const char* cmd, const char* mode);
		int pclose(void* stream);
		int fileno(void* stream);
		int fcntl(int fd, int cmd, int arg);
		int *__errno_location ();
		ssize_t read(int fd, void* buf, size_t count);
	]])
	
	-- you can compile a simple C programm to find these values(Or look in the headers)
	local F_SETFL = 4
	local O_NONBLOCK = 2048
	local EAGAIN = 11
	
	-- this "array" holds the errno variable
	local _errno = ffi.C.__errno_location()

	-- the buffer for reading from the process
	local read_buffer_size = tonumber(read_buffer_size) or 2048
	local read_buffer = ffi.new('uint8_t[?]',read_buffer_size)

	-- get a FILE* for our command
	local file = assert(ffi.C.popen(cmd, "r"))
	
	-- turn the FILE* to a fd(int) for fcntl
	local fd = ffi.C.fileno(file)
	
	-- set non-blocking mode for read
	assert(ffi.C.fcntl(fd, F_SETFL, O_NONBLOCK)==0, "fcntl failed")

	-- close the process, prevent reading, allow garbage colletion
	function file_close(self)
		ffi.C.pclose(file)
		self.read_buffer = nil
		read_buffer = nil
		self.read = function() return nil, "closed"end
	end

	-- read up to size bytes from the process. Returns data(string) and number of bytes read if successfull,
	-- nil, "EAGAIN" if there is no data aviable, and
	-- nil, "closed" if the process has ended
	local read = ffi.C.read
	function file_read(self, size)
		local _size = math.min(read_buffer_size, size)
		while true do
			local nbytes = read(fd,read_buffer,_size)
			if nbytes > 0 then
				local data = ffi.string(read_buffer, nbytes)
				return data, nbytes
			elseif (nbytes == -1) and (_errno[0] == EAGAIN) then
				return nil, "EAGAIN"
			else
				file_close(self)
				return nil, "closed"
			end
		end
	end

	return {
		_fd = fd,
		_file = file,
		_read_buffer = read_buffer,
		_read_buffer_size = read_buffer_size,
		read = file_read,
		close = file_close
	}
end


-- open a stream from a ffmpeg command line.
-- Note: you need to specify the correct dimensions and pixel format to
-- ffmpeg manually if you use this function
function ffmpeg.open_command(command, width, height, nonblocking)
	local video = {}

	video.width = assert(tonumber(width))
	video.height = assert(tonumber(height))
	local frame_size = video.width*video.height*3


	-- start the playback
	function video:start()
		if nonblocking then
			video.proc = assert(non_blocking_popen(command, frame_size), "Can't open ffmpeg!")
		else
			video.proc = assert(io.popen(command), "Can't open ffmpeg!")
		end
	end

	-- return a video frame(as string)
	local buffer = {}
	local buffer_size = 0
	local last_frame
	function video.read_frame()
		local i = 0
		while true do
			i = i + 1
			local data, bytes = video.proc:read(frame_size)
			if data then
				-- got (partial) frame, append to buffer
				table.insert(buffer, data)
				buffer_size = buffer_size + (bytes or #data)
				if buffer_size >= frame_size then
					-- if the buffer contains at least 1 full frame, return that frame, and remove it from the buffer
					local _buffer = table.concat(buffer)
					local a = _buffer:sub(1, frame_size)
					local b = _buffer:sub(frame_size + 1)
					last_frame = a
					buffer = {b}
					buffer_size = #b
					return a
				else
					--print("buffer underrun", tonumber(buffer_size), frame_size)
					--return last_frame
				end
			elseif (not data) and bytes and (bytes == "closed") then
				-- file closed
				break
			elseif (not data) and bytes and (bytes == "EAGAIN") then
				-- no data aviable
				break
			else
				break
			end
		end
	end

	-- draw a frame(returned by frame_decode) to a drawbuffer
	function video:draw_frame_to_db(target_db, frame)
		target_db:load_data_rgb(frame)
	end
	
	-- stop the video
	function video:close()
		video.proc:close()
		video.read_frame = nil
		video.draw_frame_to_db = nil
	end
	
	return video
end


-- open a stream from a V4L2 device
function ffmpeg.open_v4l2(dev, width, height, nonblocking)
	local width = assert(tonumber(width))
	local height = assert(tonumber(height))
	local ffmpeg_cmd = ("ffmpeg -y -f v4l2 -video_size %dx%d -i %s -pix_fmt bgr24 -vf scale=%d:%d -f rawvideo - 2> /dev/null"):format(width, height, dev, width, height)

	return ffmpeg.open_command(ffmpeg_cmd, width, height, nonblocking)
end


-- open a stream from a video file
function ffmpeg.open_file(filename, width, height, time, audio, nonblocking)
	local width = assert(tonumber(width))
	local height = assert(tonumber(height))
	local ffmpeg_cmd
	local time_arg = time and ("-ss "..time) or ""
	local audio_arg = audio and ("-f pulse -buffer_duration 0.1 \"out\"") or ""
	local ffmpeg_cmd = ("ffmpeg -y %s -re -i %s -pix_fmt bgr24 -vf scale=%d:%d -f rawvideo - %s 2> /dev/null"):format(time_arg, filename, width, height, audio_arg)
	
	return ffmpeg.open_command(ffmpeg_cmd, width, height, nonblocking)
end


return ffmpeg
