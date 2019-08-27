local term = require("lua-db.term")



local Halfblocks = {}
-- simple module for color bitmap output on the terminal using space characters


-- draw using a space character with colored background for each pixel returned by pixel_callback
function Halfblocks.draw_pixel_callback(width, height, pixel_callback, bpp24)
	local lines = {}
	local hb_utf8 = string.char(0xE2,0x96,0x80)

	local get_fg = term.rgb_to_ansi_color_fg_216
	local get_bg = term.rgb_to_ansi_color_bg_216
	if bpp24 then
		get_fg = term.rgb_to_ansi_color_fg_24bpp
		get_bg = term.rgb_to_ansi_color_bg_24bpp
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
		if a > 0 then
			return r,g,b
		end
	end

	-- draw using the pixel-callback
	local width = db:width()
	local height = db:height()
	return Halfblocks.draw_pixel_callback(width, height, pixel_callback, bpp24)
end



return Halfblocks
