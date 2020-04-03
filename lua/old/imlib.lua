local ldb = require("lua-db.lua_db")

local imlib = {}

-- glue code to load an image using imlib2
function imlib.from_file(filepath)
	local im = require("imlib2")
	local img = assert(im.image.load(filepath))

	local width = img:get_width()
	local height = img:get_height()
	local out_db = ldb.new(width, height)

	for y=0, height do
		for x=0, width do
			local px = img:get_pixel(x,y)
			out_db:set_pixel(x,y, px.red, px.green, px.blue, px.alpha)
		end
	end
	
	return out_db
end

return imlib
