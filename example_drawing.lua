#!/usr/bin/env luajit
local ldb = require("lua-db")

local w = tonumber(arg[1]) or 100
local h = tonumber(arg[2]) or 100
local db = ldb.new(w,h)

db:clear(0,0,0,0)

db:set_rectangle(30,10,10,10,255,255,255,255)
db:set_rectangle(30,30,10,10,255,0,0,255)
db:set_rectangle(30,50,10,10,0,255,0,255)
db:set_rectangle(30,70,10,10,0,0,255,255)
db:set_rectangle(50,10,10,10,127,127,127,255)


db:set_box(70,10,10,10,255,255,255,255)
db:set_box(0,0,w,h,255,255,255,255)
db:set_line(0,0,w-1,h-1,255,255,255,255)

db:set_line_anti_aliased(0,0,w-1,h/2,255,255,255,2)


local lines = ldb.braile.draw_db_precise(db, 1, false)
print(ldb.term.set_cursor(0,0))
for i, line in ipairs(lines) do
	print(line .. ldb.term.reset_color())
end
