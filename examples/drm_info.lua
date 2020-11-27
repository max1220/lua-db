#!/usr/bin/env lua5.1
local function table_dump(t,i)
	i = tonumber(i) or 0
	for k,v in pairs(t) do
		if type(v) == "table" then
			print(("\t"):rep(i)..tostring(k),tostring(v))
			table_dump(v,i+1)
		else
			print(("\t"):rep(i)..tostring(k),v)
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
table_dump(info)
