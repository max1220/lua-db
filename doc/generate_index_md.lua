#!/usr/bin/env lua5.1
-- start outputting the generated index
print("# Index\n")
for _, file in ipairs(arg) do
	local index = tonumber(file:match("^(%d%d%d%d)_"))
	local basename = file:match("^%d%d%d%d_(.*)%.md$")
	local title = basename:gsub("_", " ")
	--local link = basename .. ".md"
	--local link = basename .. ".html"
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

-- TODO: generate links for html one document(links to #basename)
-- TODO: generate links for markdown one document(links to #basename?)
-- TODO: generate links for html multiple documents(links to basename.html)
