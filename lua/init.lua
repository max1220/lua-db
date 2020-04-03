--[[
this file produces the actual module for lua-db, combining the
C functionallity with the lua functionallity. You can use the C modules
directly by requiring ldb_core(ldb_gfx, ldb_sdl) directly.
--]]
--luacheck: ignore self
local ldb_core = require("ldb_core")


-- append ldb_gfx drawbuffer functions to metatable of drawbuffers(every drawbuffer has the same metatable)
local ldb_gfx = require("ldb_gfx")
local db_mt = getmetatable(ldb_core.new_drawbuffer(1,1))
local gfx_drawbuffer_functions = {
	"pixel_function",
	"origin_to_target",
	"line",
	"rectangle",
	"triangle",
	"set_px_alphablend",
	"circle",
	"floyd_steinberg"
}
for _,name in ipairs(gfx_drawbuffer_functions) do
	db_mt.__index[name] = ldb_gfx[name]
end


-- append utillity functions
ldb_core.hsv_to_rgb = ldb_gfx.hsv_to_rgb
ldb_core.rgb_to_hsv = ldb_gfx.rgb_to_hsv


-- append Lua helper functions
ldb_core.input_output = require("lua-db.input_output")
ldb_core.braile = require("lua-db.braile")
ldb_core.blocks = require("lua-db.blocks")
ldb_core.halfblocks = require("lua-db.halfblocks")
ldb_core.ffmpeg = require("lua-db.ffmpeg")
ldb_core.term = require("lua-db.term")
ldb_core.bitmap = require("lua-db.bitmap")
ldb_core.bmpfont = require("lua-db.bmpfont")
ldb_core.gui = require("lua-db.gui")
ldb_core.tileset = require("lua-db.tileset")


--ldb_core.ppm = require("lua-db.ppm")
--ldb_core.imlib = require("lua-db.imlib")
--ldb_core.raw = require("lua-db.raw")


return ldb_core
