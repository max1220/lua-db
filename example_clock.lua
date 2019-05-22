#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")



-- this function draws the clock face on a drawbuffer
local function draw_clock(db, w,h, ox, oy, hour, min, sec)
	local hw = (w/2)
	local hh = (h/2)
	
	-- draw circle
	for i=0,math.pi*2,0.01 do
		local face_x = math.sin(i)*hw+hw
		local face_y = -math.cos(i)*hw+hh
		db:set_pixel(face_x+ox, face_y+oy, 255,255,255,255)
	end
	
	-- draw hour marks
	for i=0,math.pi*2,math.pi/6 do
		local tick_x1 = math.sin(i)*hw*0.8+hw
		local tick_y1 = -math.cos(i)*hw*0.8+hh
		local tick_x2 = math.sin(i)*hw*0.9+hw
		local tick_y2 = -math.cos(i)*hw*0.9+hh
		db:set_line_anti_aliased(tick_x1+ox,tick_y1+oy,tick_x2+ox,tick_y2+oy,255,255,255,0.5)
	end
	
	-- draw hour line
	if hour then
		local a = ((hour % 12) / 12) * 2 * math.pi
		local hour_x = math.sin(a)*hw*0.95+hw
		local hour_y = -math.cos(a)*hw*0.95+hh
		db:set_line_anti_aliased(hour_x+ox,hour_y+oy,hw+ox,hh+oy,255,255,255,1.3)
	end
	
	-- draw minute line
	if min then
		local a = (min / 60) * 2 * math.pi
		local min_x = math.sin(a)*hw*0.90+hw
		local min_y = -math.cos(a)*hw*0.90+hh
		db:set_line_anti_aliased(min_x+ox,min_y+oy,hw+ox,hh+oy,255,255,255,1)
	end
	
	-- draw second line
	if sec then
		local a = (sec / 60) * 2 * math.pi
		local sec_x = math.sin(a)*hw*0.90+hw
		local sec_y = -math.cos(a)*hw*0.90+hh
		db:set_line_anti_aliased(sec_x+ox,sec_y+oy,hw+ox,hh+oy,255,255,255,0.2)
	end
	
end



if arg then
	-- called interactivly, draw a clock and output as braile characters
	local w = tonumber(arg[1]) or 100
	local h = tonumber(arg[2]) or 100
	local db = ldb.new(w,h)
	db:clear(0,0,0,0)
	local t = os.date("*t")
	draw_clock(db, w,h, 0,0, t.hour, t.min, t.sec)
	local lines = ldb.braile.draw_db_precise(db, 0, true)
	io.write(table.concat(lines, ldb.term.reset_color().."\n"), ldb.term.reset_color(), "\n")

else
	-- called via require(), return module
	return {
		draw_clock = draw_clock
	}

end
