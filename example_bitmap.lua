#!/usr/bin/env luajit
local ldb = require("lua-db")
local bitmap = ldb.bitmap

local draw_db
local bpp24 = false
if arg[2] == "braile" then
	draw_db = ldb.braile.draw_db_precise
elseif arg[2] == "braile24bpp" then
	draw_db = ldb.braile.draw_db_precise
	bpp24 = true
elseif arg[2] == "blocks" then
	draw_db = ldb.blocks.draw_db
elseif arg[2] == "blocks24bpp" then
	draw_db = ldb.blocks.draw_db
	ldb.blocks.get_color_code_bg = ldb.term.rgb_to_ansi_color_bg_24bpp
else
	error("Argument 2 should be one of: braile, braile24bpp, blocks, blocks24bpp")
end


-- open file, decode headers
local f = assert(io.open(arg[1]), "Argument 1 must be a file")
local str = f:read("*a")
local header = bitmap.decode_header(str)
f:close()


-- output header info
print("Bitmap header info:")
for k,v in pairs(header) do
	print("", k,v)
end


-- create new drawing surface
local db = ldb.new(header.width, header.height)


-- copy bitmap to db
bitmap.decode_from_string_pixel_callback(str, function(x,y,r,g,b)
	db:set_pixel(x,y, r,g,b, 255)
end)


-- draw the graphics in a box using +, -, | characters
local lines = draw_db(db, 50, true)
local divider = "+" .. ("-"):rep(header.width/2) .. "+"
print(divider)
for _,line in ipairs(lines) do
	print("\027[0m|" .. line .. "\027[0m|")
end
print(divider)
