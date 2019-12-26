#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")



-- this function draws the clock face on a drawbuffer
local function draw_clock(db, w,h, ox, oy, hour, min, sec, scale,r,g,b)
	local hw = (w/2)
	local hh = (h/2)
	local _rh = (scale and hh) or hw
	local r = r or 255
	local g = g or 255
	local b = b or 255

	-- draw circle
	local step = 0.05
	for i=0,math.pi*2,step do
		local face_x1 = math.sin(i)*hw+hw
		local face_y1 = -math.cos(i)*_rh+hh
		local face_x2 = math.sin(i+step)*hw+hw
		local face_y2 = -math.cos(i+step)*_rh+hh
		--db:set_line_anti_aliased(face_x1+ox, face_y1+oy, face_x2+ox, face_y2+oy, r,g,b,0.1)
		db:set_line(face_x1+ox, face_y1+oy, face_x2+ox, face_y2+oy, r,g,b,255)
	end

	-- draw hour marks
	for i=0,math.pi*2,math.pi/6 do
		local tick_x1 = math.sin(i)*hw*0.8+hw
		local tick_y1 = -math.cos(i)*_rh*0.8+hh
		local tick_x2 = math.sin(i)*hw*0.9+hw
		local tick_y2 = -math.cos(i)*_rh*0.9+hh
		db:set_line_anti_aliased(tick_x1+ox,tick_y1+oy,tick_x2+ox,tick_y2+oy, r,g,b,1.2)
	end

	-- draw hour line
	if hour then
		local a = ((hour % 12) / 12) * 2 * math.pi
		local hour_x = math.sin(a)*hw*0.95+hw
		local hour_y = -math.cos(a)*_rh*0.95+hh
		db:set_line_anti_aliased(hour_x+ox,hour_y+oy,hw+ox,hh+oy, r,g,b,1.3)
	end

	-- draw minute line
	if min then
		local a = (min / 60) * 2 * math.pi
		local min_x = math.sin(a)*hw*0.90+hw
		local min_y = -math.cos(a)*_rh*0.90+hh
		db:set_line_anti_aliased(min_x+ox,min_y+oy,hw+ox,hh+oy, r,g,b,1)
	end

	-- draw second line
	if sec then
		local a = (sec / 60) * 2 * math.pi
		local sec_x = math.sin(a)*hw*0.90+hw
		local sec_y = -math.cos(a)*_rh*0.90+hh
		--db:set_line_anti_aliased(sec_x+ox,sec_y+oy,hw+ox,hh+oy, r,g,b,0.2)
		db:set_line(sec_x+ox,sec_y+oy,hw+ox,hh+oy, r,g,b,255)
	end

end


return {
	draw_clock = draw_clock
}
