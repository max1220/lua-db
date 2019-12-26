local term = require("lua-db.term")


-- Draw on the terminal using braile characters
local Braile = {}




local unicode_to_utf8
local ok, utf8 = pcall(require, "utf8")
if ok then
	-- We have a module for UTF8 support, either Lua5.3 or external
	unicode_to_utf8 = utf8.char
else
	-- No module, so convert a unicode codepoint to utf8 character sequence "manually"
	unicode_to_utf8 = function(c)
		-- from https://gist.github.com/pygy/7154512
		assert((55296 > c or c > 57343) and c < 1114112, "Bad Unicode code point: "..c..".")
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
end


-- convert the set bits to a utf8 character sequence
function Braile.get_chars(bits)
	-- braile characters start at unicode 0x2800
	return unicode_to_utf8(bits + 0x2800)
end


-- draw using a pixel callback (and optional color_callback)
-- the pixel callback is called for every pixel(8x per character), takes an x,y coordinate, and should return 1 if the pixel is set, 0 otherwise
-- the color callback is called for every character, takes an x,y coordinate, and should return an ANSI escape sequence to set the foreground/background color
function Braile.draw_pixel_callback(width, height, pixel_callback, color_callback)
	local chars_x = math.ceil(width/2)
	local chars_y = math.ceil(height/4)

	-- iterate over every character that should be generated
	local lines = {}
	for y=0, chars_y do
		local cline = {}
		for x=0, chars_x do
			local rx = x*2
			local ry = y*4
			local char_num = 0

			-- left 3
			char_num = char_num + pixel_callback(rx+0, ry+0)
			char_num = char_num + pixel_callback(rx+0, ry+1)*2
			char_num = char_num + pixel_callback(rx+0, ry+2)*4

			--right 3
			char_num = char_num + pixel_callback(rx+1, ry+0)*8
			char_num = char_num + pixel_callback(rx+1, ry+1)*16
			char_num = char_num + pixel_callback(rx+1, ry+2)*32

			--bottom 2
			char_num = char_num + pixel_callback(rx+0, ry+3)*64
			char_num = char_num + pixel_callback(rx+1, ry+3)*128

			if color_callback then
				local color_code = color_callback(rx, ry, char_num)
				table.insert(cline, color_code)
			end

			if char_num == 0 then
				--empty char, use space
				table.insert(cline, " ")
			else
				-- generate a utf8 character sequence for the braile code
				local chars = Braile.get_chars(char_num)
				table.insert(cline, chars)
			end
		end
		table.insert(lines, table.concat(cline))
	end
	return lines, chars_x, chars_y
end


-- draw using a lfb/lua-db drawbuffer(uses draw_pixel_callback internaly)
-- uses both foreground and background color. Not be optimal for
-- graphs etc., but usefull for images
function Braile.draw_db(db, threshold, color, bpp24)
	local threshold = tonumber(threshold) or 50

	local color_code_bg = term.rgb_to_ansi_color_bg_216
	local color_code_fg = term.rgb_to_ansi_color_fg_216
	if bpp24 then
		color_code_bg = term.rgb_to_ansi_color_bg_24bpp
		color_code_fg = term.rgb_to_ansi_color_fg_24bpp
	end

	-- get a boolean pixel value from the drawbuffer for the braile chars
	local function pixel_callback(x, y)
		local r,g,b,a = db:get_pixel(x,y)
		if a > 0 then
			local avg = (r+g+b)/3
			if avg > threshold then
				return 1
			end
		end
		return 0
	end

	-- get foreground/background color codes from the drawbuffer
	local function color_callback(x, y, char_num)
		local r,g,b = db:get_pixel(x,y)
		local bg = "\027[0m"
		local fg = ""

		-- todo: replace hardcoded parameters
		if char_num ~= 0 then
			if (r+g+b)/3 > 25 then
				bg =  color_code_bg(r/4,g/4,b/4)
			end
			fg = color_code_fg(r,g,b)
		else
			if (r+g+b)/3 > 25 then
				bg =  color_code_bg(r/3,g/3,b/3)
			end
		end
		return bg .. fg
	end

	local width = db:width()
	local height = db:height()

	if color then
		return Braile.draw_pixel_callback(width, height, pixel_callback, color_callback)
	else
		return Braile.draw_pixel_callback(width, height, pixel_callback)
	end
end


-- function optimized for precision(like in graphs).
-- Only uses the foreground color.
function Braile.draw_db_precise(db, threshold, bpp24)
	local threshold = tonumber(threshold) or 0

	local color_code_fg = term.rgb_to_ansi_color_fg_216
	if bpp24 then
		color_code_fg = term.rgb_to_ansi_color_fg_24bpp
	end

	-- determine if a pixel is represented by a braile dot
	local function pixel_callback(x,y)
		local r,g,b,a = db:get_pixel(x,y)
		if a > 0 then
			if ((r+g+b)/3) < threshold then
				return 0
			end
			return 1
		end
		return 0
	end

	-- determine color of braile dot cluster, starting at x,y(2x4)
	local function color_callback(x,y)
		local avg_r = 0
		local avg_g = 0
		local avg_b = 0
		local i = 0
		for oy=0, 3 do
			for ox=0, 1 do
				local r,g,b,a = db:get_pixel(x+ox,y+oy)
				if a > 0 then
					avg_r = avg_r + r
					avg_g = avg_g + g
					avg_b = avg_b + b
					i = i + 1
				end
			end
		end
		if i > 0 then
			avg_r = avg_r / i
			avg_g = avg_g / i
			avg_b = avg_b / i
			return color_code_fg(avg_r, avg_g, avg_b)
		else
			return color_code_fg(0,0,0)
		end
	end

	local width = db:width()
	local height = db:height()

	return Braile.draw_pixel_callback(width, height, pixel_callback, color_callback)
end



-- draw from a table containing pixel(and color) information
function Braile.draw_table(tbl, bpp24)

	-- get a boolean pixel value from the table for the braile chars
	local function pixel_callback(x, y)
		if tbl[y+1] and tbl[y+1][x+1] then
			local px = unpack(tbl[y+1][x+1])
			return px
		end
		return 0
	end

	local color_code_bg = term.rgb_to_ansi_color_bg_216
	local color_code_fg = term.rgb_to_ansi_color_fg_216
	if bpp24 then
		color_code_bg = term.rgb_to_ansi_color_bg_24bpp
		color_code_fg = term.rgb_to_ansi_color_fg_24bpp
	end

	-- get foreground/background color codes from the drawbuffer
	local function color_callback(x, y)
		local px,r,g,b = unpack(tbl[y+1][x+1])
		if r and g and b then
			local fg_code = color_code_fg(r,g,b)
			local bg_code = color_code_bg(r,g,b)
			return fg_code .. bg_code
		end
		return ""
	end

	local width = tbl.width or #tbl[1]
	local height = tbl.height or #tbl

	return Braile.draw_pixel_callback(width, height, color_callback)
end





return Braile
