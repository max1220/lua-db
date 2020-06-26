--[[
this Lua module is implementing the game of life rules on a drawbuffer.
The current state of the cellular automata is in the cstate drawbuffer.
You can use :step()
]]

local gol = {}
local ldb_core = require("ldb_core")

function gol.new_gol(width, height)

	local game = {}
	game.width = assert(tonumber(width))
	game.height = assert(tonumber(height))
	game.cstate = ldb_core.new_drawbuffer(game.width, game.height, ldb_core.pixel_formats["r1"])
	game.nstate = ldb_core.new_drawbuffer(game.width, game.height, ldb_core.pixel_formats["r1"])

	function game:clear(pct)
		if (not tonumber(pct)) or (pct <= 0) then
			-- fill
			self.cstate:clear(0,0,0,255)
			return
		elseif pct >= 1 then
			self.cstate:clear(255,255,255,255)
			return
		end
		for y=0, self.height-1 do
			for x=0, self.width-1 do
				local v = (math.random(1,1/pct)==1) and 255 or 0
				self.cstate:set_px(x,y,v,v,v,255)
			end
		end
	end

	function game:step(count)
		local cstate = self.cstate
		local nstate = self.nstate

		local function is_set(x,y)
			local r = cstate:get_px(x,y)
			if (r>0) then
				return 1
			end
			return 0
		end

		local function get_3x3(x,y)
			local sum = is_set(x-1,y-1) +
				is_set(x+0,y-1) +
				is_set(x+1,y-1) +
				is_set(x-1,y+0) +
				is_set(x+1,y+0) +
				is_set(x-1,y+1) +
				is_set(x+0,y+1) +
				is_set(x+1,y+1)
			return sum
		end

		for _=1, tonumber(count) or 1 do
			for y=0, cstate:height()-1 do
				for x=0, cstate:width()-1 do
					local sum = get_3x3(x,y)

					-- game of life rules:
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
			self.cstate,self.nstate = self.nstate, self.cstate
		end
	end

	game:clear()

	return game
end


return gol
