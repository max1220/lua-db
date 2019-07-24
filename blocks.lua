local term = require("lua-db.term")



local Blocks = {}
-- simple module for color bitmap output on the terminal using space characters


-- draw using a space character with colored background for each pixel returned by pixel_callback
function Blocks.draw_pixel_callback(width, height, pixel_callback, bpp24)
	local lines = {}
	for y=0, height-1 do
		local cline = {}
		for x=0, width-1 do
			local r,g,b,_char = pixel_callback(x,y)
			local char = "\027[0m "
			if _char then
				char = _char
			elseif r and g and b and bpp24 then
				char = term.rgb_to_ansi_color_bg_24bpp(r,g,b) .. " "
			elseif r and g and b then
				char = term.rgb_to_ansi_color_bg_216(r,g,b) .. " "
			end
			cline[x+1] = char
		end
		lines[y+1] = table.concat(cline)
	end
	return lines
end


-- utillity function to draw from a drawbuffer(calls draw_pixel_callback)
function Blocks.draw_db(db, bpp24)

	-- only return r,g,b if a>0, so the for a=0 the default terminal background is used
	local function pixel_callback(x, y)
		local r,g,b,a = db:get_pixel(x,y)
		if a > 0 then
			local char = " "
			if ((r+g+b)/3) > 192 then
				char = "#"
			elseif ((r+g+b)/3) > 96 then
				char = "*"
			end
			if bpp24 then
				return term.rgb_to_ansi_color_bg_24bpp(r,g,b) .. char
			else
				return term.rgb_to_ansi_color_bg_216(r,g,b) .. char
			end
		end
	end

	-- draw using the pixel-callback
	local width = db:width()
	local height = db:height()
	return Blocks.draw_pixel_callback(width, height, pixel_callback, bpp24)

end



return Blocks
