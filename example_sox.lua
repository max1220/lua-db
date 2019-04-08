#!/usr/bin/env luajit

local sox = require("sox")


local snd = sox.open_default()
local gen_sin = snd:generate_sin(440)
local gen_sqr = snd:generate_square(220)



local function plot_samples(samples, max_width)
	local ldb = require("ldb")
	local braile = require("braile")
	local term = require("term")
	local width = math.min(#samples, max_width or 200)
	local height = 50
	
	local db = ldb.new(width, height)
	db:clear(0,0,0,255)
	db:set_line(0, math.floor(height/2), width-1, math.floor(height/2), 127,127,127,255)
	local last_sample = 0
	for i=1, #samples do
		local sample = ((samples[i]+1)/2)*(height-1)
		db:set_line(i-1, last_sample, i, sample, 255,0,0,255)
		last_sample = sample
	end
	local lines = braile.draw_db_precise(db, 1, true)
	print(term.set_cursor(0,0) .. table.concat(lines, term.reset_color() .. "\n"))
end





snd:open_proc()
local last
while true do
	local samples
	if last then
		print("sin")
		samples = gen_sin(2 * 22050)
		last = false
	else
		print("sqr")
		samples = gen_sqr(2 * 22050)
		last = true
	end
	plot_samples(samples)
	snd:write_samples(samples)
end
