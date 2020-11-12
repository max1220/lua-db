#!/usr/bin/env lua5.1
print("Loading DRM Lua module...")
local drm = require("ldb_drm")
print("\tGot module:", drm)

print("Getting a handle for card /dev/dri/card0...")
local dev = drm.new_drm("/dev/dri/card0")
print("\tGot handle:", dev)

print("Getting info...")
local info = dev:get_info()
local w,h = info.buf0.width, info.buf0.height
print("\tGot info:", w, h)

for i=1, 2000 do
	dev:draw()
end

dev:close()
