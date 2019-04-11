#!/usr/bin/env luajit
local ldb = require("lua-db")
local braile = ldb.braile
local blocks = ldb.blocks
local Font = ldb.font
local bitmap = ldb.bitmap

-- parse arguments
local font_file = assert(io.open(arg[1], "rb"))
local char_w = assert(tonumber(arg[2]))
local char_h = assert(tonumber(arg[3]))
local out_file = io.open(arg[4] or "", "wb")
local text = io.stdin:read("*a")

-- load font header & image from file
local font_str = font_file:read("*a")
local font_db = bitmap.decode_from_string_drawbuffer(font_str)
font_file:close()
local font_header = bitmap.decode_header(font_str)

-- create font
local font = Font.from_drawbuffer(font_db, char_w, char_h)



-- get the site the rendered font will be
local width,height = font:string_size(text)

-- create drawbuffer for output
local target = ldb.new(width, height)
target:clear(0,0,0,255)

-- render a string into the target drawbuffer
font:draw_string(target, text, 0, 0)

-- output
print("dumping pixels...")
local lines = braile.draw_db(target)
for i, line in ipairs(lines) do
	print(line .. "\027[0m")
end


-- output using bitmap
if out_file then
	local bitmap_str = bitmap.encode_from_pixel_callback(target:width(), target:height(), function(x,y)
		local r,g,b = target:get_pixel(x,y)
		return r,g,b
	end)
	out_file:write(bitmap_str)
	out_file:close()
end
