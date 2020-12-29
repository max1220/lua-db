#!/usr/bin/env luajit
local lu = require("luaunit")


-- used for creating temporary drawbuffers
local w,h = 100,100
local px_fmt = "rgba8888"

function test_drawbuffer_basic()
	-- test the basics: loading the C module, create a drawbuffer, query info about it, close it
	local ldb_core = require("ldb_core")
	local drawbuffer = ldb_core.new_drawbuffer(w,h,px_fmt)

	-- basic sanity check(check default pixel format, tostring, width*height*4 = bytes_len, #dump_data == bytes_len)
	lu.assertEvalToTrue(ldb_core)
	lu.assertEvalToTrue(drawbuffer)
	lu.assertEquals(drawbuffer:pixel_format(), px_fmt)
	lu.assertEquals(drawbuffer:bytes_len(), w*h*4)
	lu.assertEquals(#drawbuffer:dump_data(), w*h*4)
	lu.assertEquals(drawbuffer:width(), w)
	lu.assertEquals(drawbuffer:height(), h)
	lu.assertEquals(drawbuffer:tostring(), "32bpp RGBA Drawbuffer: " .. drawbuffer:width() .. "x" .. drawbuffer:height())

	-- close the drawbuffer(deallocates the data memory)
	lu.assertEvalToTrue(drawbuffer:close())

	-- Tostring should return that you closed the drawbuffer
	lu.assertEquals(drawbuffer:tostring(), "Closed Drawbuffer")

	-- check that we can't call any functions
	lu.assertEvalToFalse(drawbuffer:pixel_format())
	lu.assertEvalToFalse(drawbuffer:bytes_len())
	lu.assertEvalToFalse(drawbuffer:dump_data())
	lu.assertEvalToFalse(drawbuffer:width())
	lu.assertEvalToFalse(drawbuffer:height())
end

function test_drawbuffer_clear()
	-- test the clear drawbuffer function. Sets the r,g,b,a values in the drawbuffer
	-- TODO: this only works with px_fmt = "rgba8888"
	local ldb_core = require("ldb_core")
	local drawbuffer = ldb_core.new_drawbuffer(w,h,px_fmt)

	-- check that we have the expected effect by comparing the dump output
	lu.assertEvalToTrue(drawbuffer:clear(0,0,0,0))
	lu.assertEquals(drawbuffer:dump_data(), ("\0\0\0\0"):rep(w*h))

	lu.assertEvalToTrue(drawbuffer:clear(255,255,255,255))
	lu.assertEquals(drawbuffer:dump_data(), ("\255\255\255\255"):rep(w*h))

	-- check argument order as expected
	lu.assertEvalToTrue(drawbuffer:clear(211,227,233,241))
	lu.assertEquals(drawbuffer:dump_data(), ("\211\227\233\241"):rep(w*h))
end

function test_drawbuffer_load_data()
	local ldb_core = require("ldb_core")
	local drawbuffer = ldb_core.new_drawbuffer(w,h,px_fmt)

	-- attempt to load invalid lengths
	lu.assertEvalToFalse(drawbuffer:load_data(("\0\0\0\0"):rep(w*h-1)))
	lu.assertEvalToFalse(drawbuffer:load_data(("\0\0\0\0"):rep(w*h+1)))

	-- generate a loadable data segment and compare using :get_px
	local data = {}
	for y=1, drawbuffer:height() do
		local cline = {}
		for x=1, drawbuffer:width() do
			if x==y then
				cline[#cline+1] = "\63\127\255\255"
			else
				cline[#cline+1] = "\0\0\0\0"
			end
		end
		data[y] = table.concat(cline)
	end

	-- load the generated "image"
	lu.assertEvalToTrue(drawbuffer:load_data(table.concat(data)))

	-- compare to dumped data
	local dump_data = drawbuffer:dump_data()
	local x,y = 0,0
	for i=0, (#dump_data/4)-1 do
		local j = i*4+1
		local r,g,b,a = dump_data:byte(j,j+3)
		if (x==y) then
			lu.assertEquals({r,g,b,a}, {63,127,255,255})
		else
			lu.assertEquals({r,g,b,a}, {0,0,0,0})
		end
		x = x + 1
		if x == drawbuffer:width() then
			x = 0; y = y + 1
		end
	end
end

function test_drawbuffer_set_px()
	-- test the set pixel function. (Not the alphablending function from ldb_gfx)
	-- TODO: this only works with px_fmt = "rgba8888"
	local ldb_core = require("ldb_core")
	local drawbuffer = ldb_core.new_drawbuffer(w,h,px_fmt)
	drawbuffer:clear(0,0,0,0)

	-- invalid set_px invocations should return nil
	-- value that is the color for invalid operations
	local d = 127
	lu.assertEvalToFalse(drawbuffer:set_px(-1,0, d,d,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(0,-1, d,d,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(drawbuffer:width(),0, d,d,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(0,drawbuffer:height(), d,d,d,d))

	lu.assertEvalToFalse(drawbuffer:set_px(1,1, 256,d,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(1,1, d,256,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(1,1, d,d,256,d))
	lu.assertEvalToFalse(drawbuffer:set_px(1,1, d,d,d,256))

	lu.assertEvalToFalse(drawbuffer:set_px(2,1, -256,d,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(2,1, d,-256,d,d))
	lu.assertEvalToFalse(drawbuffer:set_px(2,1, d,d,-256,d))
	lu.assertEvalToFalse(drawbuffer:set_px(2,1, d,d,d,-256))

	-- we shouldn't have changed any pixel values
	lu.assertEquals(drawbuffer:dump_data(), ("\0\0\0\0"):rep(w*h))

	-- draw a line in the drawbuffer using set_px
	for i=0, math.min(drawbuffer:width(), drawbuffer:height())-1 do
		lu.assertEvalToTrue(drawbuffer:set_px(i,i, 255,255,255,255))
	end

	-- check that the right pixels were affected by comparing to the :dump_data() output
	local dump_data = drawbuffer:dump_data()
	local x,y = 0,0
	local cmp_data = {}
	for i=0, (#dump_data/4)-1 do
		local j = i*4+1
		local r,g,b,a = dump_data:byte(j,j+3)
		if (x==y) then
			lu.assertEquals({r,g,b,a}, {255,255,255,255})
		else
			lu.assertEquals({r,g,b,a}, {0,0,0,0})
		end
		cmp_data[#cmp_data+1] = string.char(r)
		cmp_data[#cmp_data+1] = string.char(g)
		cmp_data[#cmp_data+1] = string.char(b)
		cmp_data[#cmp_data+1] = string.char(a)
		x = x + 1
		if x == drawbuffer:width() then
			x = 0; y = y + 1
		end
	end
	cmp_data = table.concat(cmp_data)
	lu.assertEquals(dump_data, cmp_data)
end

function test_drawbuffer_get_px()
	-- test the set pixel function. (Not the alphablending function from ldb_gfx)
	-- TODO: this only works with px_fmt = "rgba8888"
	local ldb_core = require("ldb_core")
	local drawbuffer = ldb_core.new_drawbuffer(w,h,px_fmt)


	-- invalid set_px invocations should return nil
	-- value that is the color for invalid operations
	lu.assertEvalToFalse(drawbuffer:get_px(-1,0))
	lu.assertEvalToFalse(drawbuffer:get_px(0,-1))
	lu.assertEvalToFalse(drawbuffer:get_px(drawbuffer:width(),0))
	lu.assertEvalToFalse(drawbuffer:get_px(0,drawbuffer:height()))

	-- simple set and get test
	lu.assertEvalToTrue(drawbuffer:set_px(0,0, 211,227,233,241))
	local r,g,b,a = drawbuffer:get_px(0,0)
	lu.assertEquals({r,g,b,a}, {211,227,233,241})

	-- draw a line in the drawbuffer using set_px
	for i=0, math.min(drawbuffer:width(), drawbuffer:height())-1 do
		lu.assertEvalToTrue(drawbuffer:set_px(i,i, 255,255,255,255))
	end

	-- check that get_px works as expected by comparing to
	-- the dump_data output(which is just a dump of the memory region)
	-- this also checks every valid coordinate
	local dump_data = drawbuffer:dump_data()
	local re_data = {}
	for y=0, drawbuffer:height()-1 do
		for x=0, drawbuffer:width()-1 do
			local r,g,b,a = drawbuffer:get_px(x,y)
			lu.assertTrue((r>=0) and (r<=255))
			lu.assertTrue((g>=0) and (g<=255))
			lu.assertTrue((b>=0) and (b<=255))
			lu.assertTrue((a>=0) and (a<=255))
			re_data[#re_data+1] = string.char(r)
			re_data[#re_data+1] = string.char(g)
			re_data[#re_data+1] = string.char(b)
			re_data[#re_data+1] = string.char(a)
		end
	end
	re_data = table.concat(re_data)
	lu.assertEquals(dump_data, re_data)
end


os.exit(lu.LuaUnit.run())
