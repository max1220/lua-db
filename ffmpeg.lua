local ffmpeg = {}


-- open a stream from a ffmpeg command line.
-- Note: you need to specify the correct dimensions and pixel format to
-- ffmpeg manually if you use this function
function ffmpeg.open_command(command, width, height)
	local video = {}
	
	video.width = assert(tonumber(width))
	video.height = assert(tonumber(height))
	
	
	
	-- start the playback
	function video:start()
		print("command", command)
		video.proc = assert(io.popen(command, "r"), "Can't open ffmpeg!")
	end
	
	-- returns a function that will return ffmpeg raw frames as strings
	local function get_frame_reader()
	
		local frame_size = video.width*video.height*3
		local cframe = ""
		
		-- this function always returns whole frames(That is, frame_size of bytes from the fd)
		local function read_frame()
			assert(video.proc)
			local frame = video.proc:read(frame_size)
			if #frame == frame_size then
				cframe = ""
				return frame
			elseif frame then
				cframe = cframe .. frame
				if #cframe >= frame_size then
					local frame = cframe:sub(1, frame_size)
					cframe = cframe:sub(frame_size+1)
					return frame
				end
			else
				return nil
			end
		end
		
		return read_frame
	end
	video.read_frame = get_frame_reader()
	
	
	
	-- draw a frame(returned by frame_decode) to a drawbuffer
	function video:draw_frame_to_db(target_db, frame)
		for x=0, width-1 do
			for y=0, height-1 do
				local i = (y*self.width+x)*3+1
				local r,g,b = string.byte(frame, i, i+2)
				target_db:set_pixel(x,y,r,g,b,255)
			end
		end
	end
	
	
	return video
end


-- open a stream from a V4L2 device
function ffmpeg.open_v4l2(dev, width, height)
	local width = assert(tonumber(width))
	local height = assert(tonumber(height))
	local ffmpeg_cmd = ("ffmpeg -y -f v4l2 -video_size %dx%d -i %s -pix_fmt rgb24 -vf scale=%d:%d -f rawvideo - 2> /dev/null"):format(width, height, dev, width, height)
	return ffmpeg.open_command(ffmpeg_cmd, width, height)
end


-- open a stream from a video file
function ffmpeg.open_file(filename, width, height, time)
	local width = assert(tonumber(width))
	local height = assert(tonumber(height))
	local ffmpeg_cmd
	if time then
		ffmpeg_cmd = ("ffmpeg -y -ss %s -re -i %s -pix_fmt rgb24 -vf scale=%d:%d -f rawvideo - 2> /dev/null"):format(time, filename, width, height)
	else
		ffmpeg_cmd = ("ffmpeg -y -re -i %s -pix_fmt rgb24 -vf scale=%d:%d -f rawvideo - 2> /dev/null"):format(filename, width, height)
	end
	return ffmpeg.open_command(ffmpeg_cmd, width, height)
end


return ffmpeg
