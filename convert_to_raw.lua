#!/usr/bin/env luajit
local ldb = require("lua-db")
local db = ldb.imlib.from_file(assert(arg[1], "Argument 1 is input file"))
assert(io.open(assert(arg[2], "Argument 2 is output file"), "wb")):write(db:dump_data())
