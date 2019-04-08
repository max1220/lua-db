local term = require("term")



local Blocks = {}
-- simple module for color bitmap output on the terminal using space characters


-- get an ANSI escape sequence for setting the background color(r,g,b: 0-255) in a 216-color space
Blocks.get_color_code_bg = term.rgb_to_ansi_color_bg_216


-- draw using a space character with colored background for each pixel returned by pixel_callback
function Blocks.draw_pixel_callback(width, height, pixel_callback)
	local lines = {}
	for y=0, height-1 do
		local cline = {}
		for x=0, width-1 do
			local r,g,b,_char = pixel_callback(x,y)
			local char = _char or " "
			if r and g and b then
				char = Blocks.get_color_code_bg(r,g,b) .. char
			else
				char = "\027[0m" .. char
			end
			cline[x+1] = char
		end
		lines[y+1] = table.concat(cline)
	end
	return lines
end


-- utillity function to draw from a drawbuffer(calls draw_pixel_callback)
function Blocks.draw_db(db)
	
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
	return Blocks.draw_pixel_callback(width, height, pixel_callback)
	
end



return Blocks
