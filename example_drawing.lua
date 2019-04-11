#!/usr/bin/env luajit
local ldb = require("lua-db")


local draw_db
local bpp24 = false
if arg[1] == "braile" then
	draw_db = ldb.braile.draw_db_precise
elseif arg[1] == "braile24bpp" then
	draw_db = ldb.braile.draw_db_precise
	bpp24 = true
elseif arg[1] == "blocks" then
	draw_db = ldb.blocks.draw_db
elseif arg[1] == "blocks24bpp" then
	draw_db = ldb.blocks.draw_db
	ldb.blocks.get_color_code_bg = ldb.term.rgb_to_ansi_color_bg_24bpp
else
	error("Argument 1 should be one of: braile, braile24bpp, blocks, blocks24bpp")
end





local w = tonumber(arg[1]) or 50
local h = tonumber(arg[2]) or 50
local db = ldb.new(w,h)
db:clear(0,0,0,255)
for x=0, 10 do
	db:set_pixel(x,30, x+10,x*12,x*24,255)
end

db:set_rectangle(30,10,10,10,127,127,127,255)
db:set_line(0,0,w-1,h-1,255,255,255,255)
db:set_box(45,10,10,10,255,255,255,255)
db:set_box(0,0,w,h,255,255,255,255)


local lines = draw_db(db, 50, true)
for i, line in ipairs(lines) do
	print(line .. ldb.term.reset_color())
end
