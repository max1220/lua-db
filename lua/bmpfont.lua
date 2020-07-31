--[[
This module is for drawing bitmap fonts.
It uses the tileset library to draw it's characers.
]]
--TODO: Implement space width
--luacheck: ignore self, no max line length
local Tileset = require("lua-db.tileset")
local ldb_core = require("ldb_core")
local ldb_gfx = require("ldb_gfx")
local BMPFont = {}


function BMPFont.new_bmpfont(config)
	local font = {}
	font.scale = tonumber(config.scale) or 1

	-- always copy drawbuffer, because we need alpha channel, and we modify
	assert(config.db)
	font.db = ldb_core.new_drawbuffer(config.db:width(), config.db:height(), "rgba8888")
	config.db:origin_to_target(font.db)

	font.char_w = assert(tonumber(config.char_w))
	font.char_h = assert(tonumber(config.char_h))

	-- create tileset
	local tiles_x = tonumber(config.tiles_x) or math.floor(font.db:width()/font.char_w)
	local tiles_y = tonumber(config.tiles_y) or math.floor(font.db:height()/font.char_h)
	local tiles_ox = tonumber(config.tiles_offset_x) or 0
	local tiles_oy = tonumber(config.tiles_offset_y) or 0
	local tiles = config.tiles or Tileset.generate_tiles(tiles_x, tiles_y, font.char_w, font.char_h, tiles_ox, tiles_oy)
	font.tileset = Tileset.new_tileset(font.db, tiles)

	font.char_to_tile = config.char_to_tile
	font.letter_spacing = tonumber(config.letter_spacing) or 0
	font.scale_x = math.floor(tonumber(config.scale_x) or 1)
	font.scale_y = math.floor(tonumber(config.scale_y) or 1)
	font.default_char = config.default_char

	-- TODO: replace with unicode-aware functions
	function font:char_to_num(char)
		assert(#char==1) -- don't just take the first byte, as that might overwrite other characters.
		return string.byte(char)
	end
	function font:num_to_char(num)
		return string.char(num)
	end
	function font:for_each_char(str, cb)
		for i=1, #(str) do
			cb(str:sub(i,i))
		end
	end

	-- generate a character to tile-id mapping
	if (not font.char_to_tile) and config.char_to_tile_str then
		-- map based on a string. Position of character in string is tileset index for that character.
		-- (e.g. if the first tile is the character "A", this string should start with "A")
		font.char_to_tile = {}
		local i = 0
		font:for_each_char(config.char_to_tile_str, function(char)
			font.char_to_tile[char] = i
			i = i + 1
		end)
	elseif not font.char_to_tile then
		-- default mapping of characters to tileset index(ASCII, left-to-right, top-to-bottom order tileset index)
		-- (e.g. the 65th tile is for character "A", assuming ASCII)
		font.char_to_tile = {}
		for i=0, 127 do
			font.char_to_tile[string.char(i)] = i
		end
	end

	-- if config.alpha_color is set, key out the specified color.
	if config.alpha_color then
		local ar, ag, ab = unpack(config.alpha_color)
		-- set the alpha values of pixels with this r,g,b value to 0
		for y=0, font.db:height()-1 do
			for x=0, font.db:width()-1 do
				local r,g,b = font.db:get_px(x,y)
				if (r == ar) and (g == ag) and (b == ab) then
					font.db:set_px(x,y,r,g,b, 0)
				else
					font.db:set_px(x,y,r,g,b, 255)
				end
			end
		end
	end

	-- if config.color is set, recolor the drawbuffer
	if config.color then
		-- copy the hue/saturation from the new color, keep the value of the original color
		local nh,ns = ldb_gfx.rgb_to_hsv(config.color[1], config.color[2], config.color[3])
		for y=0, font.db:height()-1 do
			for x=0, font.db:width()-1 do
				local sr,sg,sb,a = font.db:get_px(x,y)
				local _, _, sv = ldb_gfx.rgb_to_hsv(sr,sg,sb)
				local nr,ng,nb = ldb_gfx.hsv_to_rgb(nh,ns,sv)
				font.db:set_px(x,y,nr,ng,nb,a)
			end
		end
	end

	-- draw a single character to target_db at x,y
	function font:draw_character(target_db, char, x,y)
		local tile_id = self.char_to_tile[char] or self.char_to_tile[self.default_char]
		if not tile_id then
			return
		end
		self.tileset:draw_tile(tile_id, target_db, x, y, self.scale_x, self.scale_y, "ignorealpha")
	end

	-- get the length in pixels of the single-line string.
	function font:length_text(str)
		local len = 0
		self:for_each_char(str, function(char)
			local tile_id = self.char_to_tile[char] or self.char_to_tile[self.default_char]
			if not tile_id then
				return
			end
			local tile = self.tileset.tiles[tile_id]
			if not tile then
				return
			end
			len = len + tile.w*self.scale_x + self.letter_spacing
		end)
		len = len - self.letter_spacing
		return len
	end

	-- draw the single-line string on target_db, at x,y.
	function font:draw_text(target_db, str, x,y)
		local cx = 0
		self:for_each_char(str, function(char)
			local tile_id = self.char_to_tile[char] or self.char_to_tile[self.default_char]
			if not tile_id then
				return
			end
			local tile = self.tileset.tiles[tile_id]
			if not tile then
				return
			end
			self:draw_character(target_db, char, x+cx, y)
			cx = cx + tile.w*self.scale_x + self.letter_spacing
		end)
		local len = cx - self.letter_spacing
		return len
	end

	return font

end

return BMPFont
