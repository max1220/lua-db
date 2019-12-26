local term = require("lua-db.term")



local Blocks = {}
-- simple module for color bitmap output on the terminal using space characters


-- draw using a space character with colored background for each pixel returned by pixel_callback
function Blocks.draw_pixel_callback(width, height, pixel_callback, bpp24)
	local lines = {}
	local rgb_to_escape = term.rgb_to_ansi_color_bg_216
	if bpp24 then
		rgb_to_escape = term.rgb_to_ansi_color_bg_24bpp
	end
	for y=0, height-1 do
		local cline = {}
		for x=0, width-1 do
			local r,g,b,_char = pixel_callback(x,y)
			local char
			if r and g and b then
				if _char then
					char = rgb_to_escape(r,g,b) .. _char
				else
					char = rgb_to_escape(r,g,b) .. " "
				end
			elseif _char then
				char = _char
			else
				error("Pixel_callback failed!")
			end
			cline[x+1] = char
		end
		lines[y+1] = table.concat(cline)
	end
	return lines
end


-- utillity function to draw from a drawbuffer(calls draw_pixel_callback)
function Blocks.draw_db(db, bpp24)
	-- draw pixels with no alpha color in the default terminal background color
	local function pixel_callback(x, y)
		local r,g,b,a = db:get_pixel(x,y)
		if a == 0 then
			return nil,nil,nil,"\027[0m "
		else
			return r,g,b
		end
	end

	-- draw using the pixel-callback
	local width = db:width()
	local height = db:height()
	return Blocks.draw_pixel_callback(width, height, pixel_callback, bpp24)
end



return Blocks
