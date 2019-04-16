local ldb = require("lua-db.lua_db")


local Tileset = {}
function Tileset.new(db, tile_w, tile_h)
	local tileset = {}
	
	local db = assert(db)
	local tile_w, tile_h = assert(tonumber(tile_w)), assert(tonumber(tile_h))
	local width, height = db:width(), db:height()
	local tiles_x, tiles_y = math.floor(width/tile_w), math.floor(height/tile_h)
	local tiles = {}
	
	tileset.tiles = tiles
	tileset.tile_w = tile_w
	tileset.tile_h = tile_h
	tileset.tiles_x = tiles_x
	tileset.tiles_y = tiles_y
	tileset.db = db
	
	-- insert a coordinate for each tile into tiles
	for y=0, tiles_y-1 do
		for x=0, tiles_x-1 do
			table.insert(tiles, { x*tile_w, y*tile_h })
		end
	end
	
	-- draw a single tile
	function tileset.draw_tile(target_db, x,y,tile_id)
		local source_x, source_y = unpack(assert(tiles[tile_id]))
		db:draw_to_drawbuffer(target_db, x,y, source_x, source_y, tile_w, tile_h)
	end
	
	return tileset
end


return Tileset
