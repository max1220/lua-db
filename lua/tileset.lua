--[[
This module handles drawing tiles from a tileset.
Each tile in the tileset has the x,y,w,h fields that specify the rectangle in the
source tileset drawbuffer.
]]
--luacheck: ignore self, no max line length
local Tileset = {}

-- return tileset
function Tileset.new_tileset(tileset_db, tiles)
	local tileset = {}
	tileset.tiles = tiles

	-- draw a single tile on screen
	function tileset:draw_tile(tile_index, target_db, target_x, target_y, scale_x, scale_y, alpha_mode)
		local tile = self.tiles[tile_index]
		if not tile then
			return
		end
		scale_x, scale_y = tonumber(scale_x) or tile.scale_x or 1, tonumber(scale_y) or tile.scale_y or 1
		alpha_mode = alpha_mode or tile.alpha_mode
		if (alpha_mode == "ignorealpha") or (not alpha_mode) then
			tileset_db:origin_to_target(target_db, target_x, target_y, tile.x, tile.y, tile.w, tile.h, scale_x, scale_y, "ignorealpha")
		elseif alpha_mode == "alphablend" then
			tileset_db:origin_to_target(target_db, target_x, target_y, tile.x, tile.y, tile.w, tile.h, scale_x, scale_y, "alphablend")
		elseif alpha_mode == "copy" then
			tileset_db:origin_to_target(target_db, target_x, target_y, tile.x, tile.y, tile.w, tile.h, scale_x, scale_y)
		end
	end

	return tileset
end

-- generate a list of tiles with identical tile dimensions.
function Tileset.generate_tiles(tiles_x, tiles_y, tile_w, tile_h, offset_x, offset_y)
	local tiles = {}

	local i = 0
	for tile_y=0, tiles_y-1 do
		for tile_x=0, tiles_x-1 do
			local x = tile_x*tile_w+offset_x
			local y = tile_y*tile_h+offset_y
			tiles[i] = { x=x, y=y, w=tile_w, h=tile_h }
			i = i + 1
		end
	end

	return tiles
end


return Tileset
