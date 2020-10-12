#!/usr/bin/env luajit
-- simple benchmark script used for benchmarking the multithread_pixel_functions
-- arg[1] = json filename
-- arg[2] = csv filename
-- arg[3] = raw export file prefix
local args_parse = require("lua-db.args_parse")
local time = require("time")
local pixel_function = require("lua-db.pixel_function")


local callback_path = args_parse.get_arg_str(arg, "callback", "./examples/data/callback_basic.lua")
local json_export = args_parse.empty_str_to_false(args_parse.get_arg_str(arg, "json", "benchmark.json")) -- path to export the data to
local csv_export = args_parse.empty_str_to_false(args_parse.get_arg_str(arg, "csv")) -- if present, export csv to this path
local raw_export = args_parse.empty_str_to_false(args_parse.get_arg_str(arg, "raw")) -- if present, export raw frame dump for every resolution to this prefix("_" + resolution + ".raw" is appended)
local threads = args_parse.get_arg_num(arg, "threads") -- number of worker threads
local stride = args_parse.get_arg_num(arg, "stride", 32) -- lines to process at in the work loop
local res_step = args_parse.get_arg_num(arg, "res_step", 128) -- increase in resolution per step
local res_count = args_parse.get_arg_num(arg, "res_count", 20) -- step of resolution increase
local max_frame_eq_count = args_parse.get_arg_num(arg, "max_frame_eq_count", 100) -- how many maximum dimensions frames to render(Other resolutions are adjusted to same pixel count by increasing number of frames rendered)
local method = args_parse.get_arg_str(arg, "method","simple")
if not ((method == "simple") or (method == "ffi") or (method == "ffi_shared_buf")) then
	error("Unknown method selected:" .. method)
end

local log,logf = args_parse.logger_from_args(arg, "info","warn","err","debug")

local function per_worker_simple(w,h,bpp,worker_arg)
	local per_pixel_callback,per_frame_callback = dofile(callback_path)(w,h)
	local state = {t=0,dt=1/30} -- TODO
	local function per_frame_cb(seq)
		if per_frame_callback then
			return per_frame_callback(seq,state)
		end
	end
	local _min,_max,_floor,_char = math.min,math.max,math.floor,string.char
	local function per_pixel_cb(x,y,buf,i,per_frame)
		local r,g,b = per_pixel_callback(x,y,per_frame)
		r = _max(_min(_floor(r),255),0)
		g = _max(_min(_floor(g),255),0)
		b = _max(_min(_floor(b),255),0)
		buf[i] = _char(r,g,b)
	end
	return per_pixel_cb,per_frame_cb
end


local function per_worker_ffi(w,h,bpp,stride,ffi,worker_arg)
	local per_pixel_callback,per_frame_callback = dofile(callback_path)(w,h)
	local state = {t=0,dt=1/30}
	local function per_frame_cb(seq)
		if per_frame_callback then
			return per_frame_callback(seq, state)
		end
	end
	local function per_pixel_cb(x,y,buf,i,per_frame)
		local r,g,b = per_pixel_callback(x,y,per_frame)
		buf[i+0] = r
		buf[i+1] = g
		buf[i+2] = b
	end
	return per_pixel_cb,per_frame_cb
end





local data = {}
local function run_test(w,h,frame_count)
	local bpp = 3
	local renderer
	if method == "simple" then
		renderer = pixel_function.multithread_pixel_function_simple(w,h,bpp,threads,per_worker_simple)
	elseif method == "ffi" then
		renderer = pixel_function.multithread_pixel_function_ffi(w,h,bpp,threads,stride,per_worker_ffi)
	elseif method == "ffi_shared_buf" then
		renderer = pixel_function.multithread_pixel_function_ffi_shared_buf(w,h,bpp,threads,stride,per_worker_ffi, true)
	end
	renderer.start() -- start worker/collector threads

	if raw_export then -- export a rendered image
		local file = assert(io.open(raw_export .. "_" .. w .. ".raw", "w"))
		local raw = renderer.render()
		file:write(raw)
	else -- warmup(always render a single frame before the benchmark)
		renderer.render()
	end

	collectgarbage("collect") -- make sure we're not benchmarking against the Lua GC
	local start_mem = collectgarbage("count")
	local min,max,total = math.huge, 0, 0
	for _=1, frame_count do
		local start = time.monotonic()
		--renderer.render(true)
		renderer.send_requests() -- request a new frame
		renderer.get_frame() -- get resulting grame, blocking
		local stop = time.monotonic()
		local dt = stop-start
		min = math.min(min, dt)
		max = math.max(max, dt)
		total = total + dt
	end
	local avg = total/frame_count

	local dmem = collectgarbage("count")-start_mem
	local per_px = (total/(w*h*frame_count))
	local mb = (w*h*3*frame_count)/1000000
	local mb_per_second = mb/total

	logf("info","resolution=%4dx%4d frame_count=%8d took %8.2fms: %8.2f MB/s, min=%8.2fms avg=%8.2fms max=%8.2fms, per_px=%fus mem=%dkb",
			w,h, frame_count, total*1000, mb_per_second, min*1000, avg*1000, max*1000, per_px*1000*1000, dmem)

	if json_export or csv_export then
		local data_entry = {
			w = w,
			h = h,
			frame_count = frame_count,
			total = total,
			min = min,
			avg = avg,
			max = max,
			per_px = per_px,
			dmem = dmem,
			mb = mb,
			mb_per_second = mb_per_second,
		}
		table.insert(data, data_entry)
	end
end


-- run benchmark
local max_d = res_step*res_count -- resulting maximum dimension
logf("info","Starting benchmark")
for i=1, res_count do
	-- smaller resolutions have the frame count adjusted to equal pixel count
	local d = i*res_step
	local frame_count = max_frame_eq_count*(1/((d*d)/(max_d*max_d)))
	run_test(d,d,frame_count)
	collectgarbage("collect")
end


if json_export then -- export JSON
	logf("info","Exporting JSON to %q", json_export)
	local json = require("cjson")
	local file = assert(io.open(json_export, "w"))
	file:write(json.encode(data))
end

if csv_export then -- export CSV
	logf("info","Exporting CSV to %q", csv_export)
	local file = assert(io.open(csv_export, "w"))
	file:write("w,h,frame_count,total,min,avg,max,per_px,dmem\n")
	for _, v in ipairs(data) do
		file:write(table.concat({v.w,v.h,v.frame_count,v.total,v.min,v.avg,v.max,v.per_px,v.dmem}, ","),"\n")
	end
end

logf("info","End benchmark")
