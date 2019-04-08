#!/usr/bin/env luajit
local ldb = require("ldb")
local blocks = require("blocks")
local term = require("term")
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


local lines = blocks.draw_db(db, nil, true)
for i, line in ipairs(lines) do
	print(line .. term.reset_color())
end
