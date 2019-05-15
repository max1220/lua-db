#!/usr/bin/env luajit
local ldb = require("lua-db")

local gen = 0
local function gol_step(state_db, new_db)
	-- set the cell in the new state
	local function set_px(x,y, alive)
		if alive then
			new_db:set_pixel(x,y,255,255,255,255)
		else
			new_db:set_pixel(x,y,0,0,0,0)
		end
	end

	-- returns 1 if the cell at x,y is alive, 0 otherwise
	local function is_set(x,y)
		local r,g,b,a = state_db:get_pixel(x,y)
		if (a>0) and (r+g+b > 0) then
			return 1
		end
		return 0
	end

	-- gets the sum of the 3x3 area surrounding x,y
	local function get_3x3(x,y)
		return is_set(x-1,y-1) + is_set(x+0,y-1) + is_set(x+1,y-1) + is_set(x-1,y+0) + is_set(x+1,y+0) + is_set(x-1,y+1) + is_set(x+0,y+1) + is_set(x+1,y+1)
	end

	-- iterate over each pixel in the old state, set cells in new_db
	for y=0, state_db:height()-1 do
		for x=0, state_db:width()-1 do
			-- get neighbours
			local sum = get_3x3(x,y)
			
			-- pixels[5] is the center pixel of the 3x3 area
			if is_set(x,y) > 0 then
				-- cell alive
				if sum < 2 then
					-- dies of underpopulation
					set_px(x,y,false)
				elseif sum == 2 or sum == 3 then
					-- keep alive
					set_px(x,y,true)
				else
					-- dies of overpopulation
					set_px(x,y,false)
				end
			else
				-- cell dead
				if sum == 3 then
					-- spawn new
					set_px(x,y,true)
				else
					-- stay dead
					set_px(x,y,false)
				end
			end
			
		end
	end
	
	gen = gen + 1
end


-- fill the area with random pixels
local function random_fill(db)
	for y=0, db:height()-1 do
		for x=0, db:width()-1 do
			local v = (math.random(0,5)==0 and 1 or 0 )*255
			db:set_pixel(x,y,v,v,v,255)
		end
	end
end


local sw,sh = ldb.term.get_screen_size()
local w = tonumber(arg[1]) or (sw*2-2)
local h = tonumber(arg[2]) or (sh*4-4)
local cstate = ldb.new(w,h)
local nstate = ldb.new(w,h)
random_fill(cstate)


while true do
	-- run a game of life step
	gol_step(cstate, nstate)
	
	-- swap references to drawbuffers
	local tmp = cstate
	cstate = nstate
	nstate = tmp

	-- draw current iteratiom on screen
	local lines = ldb.braile.draw_db(cstate, 0)
	io.write(ldb.term.set_cursor(0,0))
	io.write(table.concat(lines, ldb.term.reset_color() .. "\n"))
	io.write( ldb.term.reset_color(), "\ngen: " .. gen .. "       \n")
end
