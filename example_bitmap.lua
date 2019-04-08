#!/usr/bin/env luajit
local ldb = require("ldb")
local bitmap = require("bitmap2")

local draw_db
if arg[2] == "braile" then
	local braile = require("braile")
	draw_db = braile.draw_db()
elseif arg[2] == "braile24bpp" then
	local braile = require("braile")
	braile.get_color_code_fg = braile.get_color_code_fg_24bit
	braile.get_color_code_bg = braile.get_color_code_bg_24bit
	draw_db = braile.draw_db()
elseif arg[3] == "blocks" then
	local blocks = require("blocks")
	draw_db = blocks.draw_db()
elseif arg[4] == "blocks24bpp" then
	local blocks = require("blocks")
	blocks.get_color_code_fg = blocks.get_color_code_fg_24bit
	blocks.get_color_code_bg = blocks.get_color_code_bg_24bit
	draw_db = blocks.draw_db()
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
