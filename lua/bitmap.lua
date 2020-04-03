--[[
this Lua module handles reading and writing bitmaps(Image files).
It only supports reading 24bpp rgb and 32bpp rgba bitmaps, and writing 24bpp rgb bitmaps.
]]
--luacheck: ignore self, no max line length
local ldb = require("ldb_core")




-- encode a unsigned integer of 8,16 or 32 bits
local function uint8(...)
	return string.char(...)
end
local function uint16(val)
	local a = val % 256
	local b = (val - a) / 256
	return uint8(a,b)
end
local function uint32(val)
	local a = val % 2^8
	local b = ((val - a) / 2^8) % 2^8
	local c = ((val - a - 2^8*b) / 2^16) % 2^8
	local d = ((val - a - 2^8*b - 2^16*c) / 2^24) % 2^8
	return uint8(a,b,c,d)
end


-- decode an unsigned integer of 8 or 32 bits from a byte offset in the string
local function r_uint8(str, i)
	return str:byte(i+1)
end
local function r_uint32(str, i)
	local a,b,c,d = str:byte(i+1,i+4)
	local n = a + b*2^8 + c*2^16 + d*2^24
	return n
end




local Bitmap = {}

-- generate a 24bpp bitmap header for the specified width, height
-- TODO: Add 32bpp header generation
function Bitmap.generate_header(width, height)
	-- calculate required file sizes
	local fileheader_size = 14
	local dibheader_size = 40
	local data_size = width*height*3
	local file_size = fileheader_size + dibheader_size + data_size
	local data_offset = fileheader_size + dibheader_size

	local header = {
		-- file header
		"BM",
		uint32(file_size), -- complete file size
		uint32(0), -- reserved
		uint32(data_offset), -- fileoffset_to_pixelarray

		-- actual bitmap header
		uint32(dibheader_size), -- dibheadersize
		uint32(width), -- width
		uint32(height), -- height
		uint16(1), -- planes
		uint16(24), -- bits per pixel
		uint32(0), -- compression
		uint32(data_size), -- imagesize
		uint32(0x130B), -- ypixelpermeter(72dpi)
		uint32(0x130B), -- xpixelpermeter(72dpi)
		uint32(0), -- numcolorspallette
		uint32(0), -- mostimpcolor
	}

	return table.concat(header)
end


-- decodes a bitmap header in a string to a table
function Bitmap.decode_header(str)
	-- check bitmap format
	assert(str:sub(1,2) == "BM", "Bitmap magic header not found!")

	-- check compression
	assert((r_uint8(str, 30)==0) or (r_uint8(str, 30)==3), "Only uncompressed bitmaps are supported!")

	-- check supported pixel order
	if r_uint8(str, 30)==3 then
		assert(r_uint32(str, 54)==0xff0000)
		assert(r_uint32(str, 58)==0xff00)
		assert(r_uint32(str, 62)==0xff)
		assert(r_uint32(str, 66)==0xff000000)
	end

	-- check bpp
	local bpp = r_uint8(str, 28)
	assert((bpp == 24) or (bpp == 32), "Onyl 24bpp and 32bpp bitmaps are supported!")

	-- extract bitmap dimensions
	local width = r_uint32(str, 18)
	local height = r_uint32(str, 22)

	-- check data_size
	local data_size = width*height*3
	if bpp == 32 then
		data_size = width*height*4
	end
	assert(r_uint32(str, 34) == data_size, ("Header data size: %d, expected data size: %d"):format(r_uint32(str, 34), data_size))

	local header = {
		width = width,
		height =  height,
		bpp = bpp,
		data_size = data_size,
		data_offset = r_uint32(str, 10)
	}

	return header
end


-- decode a bitmap, calling the pixel_callback for each pixel(top to bottom, left to right)
function Bitmap.decode_from_string_pixel_callback(str, pixel_callback)
	local header = Bitmap.decode_header(str)

	-- extract the r,g,b bytes from the bitmaps, and call pixel_callback with x,y,r,g,b(,a)
	local stride = 3
	if header.bpp == 32 then
		stride = 4
	end
	for y=0, header.height-1 do
		for x=0, header.width-1 do
			local i = header.data_offset + (y*header.width+x)*stride + 1
			local b,g,r,a = str:byte(i, i+stride)
			pixel_callback(x,header.height-y-1,r,g,b,a)
		end
	end

	return header
end


-- decode from a string into a new drawbuffer with the correct dimensions
function Bitmap.decode_from_string_drawbuffer(str)
	local header = Bitmap.decode_header(str)
	local db = ldb.new_drawbuffer(header.width, header.height)

	Bitmap.decode_from_string_pixel_callback(str, function(x,y,r,g,b,a)
		db:set_px(x,y,r,g,b,a or 255)
	end)

	return db, header
end


-- decode from a file into a new drawbuffer
function Bitmap.decode_from_file_drawbuffer(filepath)
	local file = assert(io.open(filepath, "rb"))
	local str = file:read("*a")
	file:close()
	return Bitmap.decode_from_string_drawbuffer(str)
end


-- encode a new bitmap based on data from the pixel_callback for each pixel specified by width*height
-- TODO: Add 32bpp rgba bitmap encoding support
function Bitmap.encode_from_pixel_callback(width, height, pixel_callback)
	local header = Bitmap.generate_header(width, height)
	local bitmap_data = {}
	for y=0, height-1 do
		for x=0, width-1 do
			local r,g,b = pixel_callback(x,y)
			table.insert(bitmap_data, uint8(r,g,b))
		end
	end

	local bitmap = header .. table.concat(bitmap_data)
	return bitmap
end


-- encode a drawbuffer as bitmap
function Bitmap.encode_from_drawbuffer(db)
	local width = db:width()
	local height = db:height()

	local bitmap = Bitmap.encode_from_pixel_callback(width, height, function(x,y)
		local r,g,b = db:get_pixel(x,y)
		return r,g,b
	end)

	return bitmap
end


return Bitmap
