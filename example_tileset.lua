#!/usr/bin/env luajit
local ldb = require("lua-db")

local w = 200
local h = 100
local tile_w = 8
local tile_h = 8

-- load tileset image
local tileset_img = ldb.bitmap.decode_from_file_drawbuffer("cga8.bmp")

-- create tileset
local tileset = ldb.tileset.new(tileset_img, tile_w, tile_h)

-- create output drawbuffer
local db = ldb.new(w,h)
db:clear(0,0,0,255)

local _write = io.write
local _draw_tile = tileset.draw_tile
local _random = math.random
local _concat = table.concat
local _line = ldb.term.reset_color() .. "\n"
local _cursor = ldb.term.set_cursor(0,0)
while true do
	for i=1, 1000 do
		local x = _random(-tile_w, w)
		local y = _random(-tile_h, h)
		local tileid = _random(1, #tileset.tiles)
		_draw_tile(db, x, y, tileid)
	end
	_write(_cursor .. _concat(ldb.braile.draw_db_precise(db, 50, false), _line))
end
