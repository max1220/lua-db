#!/usr/bin/env luajit
local lu = require("luaunit")


-- used for creating temporary drawbuffers
local width,height = 10,10
local px_fmt = "rgba8888"

function test_gfx_alphablend()
	-- test setting pixels using alphablending
	local ldb_core = require("ldb_core")
	local ldb_gfx = require("ldb_gfx")
	local drawbuffer = ldb_core.new_drawbuffer(width,height,px_fmt)

	-- basic sanity check for module loading
	lu.assertEvalToTrue(ldb_core)
	lu.assertEvalToTrue(ldb_gfx)
	lu.assertEvalToTrue(drawbuffer)

	drawbuffer:clear(0,0,0,0)

	-- make sure that alpha=255 works overwrites values correctly
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 255,255,255,255)
	local r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {255,255,255,255})

	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 227,233,241,255)
	r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {227,233,241,255})

	-- make sure alpha=0 does not change pixel value
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 227,233,241,255)
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 255,255,255,0)
	r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {227,233,241,255})

	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 227,233,241,255)
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 0,0,0,0)
	r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {227,233,241,255})
end


function test_gfx_hsv()
	local ldb_gfx = require("ldb_gfx")

	-- default is argumets are zero, should also produce r,g,b=0
	local r,g,b = ldb_gfx.hsv_to_rgb()
	lu.assertEquals({r,g,b}, {0,0,0})

	-- hue=0 is red, maximum saturation and value
	r,g,b = ldb_gfx.hsv_to_rgb(0,1,1)
	lu.assertEquals({r,g,b}, {255,0,0})

	-- hue=60° is yellow, maximum saturation and value
	r,g,b = ldb_gfx.hsv_to_rgb(1/6,1,1)
	lu.assertEquals({r,g,b}, {255,255,0})

	-- hue=120° is green, maximum saturation and value
	r,g,b = ldb_gfx.hsv_to_rgb(2/6,1,1)
	lu.assertEquals({r,g,b}, {0,255,0})

	-- hue=180° is cyan, maximum saturation and value
	r,g,b = ldb_gfx.hsv_to_rgb(3/6,1,1)
	lu.assertEquals({r,g,b}, {0,255,255})

	-- hue=240 is blue, maximum saturation and value
	r,g,b = ldb_gfx.hsv_to_rgb(4/6,1,1)
	lu.assertEquals({r,g,b}, {0,0,255})

	-- hue=300° is magenta, maximum saturation and value
	r,g,b = ldb_gfx.hsv_to_rgb(5/6,1,1)
	lu.assertEquals({r,g,b}, {255,0,255})

	local step = 0.1
	for v=0,1,step do
		for s=0,1,step do
			for h=0,1,step do
				local r,g,b = ldb_gfx.hsv_to_rgb(h,s,v)
				local _h,_s,_v = ldb_gfx.rgb_to_hsv(r,g,b)
				local dh,ds,dv = math.abs(_h-h),math.abs(_s-s),math.abs(_v-v)
				local max_d = 0.01
				if ((dh>max_d) or (ds>max_d) or (dv>max_d)) then
					--print(("%.2f %.2f %.2f  -->  %.2f %.2f %.2f"):format(h,s,v,_h,_s,_v))
				end
				--lu.assertEvalToTrue(dh<min_d)
				--lu.assertEvalToTrue(ds<min_d)
				--lu.assertEvalToTrue(dv<min_d)
				--lu.assertEquals({_h,_s,_v}, {h,s,v})
			end
		end
	end

	--ldb_gfx.rgb_to_hsv()
end
--[[
function test_gfx_line()
	local ldb_gfx = require("ldb_gfx")

	ldb_gfx.line()
end

function test_gfx_rectangle()
	local ldb_gfx = require("ldb_gfx")

	ldb_gfx.rectangle()
end
]]


os.exit(lu.LuaUnit.run())
