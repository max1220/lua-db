#!/usr/bin/env luajit
local ffi = require("ffi")
ffi.cdef([[
enum {
	CLOCK_REALTIME,
	CLOCK_MONOTONIC,
	CLOCK_PROCESS_CPUTIME_ID,
	CLOCK_THREAD_CPUTIME_ID,
	CLOCK_MONOTONIC_RAW,
	CLOCK_REALTIME_COARSE,
	CLOCK_MONOTONIC_COARSE,
	CLOCK_BOOTTIME,
	CLOCK_REALTIME_ALARM,
	CLOCK_BOOTTIME_ALARM
};

typedef struct timespec {
	int64_t tv_sec;
	int32_t tv_nsec;
} timespec_t;

int clock_gettime(int32_t clockid, timespec_t* tp);
int nanosleep(timespec_t* req, timespec_t* rem);
double sqrt(double x);
float sqrtf(float x);
long double sqrtl(long double x);

enum {
	NS_IN_S = 1000000000
};
]])

local C = ffi.C

local _sqrt = math.sqrt
local function a(i)
	return tonumber(_sqrt(i))
end

local function b(i)
	return tonumber(ffi.C.sqrtf(i))
end

local function c(i)
	-- TODO: Figure out why this crashed luajit with a NYI
	--return tonumber(ffi.C.sqrtl(i))
	return 0
end

local function d(i)
	return tonumber(ffi.C.sqrt(i))
end

local _float_x = ffi.new("float")
local _int_x = ffi.new("int32_t")
local _void_ct = ffi.typeof("void*")
local _int_ct = ffi.typeof("int32_t")
local _rshift = bit.rshift
local function e(x)
	local xhalf = 0.5*x
	_float_x = x
	local i = ffi.cast(_int_ct, ffi.cast(_void_ct, _float_x))
	i = i - _rshift(i, 1)

	x = x * (1.5-(xhalf*x*x))
	return x
end


local t = assert(ffi.new("timespec_t"))
local function gettime()
	if C.clock_gettime(C.CLOCK_MONOTONIC_RAW, t)==0 then
		return tonumber(t.tv_sec) + (t.tv_nsec/C.NS_IN_S)
	end
end

local function test(iter, fn)
	local start = gettime()
	local sum = 0LL
	for i=1, iter do
		sum = sum + fn(i)
	end
	local dt = gettime()-start
	return dt
end

local function tests(iter, ...)
	local args = {...}
	local ret = {}
	for i=1, #args do
		collectgarbage()
		test(iter, args[i]) -- "warmup"
		ret[i] = test(iter, args[i])
	end
	return ret
end


local iter = 1000000000
if false then
	print(tonumber(test(iter, b)*1000) .. "ms")
else
	local results = tests(iter, a,b,c,d,e)
	print(iter .. " Iterations")
	for i,dt in ipairs(results) do
		print(("\t%s: %7.2fms %7.2fns/iter"):format(string.char(64+i), tonumber(dt*1000), tonumber(dt*1000000000)/iter))
	end
end
