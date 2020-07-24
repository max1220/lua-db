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
local db_gfx_functions = {
	"pixel_function",
	"origin_to_target",
	"line",
	"rectangle",
	"triangle",
	"set_px_alphablend",
	"circle",
	"floyd_steinberg"
}
for _,name in ipairs(db_gfx_functions) do
	db_mt.__index[name] = ldb_gfx[name]
end

-- append gfx utillity functions
ldb_core.hsv_to_rgb = ldb_gfx.hsv_to_rgb
ldb_core.rgb_to_hsv = ldb_gfx.rgb_to_hsv


-- load pure-lua modules into namespace
local lua_modules = {
	"input_output",
	"braile",
	"blocks",
	"halfblocks",
	"ffmpeg",
	"terminal",
	"bitmap",
	"bmpfont",
	"gui",
	"tileset",
	"tetris",
	"gol",
	"random",
	"terminal_buffer",
	--"ppm",
	--"imlib",
	--"raw",
}
for _,lua_module_name in ipairs(lua_modules) do
	ldb_core[lua_module_name] = require("lua-db." .. lua_module_name)
end


return ldb_core
