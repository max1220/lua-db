--[[

This file contains functions for outputting drawbuffers to a terminal.
It returns one function, append(term), that is called in terminal.new_terminal
with the new terminal table. When this function is called, it appends the
functionallty in that table.

]]


local function rgb_to_grey(r,g,b)
	-- return (r+g+b)/3
	return (0.3*r)+(0.59*g)+(0.11*b)
end

local function rgb_to_bool(r,g,b)
	return ((0.3*r)+(0.59*g)+(0.11*b))>0.5
end

local function unicode_to_utf8(c)
	assert((55296 > c or c > 57343) and c < 1114112, "Bad Unicode code point: "..tostring(c)..".")
	if c < 128 then
		return string.char(c)
	elseif c < 2048 then
		return string.char(192 + c/64, 128 + c%64)
	elseif c < 55296 or 57343 < c and c < 65536 then
		return string.char(224 + c/4096, 128 + c/64%64, 128 + c%64)
	elseif c < 1114112 then
		return string.char(240 + c/262144, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
	end
end

-- prefer the native UTF8 facillity in Lua 5.3
if utf8 then
	unicode_to_utf8 = utf8.char
elseif pcall(require, "utf8") then -- also allow compatible external UTF-8 module
	unicode_to_utf8 = require("utf8").char or unicode_to_utf8
	assert(unicode_to_utf8(0x2588)=="█")
end



local function append(term)
	-- function to convert a drawbuffer to line data for rendering to a terminal
	-- using the color codes for the background, and a single character per pixel.
	function term:drawbuffer_colors(db, lines_buf)
		local w,h = db:width(), db:height()
		local last_color_code
		lines_buf = lines_buf or {}
		for y=1, h do
			local cline = lines_buf[y] or {}
			lines_buf[y] = cline
			for x=1, w do
				local r,g,b = db:get_pixel(x-1,y-1)
				local color_code = self:bg_color(r,g,b)
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
	function term:drawbuffer_characters(db, characters, lines_buf, _rgb_to_grey)
		local w,h = db:width(), db:height()
		_rgb_to_grey = _rgb_to_grey or rgb_to_grey
		characters = characters or {" ",".","+","#"}
		lines_buf = lines_buf or {}
		for y=1, h do
			local cline = lines_buf[y] or {}
			lines_buf[y] = cline
			for x=1, w do
				local grey = _rgb_to_grey(db:get_px(x-1,y-1))
				local char = characters[math.floor(grey*(#characters-1)+1.5)]
				cline[x] = char
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
	function term:drawbuffer_combine_bool(db, chars, win_w, win_h, lines_buf, _rgb_to_bool)
		local w,h = db:width(), db:height()
		_rgb_to_bool = _rgb_to_bool or rgb_to_bool
		lines_buf = lines_buf or {}

		for y=0, (h/win_h)-1 do
			local cline = lines_buf[y] or {}
			lines_buf[y] = cline
			for x=0, (w/win_w)-1 do
				local cindex = chars
				for win_y=0, win_h-1 do
					for win_x=0, win_w-1 do
						local set = _rgb_to_bool(db:get_px(x*win_w+win_x,y*win_h+win_y))
						cindex = cindex[set]
					end
				end
				cline[x] = cindex
			end
			cline[math.floor(w/2)+1] = nil
		end
		lines_buf[math.floor(h/2)+1] = nil
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
	term.braile_chars = get_braile_chars()
	function term:drawbuffer_braile(db, lines_buf, _rgb_to_bool)
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
	term.sextant_chars = get_sextant_chars()
	function term:drawbuffer_sextant(db, lines_buf, _rgb_to_bool)
		return self:drawbuffer_combine_bool(db, self.sextant_chars, 2,3, lines_buf, _rgb_to_bool)
	end

	term.quadrants_chars = {
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
	function term:drawbuffer_quadrants(db, lines_buf, _rgb_to_bool)
		return self:drawbuffer_combine_bool(db, self.quadrants_chars, 2,2, lines_buf, _rgb_to_bool)
	end

	term.vhalf_chars = {
		[true] = {
			 [true] = "█",
			 [false] = "▀",
		},
		[false] = {
			 [true] = "▄",
			 [false] = " ",
		},
	}
	function term:drawbuffer_vhalf(db, lines_buf, _rgb_to_bool)
		return self:drawbuffer_combine_bool(db, self.vhalf_chars, 1, 2, lines_buf, _rgb_to_bool)
	end

	term.hhalf_chars = {
		[true] = {
			 [true] = "█",
			 [false] = "▌",
		},
		[false] = {
			 [true] = "▐",
			 [false] = " ",
		},
	}
	function term:drawbuffer_hhalf(db, lines_buf, _rgb_to_bool)
		return self:drawbuffer_combine_bool(db, self.hhalf_chars, 2, 1, lines_buf, _rgb_to_bool)
	end

	-- recolor a previously uncolored set of lines.
	function term:drawbuffer_recolor(db, lines, win_w, win_h)
		for y=0,db:height()/win_h do

		end
	end
end

return append
