#!/usr/bin/env luajit
local lu = require("luaunit")


-- used for creating temporary drawbuffers
local width,height = 100,100
local px_fmt = "rgba8888"

-- ignore test_* global functions used by luacheck
--luacheck: ignore test[%w_]+

function test_gfx_set_px_alphablend()
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
	lu.assertEquals({r,g,b,a}, {255,255,255,0})
	drawbuffer:set_px(0,0, 0,0,0,0)

	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 227,233,241,255)
	r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {227,233,241,0})
	drawbuffer:set_px(0,0, 0,0,0,0)

	-- make sure alpha=0 does not change pixel value
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 227,233,241,255)
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 255,255,255,0)
	r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {227,233,241,0})
	drawbuffer:set_px(0,0, 0,0,0,0)

	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 227,233,241,255)
	ldb_gfx.set_px_alphablend(drawbuffer, 0,0, 0,0,0,0)
	r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {227,233,241,0})
end


function test_gfx_hsv_to_rgb()
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

	-- test a reduced v value
	r,g,b = ldb_gfx.hsv_to_rgb(0,1,0.5)
	lu.assertEquals({r,g,b}, {127,0,0})

	-- test a saturation of 0 with value=1(white)
	r,g,b = ldb_gfx.hsv_to_rgb(0,0,1)
	lu.assertEquals({r,g,b}, {255,255,255})

	-- test a saturation of 0 with value=0.5(grey)
	r,g,b = ldb_gfx.hsv_to_rgb(0,0,0.5)
	lu.assertEquals({r,g,b}, {127,127,127})
end


function test_gfx_rgb_to_hsv()
	local ldb_gfx = require("ldb_gfx")

	-- compare the absolute difference between a and b, return true if value is smaller than max_deviation
	local function deviation(a, b, max_deviation)
		return math.abs(a-b)<max_deviation
	end

	-- maximum derivation from expected comparison value based on RGB precision
	local max_deviation = 1/256

	-- Pure red should produce hue=0, maximum saturation and value
	local h,s,v = ldb_gfx.rgb_to_hsv(255,0,0)
	lu.assertEquals({h,s,v}, {0,1,1})

	-- Pure green should produce hue=120°, maximum saturation and value
	h,s,v = ldb_gfx.rgb_to_hsv(0,255,0)
	lu.assertEquals({s,v}, {1,1})
	lu.assertEvalToTrue(deviation(h,2/6,max_deviation))

	-- Pure blue should produce hue=240°, maximum saturation and value
	h,s,v = ldb_gfx.rgb_to_hsv(0,0,255)
	lu.assertEquals({s,v}, {1,1})
	lu.assertEvalToTrue(deviation(h,4/6,max_deviation))

	-- reduced rgb values lead to reduced value
	h,s,v = ldb_gfx.rgb_to_hsv(127,0,0)
	lu.assertEquals({h,s}, {0,1})
	lu.assertEvalToTrue(deviation(v,0.5,max_deviation))
end


function test_gfx_line_vertical()
	local ldb_core = require("ldb_core")
	local ldb_gfx = require("ldb_gfx")
	local drawbuffer = ldb_core.new_drawbuffer(width,height,px_fmt)
	lu.assertEvalToTrue(drawbuffer)
	drawbuffer:clear(0,0,0,0)

	-- simple vertical line(from (10,10) to (width-11, 10)), overwrite pixels
	ldb_gfx.line(drawbuffer, 10,10, width-11,10, 11,22,33,44, false)

	-- check that all expected pixels are set
	for x=10, width-11 do
		local r,g,b,a = drawbuffer:get_px(x,10)
		lu.assertEquals({r,g,b,a}, {11,22,33,44})
		-- "unset" every expected pixel
		drawbuffer:set_px(x,10,0,0,0,0)
	end

	-- check no overdraw happened(drawbuffer should be empty now)
	lu.assertEquals(drawbuffer:dump_data(), ("\0"):rep(width*height*4))
end


