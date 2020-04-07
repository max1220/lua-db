#!/usr/bin/env lua5.1
local filename = assert(arg[1])
local link = filename:match("^%d%d%d%d_(.*)%..*$")
if link then
	io.write("\n\n<a name=\"" .. link .. "\"></a>\n\n")
end
