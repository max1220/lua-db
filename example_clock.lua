#!/usr/bin/env luajit
-- draw a clock and output as braile characters
local ldb = require("lua-db")
local clock = require("clock")

local w = tonumber(arg[1]) or 100
local h = tonumber(arg[2]) or 100
local blocks = arg[3] == "blocks"
local db = ldb.new(w,h)
db:clear(0,0,0,0)

-- draw clock to drawbuffer
local t = os.date("*t")
clock.draw_clock(db, w,h, 0,0, t.hour, t.min, t.sec, true, 255,0,0)

-- output
local lines
if blocks then
	lines = ldb.blocks.draw_db(db, true)
else
	lines = ldb.braile.draw_db_precise(db, 0, true)
end
io.write(table.concat(lines, ldb.term.reset_color().."\n"), ldb.term.reset_color(), "\n")
