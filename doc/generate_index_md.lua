#!/usr/bin/env lua5.1
-- This script generates a simple markdown index for each topic in the file argument list
print("# Index\n")
for _, file in ipairs(arg) do
	local index = tonumber(file:match("^(%d%d%d%d)_.*%.md$"))
	local basename = file:match("^%d%d%d%d_(.*)%.md$")
	local title = basename:gsub("_", " ")
	local link = "#" .. basename
	if (index % 100)==0 then
		-- if the index number's last 2 digits are 0, this is a top-level
		-- topic, and should not be indented.
		local num = index/100 -- numeric index in top-level list
		print(" " .. num .. ". [" .. title.."](" .. link .. ")")
	else
		-- if the index number's last 2 digits are not 0,
		print("    - [" .. title.."](" .. link .. ")")
	end
end
