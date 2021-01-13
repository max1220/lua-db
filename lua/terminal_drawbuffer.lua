--[[

This file contains functions for outputting drawbuffers to a terminal.
It supports multiple ways of outputting graphics to the terminal:
 * regular characters, approximating brightness of pixel("ASCII art").
 * space characters, with a ANSI escape code to set to appropriate background color.
 * unicode braile characters(2x4 "dots" per pixel)
 * various unicode block characters
  * 2x3 sextants
  * 2x2 quadrants
  * 2x1 vertical halfblocks
  * 1x2 horizontal halfblocks

It's generic enough to be useful seperatly from the terminal module(it does not
require it), but keep in mind that these functions might be copied into a
terminal table. (So some optional functions like self.bg_color are implemented
in terminal automatically, but need to be specified in arguments when used
standalone)
]]


local unicode_to_utf8 = require("lua-db.unicode_to_utf8")

local function rgb_to_grey(r,g,b)
	if r and g and b then
		return math.min((0.3*r)+(0.59*g)+(0.11*b), 1)
	else
		return 0
	end
end

local function rgb_to_bool(r,g,b)
	if r and g and b then
		return ((0.3*r)+(0.59*g)+(0.11*b))>0.5
	else
		return false
	end
end


local terminal_drawbuffer = {}





-- function to convert a drawbuffer to line data for rendering to a terminal
-- using the color codes for the background, and a single character per pixel.
function terminal_drawbuffer:drawbuffer_colors(db, lines_buf, _bg_color)
	local w,h = db:width(), db:height()
	local last_color_code
	local bg_color = assert(_bg_color or self.bg_color)
	lines_buf = lines_buf or {}
	for y=1, h do
		local cline = lines_buf[y] or {}
		lines_buf[y] = cline
		for x=1, w do
			local r,g,b = db:get_px(x-1,y-1)
			local color_code = bg_color(self, r,g,b)
			if (color_code~=last_color_code) then
				last_color_code = color_code
				cline[x] = color_code.." "
			else
				cline[x] = " "
			end
		end
		cline[w+1] = nil
	end
	lines_buf[h+1] = nil
	return lines_buf
end


