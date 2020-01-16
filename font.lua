local Font = {}

function Font.from_drawbuffer(db, char_w, char_h, alpha_color, _scale)
	local font = {}
	local scale = tonumber(_scale) or 1

	font.db = assert(db)
	font.char_w = assert(tonumber(char_w))
	font.char_h = assert(tonumber(char_h))
	if alpha_color then
		local ar, ag, ab = unpack(alpha_color)
		-- set the alpha values of pixels with this r,g,b value to 0
		for y=0, db:height()-1 do
			for x=0, db:width()-1 do
				local r,g,b = db:get_pixel(x,y)
				if r == ar and g == ag and b == ab then
					db:set_pixel(x,y,r,g,b, 0)
				else
					db:set_pixel(x,y,r,g,b, 255)
				end
			end
		end
	end

	-- calculate offsets in font
	font.chars = {}
	local index = 0
	for y=0, db:height()-1, char_h do
		for x=0, db:width()-1, char_w do
			font.chars[index] = {x,y}
			index = index + 1
		end
	end

	-- split a string into lines of lenght <= max_width
	-- TODO: split along word boundarys if possible
	function font:str_split_lines(str, max_width)
		local lines = {}
		local cline = {}
		for i=1, #str do
			table.insert(cline, str:sub(i,i))
			if max_width then
				local max_len = math.floor(max_width / self.char_w)
				table.insert(lines, table.concat(cline))
				cline = {}
			end
		end
		if #cline > 0 then
			table.insert(lines, table.concat(cline))
		end
		return lines
	end

	-- draws a single character from the font
	function font:draw_character(target_db, char_id, x, y, color)
		local char = self.chars[char_id]
		if not char then
			return
		end
		local source_x, source_y = char[1], char[2]
		if color then
			for oy=0, self.char_h-1 do
				for ox=0, self.char_w-1 do
					local _,_,_,a = self.db:get_pixel(source_x+ox,source_y+oy)
					if a > 0 then
						for sy=0, scale-1 do
							for sx=0, scale-1 do
								target_db:set_pixel(x+ox*scale+sx,y+oy*scale+sy, color[1], color[2], color[3], color[4])
							end
						end
					end
				end
			end
		else
			self.db:draw_to_drawbuffer(target_db, x, y, source_x, source_y, char_w, char_h, scale)
		end
	end

	-- draws a string. If max_width is provided, the string is split into multiple lines using str_split_lines
	function font:draw_string(target_db, str, x, y, max_width, color)
		if max_width then
			local lines = self:str_split_lines(str, max_width)
			for oy, line in ipairs(lines) do
				self:draw_string(target_db, line, x, y+oy*char_h, nil, color)
			end
		else
			for i=1, #str do
				self:draw_character(target_db, str:byte(i), x+(i-1)*char_w*scale, y, color)
			end
		end
	end

	-- get the rendered width, height of a string
	function font:string_size(str, max_width)
		local lines = self:str_split_lines(str, max_width)
		local max_len = 0
		for _, line in ipairs(lines) do
			max_len = math.max(max_len, #line)
		end
		local width = max_len * char_w * scale
		local height = #lines * char_h * scale
		return width, height
	end

	return font

end


function Font.from_file(filepath, char_w, char_h, alpha_color, scale)
	local Bitmap = require("lua-db.bitmap")
	local db = Bitmap.decode_from_file_drawbuffer(filepath)
	return Font.from_drawbuffer(db, char_w, char_h, alpha_color, scale)
end



return Font
