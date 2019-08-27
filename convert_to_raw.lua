#!/usr/bin/env luajit
local ldb = require("lua-db")
local db = ldb.imlib.from_file(assert(arg[1], "Argument 1 is input file"))
local file = assert(io.open(assert(arg[2], "Argument 2 is output file"), "wb"), "Can't open file!")
if (not arg[3]) or (arg[3] == "rgba") then
	file:write(db:dump_data_rgba())
elseif arg[3] == "rgb" then
	file:write(db:dump_data_rgb())
else
	print("Unknown pixel format! Try rgba, rgb or blank for default(rgba)")
end
file:close()
