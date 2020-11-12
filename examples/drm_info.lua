#!/usr/bin/env lua5.1

local print_table_sorted
print_table_sorted = function (t, i)
	local indent = ("\t"):rep(tonumber(i) or 0)
	local new_t = {}
	for k,v in pairs(t) do
		table.insert(new_t, {k=k,v=v})
	end
	table.sort(new_t, function(a,b)
		return a.k>b.k
	end)
	for _,entry in ipairs(new_t) do
		if type(entry.v) == "table" then
			print(indent..tostring(entry.k))
			print_table_sorted(entry.v, i+1)
		else
			print(indent..tostring(entry.k), tostring(entry.v))
		end
	end
end

print("Loading DRM Lua module...")
local drm = require("ldb_drm")
print("\tGot module:", drm)

print("Getting a handle for card /dev/dri/card0...")
local dev = drm.new_drm("/dev/dri/card0")
print("\tGot handle:", dev)

print("Getting info...")
local info = dev:get_info()
print("\tGot info:", info)
print_table_sorted(info)
