#!/usr/bin/env luajit
local ldb = require("lua-db")

local w = tonumber(arg[1]) or 100
local h = tonumber(arg[2]) or 100


local function draw_clock(db, hour, min, sec)
	local hw = (w/2)
	local hh = (h/2)
	
	-- draw circle
	for i=0,math.pi*2,0.01 do
		local face_x = math.sin(i)*hw+hw
		local face_y = -math.cos(i)*hw+hh
		db:set_pixel(face_x, face_y, 255,255,255,255)
	end
	
	-- draw hour marks
	for i=0,math.pi*2,math.pi/6 do
		local tick_x1 = math.sin(i)*hw*0.8+hw
		local tick_y1 = -math.cos(i)*hw*0.8+hh
		local tick_x2 = math.sin(i)*hw*0.9+hw
		local tick_y2 = -math.cos(i)*hw*0.9+hh
		db:set_line_anti_aliased(tick_x1,tick_y1,tick_x2,tick_y2,255,255,255,0.5)
	end
	
	-- draw hour line
	if hour then
		local a = ((hour % 12) / 12) * 2 * math.pi
		local hour_x = math.sin(a)*hw*0.95+hw
		local hour_y = -math.cos(a)*hw*0.95+hh
		db:set_line_anti_aliased(hour_x,hour_y,w/2,h/2,255,255,255,1.5)
	end
	
	-- draw minute line
	if min then
		local a = (min / 60) * 2 * math.pi
		local min_x = math.sin(a)*hw*0.90+hw
		local min_y = -math.cos(a)*hw*0.90+hh
		db:set_line_anti_aliased(min_x,min_y,w/2,h/2,255,255,255,1)
	end
	
	-- draw second line
	if sec then
		local a = (sec / 60) * 2 * math.pi
		local sec_x = math.sin(a)*hw*0.90+hw
		local sec_y = -math.cos(a)*hw*0.90+hh
		db:set_line_anti_aliased(sec_x,sec_y,w/2,h/2,255,255,255,0.7)
	end
	
end


local db = ldb.new(w,h)
db:clear(0,0,0,0)

local t = os.date("*t")

draw_clock(db, t.hour, t.min, t.sec)

local lines = ldb.braile.draw_db_precise(db, 0, true)
io.write(table.concat(lines, ldb.term.reset_color().."\n"), ldb.term.reset_color(), "\n")

