local sox = {}
-- library for handling and generating sounds


function sox.open_command(sox_command, sample_rate)
	local sound = {}
	sound.sample_rate = sample_rate
	
	
	-- return a function that takes a sample count and returns samples of a sinewave at that frequency.
	function sound:generate_sin(pitch)
		local seconds_per_frame = 1/self.sample_rate
		local radians_per_second = pitch * 2 * math.pi
		local frame_count = 1000
		local offset_seconds = 0
		
		-- generate a single sample based on frame, the sample index
		local function generate_sample()
			local sample = math.sin(offset_seconds * radians_per_second)
			offset_seconds = (offset_seconds + seconds_per_frame) % 10000
			return sample
		end
		
		-- generate a ammount of samples
		local function generate_samples(frame_count)
			local samples = {}
			for frame=0, frame_count-1 do
				local sample = generate_sample(frame)
				table.insert(samples, sample)
			end
			return samples
		end
		
		return generate_samples
		
	end
	
	
	-- generate a square wave by generating a sine wave, then set the output sample high if a sample is >0, low otherwise.
	function sound:generate_square(pitch)
		local _generate_samples = sound:generate_sin(pitch)
		local function generate_samples(frame_count)
			local samples = _generate_samples(frame_count)
			for i=1, #samples do
				if samples[i] > 0 then
					samples[i] = 1
				else
					samples[i] = -1
				end
			end
			return samples
		end
		return generate_samples
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
			out_samples[i] = out_samples[i] / out_counts[i]
			out_samples[i] = math.tanh(out_samples[i])
		end
		return out_samples
	end
	
	
	-- open the proc
	function sound:open_proc()
		self.proc = assert(io.popen(sox_command, "w"))
		self.proc:setvbuf("full")
	end
	
	
	-- write samples to sox
	function sound:write_samples(samples)
		local proc = assert(self.proc)
		local sample_data = {}
		for i=1, #samples do
			sample_data[i] = string.char(math.floor((samples[i] + 1) * 127.5))
		end
		proc:write(table.concat(sample_data))
		proc:flush()
	end
	
	return sound
end



function sox.open_default()
	return sox.open_command("play -t raw -b 8 -e unsigned -c 1 -r 22050 - 2> /dev/null", 22050)
end



return sox
