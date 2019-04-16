local ldb = require("lua-db.lua_db")

local raw = {}
-- this module contains some shortcuts for encoding/decoding raw pixel
-- data from lua-db. No headers are checked, but the string lenght must
-- must match width*height*4. The raw pixel format is always 32bpp RGBA.


-- string+dimensions to new drawbuffer
function raw.decode_from_string_drawbuffer(str, width, height)	
	local db = ldb.new(width, height)
	
	assert(db:load_data(str))
	
	return db
end


-- filepath+dimensions to new drawbuffer
function raw.decode_from_file_drawbuffer(filepath, width, height)
	local file = assert(io.open(filepath, "rb"))
	local str = file:read("*a")
	
	return raw.decode_from_string_drawbuffer(str, width, height)
end


-- drawbuffer to string(dump data)
function raw.encode_from_drawbuffer(db)
	local str = db:dump_data()
	return str
end


return raw
