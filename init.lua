--[[
this file produces the actual module for lua-db, combining the
C functionallity with the lua functionallity. You can use the C module
directly. This works by extending the meta table.
--]]
local db = require("ldb")
local db_mt = getmetatable(db)
db_mt.bitmap = require("bitmap")
db_mt.braile = require("braile")




return db
