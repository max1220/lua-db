-- Uses Lua internal utf8 library when supported, external library if available
-- Safe utillity function for turning a unicode codepoint into a utf-8 sequence.
-- and working as expected, or a pure-lua version that should work everywhere.

-- Time library functions(gettime, gettime_monotonic, sleep) implemented using the LuaJIT FFI library
local function time_ffi()
	if not jit then
		return
	end
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
	enum {
		NS_IN_S = 1000000000
	};
	]])

	local t = assert(ffi.new("timespec_t"))
	local function gettime(clockid)
		return function()
			if ffi.C.clock_gettime(clockid, t)==0 then
				return tonumber(t.tv_sec) + (t.tv_nsec/ffi.C.NS_IN_S)
			end
		end
	end

	local function sleep(seconds)
		local secs_int = math.floor(seconds)
		local nsecs_int = math.floor((seconds - secs_int)*ffi.C.NS_IN_S)
		t.tv_sec = secs_int
		t.tv_nsec = nsecs_int
		ffi.C.nanosleep(t, nil)
	end

	return {
		gettime = gettime(ffi.C.CLOCK_REALTIME),
		gettime_monotonic = gettime(ffi.C.CLOCK_MONOTONIC_RAW),
		sleep = sleep,
	}
end

-- Time library functions implemented as a module
local function time_external()
	local ok, time_lib = pcall(require,"time")
	if (not ok) or (not (time_lib.realtime and time_lib.monotonic and time_lib.sleep)) then
		return -- no(incompatible) time library
	end

	return {
		gettime = time_lib.realtime,
		gettime_monotonic = time_lib.monotonic,
		sleep= time_lib.sleep,
	}
end


-- Use only Lua-internal functions(os.clock).
-- This has very low precision(1 second!), and uses a simple busy wait!
local function time_internal()
	io.stderr:write("Warning: Using lua internal time library with low precision!\n")
	local function sleep(dur)
		local start = os.time()
		while (os.time()-start) < dur do
			-- busy wait!
		end
	end
	return {
		gettime = os.time,
		gettime_monotonic = os.time,
		sleep = sleep,
	}
end


-- prefer ffi, then native, then internal
local time_lib = time_ffi() or time_external() or time_internal()
return time_lib, {
	-- also return a table that contains functions for using a specific implementation
	ffi = time_ffi,
	external = time_external,
	internal = time_internal,
}
