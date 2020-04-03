#!/usr/bin/env luajit
--[[
this Lua moudle draws a clock face on a drawbuffer.
]]

local function draw_clock(db, w,h, ox, oy, _hour, _min, _sec,_r,_g,_b)
	local hw = (w/2)
	local hh = (h/2)
	local _rh = ((w>h) and hh) or hw
	local r = _r or 255
	local g = _g or 255
	local b = _b or 255
	local hour,min,sec = _hour,_min,_sec

	-- if no hand is specified, draw the current time
	if (not _hour) and (not _min) and (not _sec) then
		local t = os.date("*t")
		hour, min, sec = t.hour, t.min, t.sec
	end

	-- draw circle
	local step = 0.1
	for i=0,math.pi*2,step do
		local face_x1 = math.sin(i)*hw+hw
		local face_y1 = -math.cos(i)*_rh+hh
		local face_x2 = math.sin(i+step)*hw+hw
		local face_y2 = -math.cos(i+step)*_rh+hh
		db:line(face_x1+ox, face_y1+oy, face_x2+ox, face_y2+oy, r,g,b,255)
	end

	-- draw hour marks
	for i=0,math.pi*2,math.pi/6 do
		local tick_x1 = math.sin(i)*hw*0.8+hw
		local tick_y1 = -math.cos(i)*_rh*0.8+hh
		local tick_x2 = math.sin(i)*hw*0.9+hw
		local tick_y2 = -math.cos(i)*_rh*0.9+hh
		db:line(tick_x1+ox,tick_y1+oy,tick_x2+ox,tick_y2+oy, r,g,b,255, 2)
	end

	-- draw hour line
	if hour then
		local a = ((hour % 12) / 12) * 2 * math.pi
		local hour_x = math.sin(a)*hw*0.95+hw
		local hour_y = -math.cos(a)*_rh*0.95+hh
		db:line(hour_x+ox,hour_y+oy,hw+ox,hh+oy, r,g,b,255, 2)
	end

	-- draw minute line
	if min then
		local a = (min / 60) * 2 * math.pi
		local min_x = math.sin(a)*hw*0.90+hw
		local min_y = -math.cos(a)*_rh*0.90+hh
		db:line(min_x+ox,min_y+oy,hw+ox,hh+oy, r,g,b,255, 1)
	end

	-- draw second line
	if sec then
		local a = (sec / 60) * 2 * math.pi
		local sec_x = math.sin(a)*hw*0.90+hw
		local sec_y = -math.cos(a)*_rh*0.90+hh
		db:line(sec_x+ox,sec_y+oy,hw+ox,hh+oy, r,g,b,255, 0.5)
	end

end


return {
	draw_clock = draw_clock
}