function test_gfx_line_horizontal()
	local ldb_core = require("ldb_core")
	local ldb_gfx = require("ldb_gfx")
	local drawbuffer = ldb_core.new_drawbuffer(width,height,px_fmt)
	lu.assertEvalToTrue(drawbuffer)
	drawbuffer:clear(0,0,0,0)

	-- simple horizontal line(from (10,10) to (10, height-11)), overwrite pixels
	ldb_gfx.line(drawbuffer, 10,10, 10,height-11, 11,22,33,44, false)

	-- check that all expected pixels are set
	for y=10, height-11 do
		local r,g,b,a = drawbuffer:get_px(10,y)
		lu.assertEquals({r,g,b,a}, {11,22,33,44})
		-- "unset" every expected pixel
		drawbuffer:set_px(10,y,0,0,0,0)
	end

	-- check no overdraw happened(drawbuffer should be empty now)
	lu.assertEquals(drawbuffer:dump_data(), ("\0"):rep(width*height*4))
end


function test_gfx_line_diagonal()
	local ldb_core = require("ldb_core")
	local ldb_gfx = require("ldb_gfx")
	local drawbuffer = ldb_core.new_drawbuffer(width,height,px_fmt)
	lu.assertEvalToTrue(drawbuffer)
	drawbuffer:clear(0,0,0,0)

	local min_d = math.min(width,height)

	-- simple vertical line(from (10,10) to (width-11, 10)), overwrite pixels
	ldb_gfx.line(drawbuffer, 10,10, min_d-11,min_d-11, 11,22,33,44, false)

	-- check that all expected pixels are set
	for i=10, min_d-11 do
		local r,g,b,a = drawbuffer:get_px(i,i)
		lu.assertEquals({r,g,b,a}, {11,22,33,44})
		-- "unset" every expected pixel
		drawbuffer:set_px(i,i,0,0,0,0)
	end

	-- check no overdraw happened(drawbuffer should be empty now)
	lu.assertEquals(drawbuffer:dump_data(), ("\0"):rep(width*height*4))
end


function test_gfx_line_misc()
	local ldb_core = require("ldb_core")
	local ldb_gfx = require("ldb_gfx")
	local drawbuffer = ldb_core.new_drawbuffer(width,height,px_fmt)
	lu.assertEvalToTrue(drawbuffer)
	drawbuffer:clear(0,0,0,0)

	-- check that setting a single pixel works as expected
	ldb_gfx.line(drawbuffer, 10,10, 10,10, 11,22,33,44, false)
	local r,g,b,a = drawbuffer:get_px(10,10)
	lu.assertEquals({r,g,b,a}, {11,22,33,44})
	drawbuffer:set_px(10,10, 0,0,0,0)

	-- check no overdraw happened(drawbuffer should be empty now)
	lu.assertEquals(drawbuffer:dump_data(), ("\0"):rep(width*height*4))

	-- check that setting a single pixel uisng alphablending works as expected
	ldb_gfx.line(drawbuffer, 10,10, 10,10, 255,255,255,127, true)
	r,g,b,a = drawbuffer:get_px(10,10)
	lu.assertEquals({r,g,b,a}, {127,127,127,0})
	drawbuffer:set_px(10,10, 0,0,0,0)

	-- check no overdraw happened(drawbuffer should be empty now)
	lu.assertEquals(drawbuffer:dump_data(), ("\0"):rep(width*height*4))
end


function test_gfx_origin_to_target()
	local ldb_core = require("ldb_core")
	local ldb_gfx = require("ldb_gfx")

	-- create a new drawbuffer, clear to black
	local drawbuffer_a = ldb_core.new_drawbuffer(width,height,px_fmt)
	lu.assertEvalToTrue(drawbuffer_a)
	drawbuffer_a:clear(0,0,0,255)

	-- create a second drawbuffer, clear to white
	local drawbuffer_b = ldb_core.new_drawbuffer(width,height,px_fmt)
	lu.assertEvalToTrue(drawbuffer_b)
	drawbuffer_b:clear(255,255,255,255)

	-- copy everything from drawbuffer_b(origin) to drawbuffer_a(target)
	ldb_gfx.origin_to_target(drawbuffer_b, drawbuffer_a)

	-- verify that we have copied every single pixel
	lu.assertEvalToTrue(drawbuffer_a:dump_data() == drawbuffer_b:dump_data())

	-- verify that we did not modify the source buffer
	lu.assertEvalToTrue(drawbuffer_b:dump_data()==string.char(255):rep(width*height*4))
end


-- TODO: test lines p1==p1, 1px wide/tall, etc.
-- TODO: Also test alphablending mode for lines
-- TODO: test rectangle, circles
os.exit(lu.LuaUnit.run())
