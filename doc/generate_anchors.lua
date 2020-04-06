#!/usr/bin/env lua5.1
for _, filename in ipairs(arg) do
	local basename = filename:match("^(.*)%.md$")
	local file = io.open(basename..".anchor_md", "w")
	local link = filename:match("^%d%d%d%d_(.*)%.md$")
	local line = "\n\n\n<a name=\"" .. link .. "\"></a>\n\n---\n\n"
	--io.write(line)
	file:write(line)
	file:close()
end
