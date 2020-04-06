#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")


-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "terminal",
	default_terminal_mode = "halfblocks",
	terminal_no_colors = true,
}, arg)
cio:init()
local w,h = cio:get_native_size()

-- create 2 drawbuffers: one for the current state, one for the new state(1bpp)
local cstate = ldb.new_drawbuffer(w,h, ldb.pixel_formats["r1"])
local nstate = ldb.new_drawbuffer(w,h, ldb.pixel_formats["r1"])

-- set seed for randomizing the initial state
math.randomseed(time.realtime())

-- randomize current state drawbuffer
for y=0, h-1 do
	for x=0, w-1 do
		local v = math.random(1,5)==1 and 255 or 0
		cstate:set_px(x,y,v,v,v,255)
	end
end

-- returns 1 if the cell at x,y is alive, 0 otherwise
local function is_set(x,y)
	local r = cstate:get_px(x,y)
	if (r>0) then
		return 1
	end
	return 0
end

-- gets the ammount of alive cells surrounding x,y
local function get_3x3(x,y)
	return is_set(x-1,y-1) +
		is_set(x+0,y-1) +
		is_set(x+1,y-1) +
		is_set(x-1,y+0) +
		is_set(x+1,y+0) +
		is_set(x-1,y+1) +
		is_set(x+0,y+1) +
		is_set(x+1,y+1)
end

-- run a game of life step(iterate over each pixel in the old state, set cells in new_db)
local function gol_step()
	for y=0, cstate:height()-1 do
		for x=0, cstate:width()-1 do
			local sum = get_3x3(x,y)
			if is_set(x,y) > 0 then
				-- cell alive
				if sum < 2 then
					-- dies of underpopulation
					nstate:set_px(x,y,0,0,0,0)
				elseif sum == 2 or sum == 3 then
					-- keep alive
					nstate:set_px(x,y,255,255,255,255)
				else
					-- dies of overpopulation
					nstate:set_px(x,y,0,0,0,0)
				end
			else
				-- cell dead
				if sum == 3 then
					-- spawn new
					nstate:set_px(x,y,255,255,255,255)
				else
					-- stay dead
					nstate:set_px(x,y,0,0,0,0)
				end
			end
		end
	end
end


-- run until cio stops
while not cio.stop do
	-- run a game of life step
	gol_step(cstate, nstate)

	-- swap drawbuffers
	cstate,nstate = nstate, cstate

	-- draw drawbuffer to output
	cio:update_output(nstate)
	cio:update_input()
end
