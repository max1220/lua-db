local term = require("lua-db.term")



local Halfblocks = {}
-- simple module for color bitmap output on the terminal using space characters


-- draw using a space character with colored background for each pixel returned by pixel_callback
function Halfblocks.draw_pixel_callback(width, height, pixel_callback, bpp24, no_colors, threshold)
	local lines = {}
	local fb_utf8 = string.char(0xE2,0x96,0x88)
	local hb_utf8 = string.char(0xE2,0x96,0x80)
	local hb_lower_utf8 = string.char(0xE2,0x96,0x84)
	local threshold = tonumber(threshold) or 1

	local get_fg = term.rgb_to_ansi_color_fg_216
	local get_bg = term.rgb_to_ansi_color_bg_216
	if bpp24 then
		get_fg = term.rgb_to_ansi_color_fg_24bpp
		get_bg = term.rgb_to_ansi_color_bg_24bpp
	end
	if no_colors then
		get_fg = function() return "" end
		get_bg = function() return "" end
	end

	for y=0, (height/2)-1 do
		local cline = {}
		for x=0, width-1 do
			local r_0,g_0,b_0 = pixel_callback(x,y*2)
			local r_1,g_1,b_1 = pixel_callback(x,y*2+1)
			local fg = get_fg(r_0 or 0, g_0 or 0, b_0 or 0)
			local bg = get_bg(r_1 or 0, g_1 or 0, b_1 or 0)
			local char
			if fg == bg then
				char = bg .. " "
			else
				char = fg .. bg .. hb_utf8
			end
			if no_colors then
				local up,down = false,false
				if (r_0+g_0+b_0>threshold*3) then
					up = true
				end
				if (r_1+g_1+b_1>threshold*3) then
					down = true
				end
				if up and down then
					char = fb_utf8
				elseif up then
					char = hb_utf8
				elseif down then
					char = hb_lower_utf8
				else
					char = " "
				end
			end
			cline[x+1] = char
		end
		lines[y+1] = table.concat(cline)
	end
	return lines
end


-- utillity function to draw from a drawbuffer(calls draw_pixel_callback)
function Halfblocks.draw_db(db, bpp24)

	-- only return r,g,b if a>0, so the for a=0 the default terminal background is used
	local function pixel_callback(x, y)
		local r,g,b,a = db:get_pixel(x,y)
		if (a > 0) then
			return r,g,b
		end
	end

	-- draw using the pixel-callback
	local width = db:width()
	local height = db:height()
	return Halfblocks.draw_pixel_callback(width, height, pixel_callback, bpp24)
end



return Halfblocks
