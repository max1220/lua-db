--[[
This module provides additional randomness-related functions, e.g. enerating continuous noise.
]]
--luacheck: no max line length
local random = {}


function random.new_rng()
	local rng = {}

	-- initialize the seedbox to random values
	function rng:seed()
		local seedbox = {}
		for i=0, 255 do
			seedbox[i] = math.random()
		end
		self.seedbox = seedbox
	end


	-- return a random number for i
	function rng:noise_1d(i)
		local seed_index = math.floor(i)%255
		return self.seedbox[seed_index]
	end


	-- simple 1D continuous noise function
	function rng:continuous_noise_1d(f)
		local a,b = self:noise_1d(f), self:noise_1d(f+1)
		local p = f%1
		local v = (p*b)+((1-p)*a)
		return v
	end


	-- return a random number for x,y
	function rng:noise_2d(x,y)
		local seed_index = math.floor((x + y*15731)%255)
		return self.seedbox[seed_index]
	end


	-- simple 2D continuous noise function
	function rng:continuous_noise_2d(x,y)
		local xi,xf = math.floor(x), x%1
		local yi,yf = math.floor(y), y%1
		local n00 = self:noise_2d(xi,yi)
		local n01 = self:noise_2d(xi,yi+1)
		local n10 = self:noise_2d(xi+1,yi)
		local n11 = self:noise_2d(xi+1,yi+1)

		local nx = (n11*yf)+(n10*(1-yf))
		local ny = (n01*yf)+(n00*(1-yf))

		local v = (nx*xf)+(ny*(1-xf))

		return v
	end

	return rng
end


return random
