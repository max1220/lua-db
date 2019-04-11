--[[
this file produces the actual module for lua-db, combining the
C functionallity with the lua functionallity. You can use the C module
directly by requiring ldb directly.
--]]


local db = require("lua-db.lua_db")

db.bitmap = require("lua-db.bitmap")
db.ppm = require("lua-db.ppm")
db.braile = require("lua-db.braile")
db.blocks = require("lua-db.blocks")
db.font = require("lua-db.font")
db.ffmpeg = require("lua-db.ffmpeg")
db.term = require("lua-db.term")



return db
