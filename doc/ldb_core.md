# ldb_core - Core C module

This documentation is about the lua-db core C module(`ldb_core.c`).

It implements the basic drawbuffer userdata type. Each drawbuffer userdata
instance has the same metatable, which makes extending the available methods
easy.

It is loaded simply by `ldb_core = require("ldb_core")`. Keep in mind that this is not the
usual way to load this library. Instead, use `ldb = require("lua-db")` to load the
entire library with it's overloaded functions, if available. This will load this
C module internally and overload the avaliable functions into the drawbuffer
metatable.

The returned table contains:
 * version - the library version as a string(from ldb.h, currently `3.0`)
 * pixel_formats - a table containing the available pixel formats.
 * new_drawbuffer - a function that returns a new drawbuffer of specified size
