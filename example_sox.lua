#!/usr/bin/env luajit

local ldb = require("lua-db")
local sox = require("sox")
local input = require("lua-input")
local time = require("time")

local function plot_samples(samples, max_width)
	
	local width = math.min(#samples, max_width or 150)
	local height = 90
	
	local db = ldb.new(width, height)
	db:clear(0,0,0,255)
	db:set_line(0, math.floor(height/2), width-1, math.floor(height/2), 127,127,127,255)
	local last_sample = height/2
	for i=1, #samples do
		local sample = ((samples[i]+1)/2)*(height-1)
		db:set_line(i-1, last_sample, i, sample, 255,0,0,255)
		last_sample = sample
	end
	local lines = ldb.braile.draw_db_precise(db, 1, true)
	print(ldb.term.set_cursor(0,0) .. table.concat(lines, ldb.term.reset_color() .. "\n"))
end





local snd = sox.open_default()
-- how many samples to generate per iteration
local frame_count = 256


-- map a key to a configuration for the tone generator
local mapping = {
	[input.event_codes.KEY_Q] = { gen = snd:generate_sin(27), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_W] = { gen = snd:generate_sin(41), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_E] = { gen = snd:generate_sin(61), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_R] = { gen = snd:generate_sin(87), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_T] = { gen = snd:generate_sin(130), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_Y] = { gen = snd:generate_sin(196), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_U] = { gen = snd:generate_sin(329), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_I] = { gen = snd:generate_sin(440), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_O] = { gen = snd:generate_sin(659), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_P] = { gen = snd:generate_sin(987), buf = snd:empty_buffer(frame_count), index = 0},
	
	[input.event_codes.KEY_A] = { gen = snd:generate_square(41), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_S] = { gen = snd:generate_square(61), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_D] = { gen = snd:generate_square(87), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_F] = { gen = snd:generate_square(130), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_G] = { gen = snd:generate_square(196), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_H] = { gen = snd:generate_square(329), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_J] = { gen = snd:generate_square(440), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_K] = { gen = snd:generate_square(659), buf = snd:empty_buffer(frame_count), index = 0},
	[input.event_codes.KEY_L] = { gen = snd:generate_square(987), buf = snd:empty_buffer(frame_count), index = 0},
}





snd:open_proc()
local last
local frame_index = 0
local frame_buffer = snd:empty_buffer(frame_count)
local tones
local input_dev = assert(input.open(arg[1]), true)
local last_time = time.realtime()
while true do

	local ev = input_dev:read()
	while ev do
	if ev.type == input.event_codes.EV_KEY then
			if mapping[ev.code] then
				mapping[ev.code].active = (ev.value ~= 0)
			end
		end
		ev = input_dev:read()
	end
	
	if (time.realtime() - last_time)+0.01 >= (1/snd.sample_rate) * frame_count then
	
		local frames_bufs = {}
		for key, sound in pairs(mapping) do
			if sound.active then
				local frame_buf, frame_index = sound.gen(frame_count, sound.index, sound.buf)
				sound.buf = frame_buf
				sound.index = frame_index
				table.insert(frames_bufs, frame_buf)
			else
				sound.buf = snd:empty_buffer(frame_count, sound.buf)
				sound.index = 0
			end
		end
	
		snd:empty_buffer(frame_count, frame_buffer)
		snd:mix_frames(frames_bufs, frame_buffer)
		snd:write_samples(frame_buffer)
		plot_samples(frame_buffer)
		last_time = time.realtime()
	else
		time.sleep(0.005)
	end
	
end
