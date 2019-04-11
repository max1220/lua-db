local sox = {}
-- library for handling and generating sounds


function sox.open_command(sox_command, sample_rate)
	local sound = {}
	sound.sample_rate = sample_rate
	
	
	-- return a function that takes a sample count and returns samples of a sinewave at that frequency.
	function sound:generate_sin(pitch)
		local sin = math.sin
		
		-- generate a single sample based on it's index
		local function generate_frame(frame_index)
			local seconds_per_frame = 1/self.sample_rate
			local radians_per_second = pitch * 2 * math.pi
			return sin(frame_index * seconds_per_frame * radians_per_second)
		end
		
		-- generate a ammount of samples
		local function generate_frames(frame_count, frame_index, frames_buf)
			local frames = frames_buf or {}
			for frame_offset=0, frame_count-1 do
				frames[frame_offset + 1] = generate_frame(frame_offset+frame_index)
			end
			return frames, frame_count+frame_index
		end
		
		return generate_frames
		
	end
	
	
	-- generate a square wave by generating a sine wave, then set the output sample high if a sample is >0, low otherwise.
	function sound:generate_square(pitch)
		local sin = math.sin
		
		-- generate a single sample based on it's index
		local function generate_frame(frame_index)
			local seconds_per_frame = 1/self.sample_rate
			local radians_per_second = pitch * 2 * math.pi
			local s = sin(frame_index * seconds_per_frame * radians_per_second)
			if s > 0 then
				return 1
			end
			return -1
		end
		
		-- generate a ammount of samples
		local function generate_frames(frame_count, frame_index, frames_buf)
			local frames = frames_buf or {}
			for frame_offset=0, frame_count-1 do
				frames[frame_offset + 1] = generate_frame(frame_offset+frame_index)
			end
			return frames, frame_count+frame_index
		end
		
		return generate_frames
	end
	
	
	
	function sound:empty_buffer(frame_count, frame_buf)
		local frame_buf = frame_buf or {}
		for i=1, frame_count do
			frame_buf[i] = 0
		end
		return frame_buf
	end
	
	
	
	function sound:mix_frames(frame_bufs, out_buf)
		for i, frame_buf in ipairs(frame_bufs) do
			for j=1, #frame_buf do
				out_buf[j] = out_buf[j] + frame_buf[j]
			end
		end
		for j=1, #out_buf do
			out_buf[j] = math.tanh(out_buf[j])
		end
		return out_buf
	end
	
	
	-- final step in output, mix multiple sample channels together and set their volumes
	function sound:mix(channels, frame_count)
		local out_samples = {}
		local out_counts = {}
		for i, channel in ipairs(channels) do
			local samples = channel.generate_samples(frame_count)
			if samples then
				for j=1, #samples do
					out_samples[j] = out_samples[j] + samples[j] * channel.volume
					out_counts[j] = out_counts[j] + 1
				end
			end
		end
		for i=1, #out_samples do
			--out_samples[i] = out_samples[i] / out_counts[i]
			out_samples[i] = math.tanh(math.tanh(out_samples[i] * 0.9))
		end
		return out_samples
	end
	
	
	-- open the proc
	function sound:open_proc()
		self.proc = assert(io.popen(sox_command, "w"))
		self.proc:setvbuf("no")
	end
	
	
	-- write samples to sox
	local out_buffer = {}
	local _c = string.char
	local _f = math.floor
	local function a_to_c(a)
		return _c( _f( (a+1)*127 ) )
	end
	function sound:write_samples(samples)
		local last_sample
		local skip = 0
		for i=1, #samples do
			local csample = a_to_c(samples[i-skip])
			out_buffer[i-skip] = csample
			if last_sample == 0 and csample == 0 then
				skip = skip + 1
			end
			last_sample = csample
			--self.proc:write(csample)
		end
		self.proc:write(table.concat(out_buffer))
		self.proc:flush()
	end
	
	return sound
end



function sox.open_default()
	return sox.open_command("play -V3 --buffer 256 -t raw -b 8 -e unsigned-integer -c 1 -r 11025 -", 11025)
	-- return sox.open_command("pv > /dev/null", 22050)
end



return sox
