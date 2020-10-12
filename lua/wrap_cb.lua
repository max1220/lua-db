-- Helper function to wrap a function in pcall/xpcall, and dump errors(and stacktrace if available) to stderr.
-- Returned function calls fn using pcall/xpcall(Returns nil on error, return values from fn otherwise).

local function pack(...)
	return {...}
end

-- catch errors in thread functions using xpcall
-- TODO: Generic form of this? Without hard-coded output to stderr
local function wrap_cb_xpcall(fn)
	return function(...)
		local ret = pack(xpcall(fn, function(err)
			io.stderr:write("\n\027[31m", ("-"):rep(80), "\n")
			io.stderr:write("xpcall error: ", tostring(err), "\n")
			io.stderr:write(debug.traceback(), "\n")
			io.stderr:write(("-"):rep(80), "\027[0m\n")
			io.stderr:flush()
		end, ...))
		local ok = table.remove(ret, 1)
		if ok then
			return unpack(ret)
		end
	end
end

-- catch errors in thread functions using pcall
local function wrap_cb_pcall(fn)
	return function(...)
		local ret = pack(pcall(fn, ...))
		local ok = table.remove(ret, 1)
		if not ok then
			io.stderr:write("\n\027[31m", ("-"):rep(80), "\n")
			io.stderr:write("pcall error: ", tostring(ret), "\n")
			io.stderr:write(("-"):rep(80), "\027[0m\n")
			io.stderr:flush()
			return
		end
		return unpack(ret)
	end
end

-- catch errors in thread functions using xpcall or pcall as fallback
local function wrap_cb(fn)
	if xpcall then
		return wrap_cb_xpcall(fn)
	else
		return wrap_cb_pcall(fn)
	end
end

return wrap_cb