-- function to convert a drawbuffer to line data for rendering to a terminal,
-- using only ASCII characters(one per pixel)
function terminal_drawbuffer:drawbuffer_characters(db, lines_buf, characters, _rgb_to_grey)
	local w,h = db:width(), db:height()
	_rgb_to_grey = _rgb_to_grey or rgb_to_grey
	characters = characters or {" ",".","+","#"}
	lines_buf = lines_buf or {}
	for y=1, h do
		local cline = lines_buf[y] or {}
		lines_buf[y] = cline
		for x=1, w do
			local grey = _rgb_to_grey(db:get_px(x-1,y-1))
			local char = characters[grey*(#characters-1)+1]
			cline[x] = char or "?"
		end
		cline[w+1] = nil
	end
	lines_buf[h+1] = nil
	return lines_buf
end

-- function to convert a drawbuffer to line data for rendering to a terminal,
-- converting each windows of win_w, win_h pixels into a single character,
-- based on a boolean decission tree, the chars table.
-- It is with the pixel values converted to boolean from top-left, right then down.
function terminal_drawbuffer:drawbuffer_combine_bool(db, chars, win_w, win_h, lines_buf, _rgb_to_bool)
	local w,h = db:width(), db:height()
	_rgb_to_bool = _rgb_to_bool or rgb_to_bool
	lines_buf = lines_buf or {}

	local lines_buf_i = 1
	for y=0, math.ceil((h/win_h)-1) do
		local cline = lines_buf[y+1] or {}
		local cline_i = 1
		for x=0, math.ceil((w/win_w)-1) do
			local cindex = chars
			for win_y=0, win_h-1 do
				for win_x=0, win_w-1 do
					local set = _rgb_to_bool(db:get_px(x*win_w+win_x,y*win_h+win_y))
					cindex = cindex[set]
				end
			end
			cline[cline_i] = cindex
			cline_i = cline_i + 1
		end
		cline[cline_i+1] = nil
		lines_buf[lines_buf_i] = cline
		lines_buf_i = lines_buf_i + 1
	end
	lines_buf[lines_buf_i+1] = nil
	return lines_buf
end

-- index the table using vararg, set to value val
local function set(tbl, val, ...)
	local ct = tbl
	local indexes = {...}
	for i=1, #indexes-1 do
		local j = indexes[i]
		ct[j] = ct[j] or {}
		ct = ct[j]
	end
	ct[indexes[#indexes]] = val
end
-- TODO: This is sort of ugly...
local function get_braile_chars()
	local braile_chars = {}
	for b8=0,1 do for b7=0,1 do	for b6=0,1 do for b5=0,1 do
	for b4=0,1 do for b3=0,1 do	for b2=0,1 do for b1=0,1 do
		local unicode = 0x2800+b1+b2*8+b3*2+b4*16+b5*4+b6*32+b7*64+b8*128
		local utf8 = unicode_to_utf8(unicode)
		set(braile_chars, utf8, b1==1,b2==1,b3==1,b4==1,b5==1,b6==1,b7==1,b8==1)
	end end end end
	end end end end
	return braile_chars
end
terminal_drawbuffer.braile_chars = get_braile_chars()
function terminal_drawbuffer:drawbuffer_braile(db, lines_buf, _rgb_to_bool)
	return self:drawbuffer_combine_bool(db, self.braile_chars, 2,4, lines_buf, _rgb_to_bool)
end

local function get_sextant_chars()
	local sextant_chars = {}
	for b6=0,1 do for b5=0,1 do
	for b4=0,1 do for b3=0,1 do	for b2=0,1 do for b1=0,1 do
		local unicode = 0x1FB00+b1+b2*2+b3*4+b4*8+b5*16+b6*32-1
		if unicode>0x1fb13 then
			unicode = unicode - 1
		end
		if unicode>0x1fb26 then
			unicode = unicode - 1
		end
		local utf8 = unicode_to_utf8(unicode)
		set(sextant_chars, utf8, b1==1,b2==1,b3==1,b4==1,b5==1,b6==1)
	end end end end
	end end
	set(sextant_chars, " ", false,false,false,false,false,false)
	set(sextant_chars, "▌", true,false,true,false,true,false)
	set(sextant_chars, "▐", false,true,false,true,false,true)
	set(sextant_chars, "█", true,true,true,true,true,true)
	return sextant_chars
end
terminal_drawbuffer.sextant_chars = get_sextant_chars()
function terminal_drawbuffer:drawbuffer_sextant(db, lines_buf, _rgb_to_bool)
	return self:drawbuffer_combine_bool(db, self.sextant_chars, 2,3, lines_buf, _rgb_to_bool)
end

terminal_drawbuffer.quadrants_chars = {
	[true] = {
		[true] = {
			[true] = {
				[true] = "█",
				[false] = "▛",
			},
			[false] = {
				[true] = "▜",
				[false] = "▀",
			},
		},
		[false] = {
			[true] = {
				[true] = "▙",
				[false] = "▌",
			},
			[false] = {
				[true] = "▚",
				[false] = "▘",
			},
		},
	},
	[false] = {
		[true] = {
			[true] = {
				[true] = "▟",
				[false] = "▞",
			},
			[false] = {
				[true] = "▐",
				[false] = "▝",
			}
		},
		[false] = {
			[true] = {
				[true] = "▄",
				[false] = "▖",
			},
			[false] = {
				[true] = "▗",
				[false] = " ",
			}
		},
	},
}
function terminal_drawbuffer:drawbuffer_quadrants(db, lines_buf, _rgb_to_bool)
	return self:drawbuffer_combine_bool(db, self.quadrants_chars, 2,2, lines_buf, _rgb_to_bool)
end

terminal_drawbuffer.vhalf_chars = {
	[true] = {
		 [true] = "█",
		 [false] = "▀",
	},
	[false] = {
		 [true] = "▄",
		 [false] = " ",
	},
}
function terminal_drawbuffer:drawbuffer_vhalf(db, lines_buf, _rgb_to_bool)
	return self:drawbuffer_combine_bool(db, self.vhalf_chars, 1, 2, lines_buf, _rgb_to_bool)
end

terminal_drawbuffer.hhalf_chars = {
	[true] = {
		 [true] = "█",
		 [false] = "▌",
	},
	[false] = {
		 [true] = "▐",
		 [false] = " ",
	},
}
function terminal_drawbuffer:drawbuffer_hhalf(db, lines_buf, _rgb_to_bool)
	return self:drawbuffer_combine_bool(db, self.hhalf_chars, 2, 1, lines_buf, _rgb_to_bool)
end


return terminal_drawbuffer
