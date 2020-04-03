local ppm = {}
-- encode/decode a portable pixmap(.ppm) image file


-- decode a .ppm from a string, calling pixel_callback for each pixel
function ppm.decode_from_string_pixel_callback(str, pixel_callback)
	local width, height
	assert(str:sub(1,3) == "P3\n")
	local i = 0
	for line in str:gmatch("[^\r\n]+") do
		if not width then
			-- first line should contain the width and height
			width, height = str:match("^(%d+) (%d+)$")
			width = assert(tonumber(width))
			height = assert(tonumber(height))
		elseif not line:match("^%s+#") then
			-- increase i for each r,g,b tripplet, then call pixel_callback for the x,y coordinated with the r,g,b values
			for r,g,b in line:gmatch("(%d*)%s+(%d*)%s+(%d*)%s*") do
				local x = i % width
				local y = (i-x)/width
				pixel_callback(x,y,r,g,b)
				i = i + 1
			end
		end
	end
	
	return width, height
end


-- decode a .ppm from a string into a drawbuffer
function ppm.decode_from_string_drawbuffer(str)
	local ldb = require("lua-db")
	local db = ldb.new(header.width, header.height)
	
	pgm.decode_from_string_pixel_callback(str, function(x,y,r,g,b)
		db:set_pixel(x,y,r,g,b,255)
	end)
	
	return db
end


-- decode from a file into a new drawbuffer
function ppm.decode_from_file_drawbuffer(filepath)
	local file = assert(io.open(filepath, "rb"))
	local str = file:read("*a")
	return ppm.decode_from_string_drawbuffer(str)
end


-- encode a .ppm based on a width, height and pixel_callback
function ppm.encode_from_pixel_callback(width, height, pixel_callback)
	local ppm_data = {
		"P3",
		width .. " " .. height,
		255
	}
	for y=0, height-1 do
		local cline = {}
		for x=0, width-1 do
			local r,g,b = pixel_callback(x,y)
			table.insert(cline, ("%.3d %.3d %.3d"):format(r,g,b))
		end
		table.insert(ppm_data, table.concat(cline, "\n"))
	end
	
	return table.concat(ppm_data, "\n")
end


-- encode a .ppm based on a drawbuffer
function ppm.encode_from_drawbuffer(db)
	local width = db:width()
	local height = db:height()
	
	local ppm = ppm.encode_from_pixel_callback(width, height, function(x,y)
		local r,g,b = db:get_pixel(x,y)
		return r,g,b
	end)
	
	return ppm
end


return ppm
