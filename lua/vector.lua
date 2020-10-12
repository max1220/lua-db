--[[
# LuaJIT Vector library

This file implements some vector utillity functions, and multiple
conventions for using vector operations in Lua(mostly graphics/game programming).
It has been designed for best performance with LuaJIT and it's FFI library in mind.
Currently, only 2 or 3 component vectors are supported.


# Usage

```
local vec2 = vector2(type, metafunctions)
local vec3 = vector3(type, metafunctions)
```

type is a luajit ctype(can be a string like "double" or a userdata ctype reference; see LuaJIT FFI docs.)
metafunctions is a boolean(If enabled, arithmetic metamethods are available)

The vector2/vector3 functions return a FFI ctype that can be used to generate a new
vector variable(See LuaJIT FFI docs for initialization rules).

In general, most functions are available in 3 variants:

 * No prefix usually means the last argument is target, a vector in which the result is stored in.
   - `foo:add_v(bar, result)`
 * "l_"-prefix means the target argument is the first function argument.
   - `foo:l_add_v(bar)` is equal to `foo:add_v(bar, foo)`
 * "n_"-prefix means the target argument is a new vector of the same type, and that new vector is returned.
   - `local new = foo:n_add_v(bar)` is equal to `local new = vec3(); foo:add_v(bar, new)`
   - this is also the default for the metamethods, and allows for an easy chaining syntax
     * `local foo = vec3(0,0,0):n_add_v(1,2,3):n_mul_n(2)` is equal to `local foo = vec3(0,0,0) + vec3(1,2,3)*2`

As you can see the metamethod syntax is clean, but might create more new vectors than needed, hindering performance.
Vectors are (internally) always refered to by reference.


## Available functions

 * add_v,sub_v,add_n,sub_n,mul_n,mul_v,div,min_n,max_n,min_v,max_v,clamp,neg,zero,one,copy_to,len,normalize,abs,dotp,tostring,equals
 * l_neg,l_normalize,l_abs,l_add_v,l_sub_v,l_add_n,l_sub_n,l_mul_n,l_mul_v,l_div,l_min_n,l_max_n,l_min_v,l_max_v,l_clamp
 * n_neg,n_normalize,n_abs,n_add_v,n_sub_v,n_add_n,n_sub_n,n_mul_n,n_mul_v,n_div,n_min_n,n_max_n,n_min_v,n_max_v,n_clamp,n_copy,n_zero,n_one


## Examples

get a new vector type that uses float and supports metamethods(syntax sugar)

```
local vec3 = vector3("float", true)
```

create a new vector and initialize to 0,1,0
```
local dir = vec3(0,1,0)
```

normalize dir vector(All l_ prefixed functions store results in the vector before the ":"-invocation)
```
dir:l_normalize()
```

-- add dir to pos, store result in a new vector(newpos)
```
local newpos = vec3()
pos:add_v(dir, newpos)
```

the meta-methods always wrap the n_ prefixed functions (creates a new vector for the result)
```
local newpos = pos + dir -- this is the same as the above example

```



]]

-- TODO: Fallback version that works without LuaJIT(maybe only need compatible FFI library for PUC Lua?)
-- TODO: matrix operations?
-- TODO: generic version fort n-vectors?
-- TODO: test assumed lower overhead of wrapping functions
-- TODO: create proper benchmark + analysis tools(support luajit profiler, compare bytecode, etc.)

local ffi = require("ffi")



local function get_nwrap(type_cb)
	local function nwrap0(fn)
		return function()
			local type = type_cb()
			local target = type()
			fn(target)
			return target
		end
	end

	local function nwrap1(fn)
		return function(a)
			local type = type_cb()
			local target = type()
			fn(a, target)
			return target
		end
	end

	local function nwrap2(fn)
		return function(a,b)
			local type = type_cb()
			local target = type()
			fn(a, b, target)
			return target
		end
	end

	local function nwrap3(fn)
		return function(a,b,c)
			local type = type_cb()
			local target = type()
			fn(a, b, c, target)
			return target
		end
	end

	return nwrap0, nwrap1, nwrap2, nwrap3
end

-- TODO: benchmark lwrap vs raw
local function get_lwrap()
	local function lwrap1(fn)
		return function(a)
			fn(a, a)
			return a
		end
	end

	local function lwrap2(fn)
		return function(a,b)
			fn(a, b, a)
			return a
		end
	end

	local function lwrap3(fn)
		return function(a,b,c)
			fn(a, b, c, a)
			return a
		end
	end

	return lwrap1, lwrap2, lwrap3
end


local function vector2(ctype, metafunctions)
	ctype = ctype or "float"

	ffi.cdef("struct __attribute__(( aligned(16) )) vec2_ct { __attribute__(( packed )) " .. ctype .." x, y; };")

	-- for all vector functions:
	--  v/v1/v2 argument is a vector argument
	--  n is a numeric argument
	--  target argument is where a vector result is stored

	local function v2_add_v2(v1,v2,target)
		target.x = v1.x+v2.x
		target.y = v1.y+v2.y
	end

	local function v2_sub_v2(v1,v2,target)
		target.x = v1.x-v2.x
		target.y = v1.y-v2.y
	end

	local function v2_add_n(v1,n,target)
		target.x = v1.x+n
		target.y = v1.y+n
	end

	local function v2_sub_n(v1,n,target)
		target.x = v1.x-n
		target.y = v1.y-n
	end

	local function v2_mul_n(v,n,target)
		target.x = v.x*n
		target.y = v.y*n
	end

	local function v2_mul_v2(v1,v2,target)
		target.x = v1.x*v2.x
		target.y = v1.y*v2.y
	end

	local function v2_div(v,n,target)
		target.x = v.x/n
		target.y = v.y/n
	end

	local _min = math.min
	local function v2_min_n(v,n,target)
		target.x = _min(v.x,n)
		target.y = _min(v.y,n)
	end

	local _max = math.max
	local function v2_max_n(v,n,target)
		target.x = _max(v.x,n)
		target.y = _max(v.y,n)
	end

	local function v2_min_v(v1,v2,target)
		target.x = _min(v1.x,v2.x)
		target.y = _min(v1.y,v2.y)
	end

	local function v2_max_v(v1,v2,target)
		target.x = _max(v1.x,v2.x)
		target.y = _max(v1.y,v2.y)
	end

	local function v2_clamp(v,min,max,target)
		target.x = _min(_max(v.x,min),max)
		target.y = _min(_max(v.y,min),max)
	end

	local function v2_neg(v,target)
		target.x = -v.x
		target.y = -v.y
	end

	local function v2_copy_to(v,target)
		target.x = v.x
		target.y = v.y
	end

	local function v2_zero(target)
		target.x = 0
		target.y = 0
	end

	local function v2_one(target)
		target.x = 1
		target.y = 1
	end

	local _sqrt = math.sqrt
	local function v2_len(v)
		return _sqrt(v.x^2+v.y^2)
	end

	local function v2_normalize(v,target)
		local mag = v2_len(v)
		target.x = v.x/mag
		target.y = v.y/mag
	end

	local _abs = math.abs
	local function v2_abs(v,target)
		target.x = _abs(v.x)
		target.y = _abs(v.y)
	end

	local function v2_dotp(v1,v2)
		return v1.x*v2.x+v1.y*v2.y
	end

	local function v2_tostring(v)
		return "vec2 ("..v.x..", "..v.y..")"
	end

	local function v2_equals(v1,v2)
		return (v1.x==v2.x) and (v1.y==v2.y)
	end


	local vec2_type
	-- these function wrapper utillity functions are used to get versions of a function with a fixed argument
	-- return functions with the target-argument set to a new vector
	local nwrap0, nwrap1, nwrap2, nwrap3 = get_nwrap(function() return vec2_type end)
	-- return functions with the target-argument set to the first argument(modify in place)
	local lwrap1, lwrap2, lwrap3 = get_lwrap()

	-- list of functions. If the function has a vector result, it's saved in the last argument(target)
	local vec2_funcs = {
		add_v = v2_add_v2,
		sub_v = v2_sub_v2,
		add_n = v2_add_n,
		sub_n = v2_sub_n,
		mul_n = v2_mul_n,
		mul_v = v2_mul_v2,
		div = v2_div,
		min_n = v2_min_n,
		max_n = v2_max_n,
		min_v = v2_min_v,
		max_v = v2_max_v,
		clamp = v2_clamp,
		neg = v2_neg,
		zero = v2_zero,
		one = v2_one,
		copy_to = v2_copy_to,
		len = v2_len,
		normalize = v2_normalize,
		abs = v2_abs,
		dotp = v2_dotp,
		tostring = v2_tostring,
		equals = v2_equals,

		-- list of left argument wrapped functions. target is first argument
		-- (e.g. l_add_v(a,b) calls add_v(a,b,a))
		l_neg = lwrap1(v2_neg),
		l_normalize = lwrap1(v2_normalize),
		l_abs = lwrap1(v2_abs),
		l_add_v = lwrap2(v2_add_v2),
		l_sub_v = lwrap2(v2_sub_v2),
		l_add_n = lwrap2(v2_add_n),
		l_sub_n = lwrap2(v2_sub_n),
		l_mul_n = lwrap2(v2_mul_n),
		l_mul_v = lwrap2(v2_mul_v2),
		l_div = lwrap2(v2_div),
		l_min_n = lwrap2(v2_min_n),
		l_max_n = lwrap2(v2_max_n),
		l_min_v = lwrap2(v2_min_v),
		l_max_v = lwrap2(v2_max_v),
		l_clamp = lwrap3(v2_clamp),

		-- list of new vector wrapped functions. target us always a new vector
		-- (warning: might be slow due to GC)
		-- (e.g. "n_add_v(a,b)" is equal to "v=vec3();add_v(a,b,v);return v;")
		n_neg = nwrap1(v2_neg),
		n_normalize = nwrap1(v2_normalize),
		n_abs = nwrap1(v2_abs),
		n_add_v = nwrap2(v2_add_v2),
		n_sub_v = nwrap2(v2_sub_v2),
		n_add_n = nwrap2(v2_add_n),
		n_sub_n = nwrap2(v2_sub_n),
		n_mul_n = nwrap2(v2_mul_n),
		n_mul_v = nwrap2(v2_mul_v2),
		n_div = nwrap2(v2_div),
		n_min_n = nwrap2(v2_min_n),
		n_max_n = nwrap2(v2_max_n),
		n_min_v = nwrap2(v2_min_v),
		n_max_v = nwrap2(v2_max_v),
		n_clamp = nwrap3(v2_clamp),

		n_copy = nwrap1(v2_copy_to),
		n_zero = nwrap0(v2_zero),
		n_one = nwrap0(v2_one),
	}

	-- optional meta-methods for the vector
	local __add, __sub, __mul, __div, __unm, __len
	if metafunctions then
		__add = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v2_add_n(a,b,vec2_type())
			elseif b.is_vec3 then
				return v2_add_v2(a,b,vec2_type())
			end
		end

		__sub = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v2_sub_n(a,b,vec2_type())
			elseif b.is_vec3 then
				return v2_sub_v2(a,b,vec2_type())
			end
		end

		__mul = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v2_mul_n(a,b,vec2_type())
			elseif b.is_vec3 then
				return v2_dotp(a,b)
			end
		end

		__div = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v2_div(a,b,vec2_type())
			end
		end

		__unm = function(a)
			return v2_neg(a, vec2_type())
		end

		__len = function(a)
			return v2_len(a)
		end
	end

	-- create metatable for type(can't be changed after the ffi.metatype call)
	local vec2_mt = {
		__index = {
			is_vec = true,
			is_vec2 = true,
		},
		__tostring = v2_tostring, -- always included meta-methods
		__eq = v2_equals,
		__add = __add, __sub = __sub, -- optional meta-methods
		__mul = __mul, __div = __div,
		__unm = __unm, __len = __len
	}

	-- add functions to metatype
	for k,v in pairs(vec2_funcs) do
		vec2_mt.__index[k] = v
	end

	-- create metatype
	vec2_type = ffi.metatype("struct vec2_ct", vec2_mt)

	-- return metatype and function list
	return vec2_type, vec2_funcs
end


local function vector3(ctype, metafunctions)
	ctype = ctype or "float"

	ffi.cdef("struct __attribute__(( aligned(16) )) vec3_ct { __attribute__(( packed )) " .. ctype .." x, y, z; };")

	-- for all vector functions:
	--  v/v1/v2 argument is a vector argument
	--  n is a numeric argument
	--  target argument is where a vector result is stored

	local function v3_add_v3(v1,v2,target)
		target.x = v1.x+v2.x
		target.y = v1.y+v2.y
		target.z = v1.z+v2.z
	end

	local function v3_sub_v3(v1,v2,target)
		target.x = v1.x-v2.x
		target.y = v1.y-v2.y
		target.z = v1.z-v2.z
	end

	local function v3_add_n(v1,n,target)
		target.x = v1.x+n
		target.y = v1.y+n
		target.z = v1.z+n
	end

	local function v3_sub_n(v1,n,target)
		target.x = v1.x-n
		target.y = v1.y-n
		target.z = v1.z-n
	end

	local function v3_mul_n(v,n,target)
		target.x = v.x*n
		target.y = v.y*n
		target.z = v.z*n
	end

	local function v3_mul_v3(v1,v2,target)
		target.x = v1.x*v2.x
		target.y = v1.y*v2.y
		target.z = v1.z*v2.z
	end

	local function v3_div(v,n,target)
		target.x = v.x/n
		target.y = v.y/n
		target.z = v.z/n
	end

	local _min = math.min
	local function v3_min_n(v,n,target)
		target.x = _min(v.x,n)
		target.y = _min(v.y,n)
		target.z = _min(v.z,n)
	end

	local _max = math.max
	local function v3_max_n(v,n,target)
		target.x = _max(v.x,n)
		target.y = _max(v.y,n)
		target.z = _max(v.z,n)
	end

	local function v3_min_v(v1,v2,target)
		target.x = _min(v1.x,v2.x)
		target.y = _min(v1.y,v2.y)
		target.z = _min(v1.z,v2.z)
	end

	local function v3_max_v(v1,v2,target)
		target.x = _max(v1.x,v2.x)
		target.y = _max(v1.y,v2.y)
		target.z = _max(v1.z,v2.z)
	end

	local function v3_clamp(v,min,max,target)
		target.x = _min(_max(v.x,min),max)
		target.y = _min(_max(v.y,min),max)
		target.z = _min(_max(v.z,min),max)
	end

	local function v3_neg(v,target)
		target.x = -v.x
		target.y = -v.y
		target.z = -v.z
	end

	local function v3_copy_to(v,target)
		target.x = v.x
		target.y = v.y
		target.z = v.z
	end

	local function v3_zero(target)
		target.x = 0
		target.y = 0
		target.z = 0
	end

	local function v3_one(target)
		target.x = 1
		target.y = 1
		target.z = 1
	end

	local _sqrt = math.sqrt
	local function v3_len(v)
		return _sqrt(v.x^2+v.y^2+v.z^2)
	end

	local function v3_normalize(v,target)
		local mag = v3_len(v)
		target.x = v.x/mag
		target.y = v.y/mag
		target.z = v.z/mag
	end

	local _abs = math.abs
	local function v3_abs(v,target)
		target.x = _abs(v.x)
		target.y = _abs(v.y)
		target.z = _abs(v.z)
	end

	local function v3_dotp(v1,v2)
		return v1.x*v2.x+v1.y*v2.y+v1.z*v2.z
	end

	local function v3_tostring(v)
		return "vec3 ("..v.x..", "..v.y..", "..v.z..")"
	end

	local function v3_equals(v1,v2)
		return (v1.x==v2.x) and (v1.y==v2.y) and (v1.z==v2.z)
	end

	local vec3_type
	-- these function wrapper utillity functions are used to get versions of a function with a fixed argument
	-- return functions with the target-argument set to a new vector
	local nwrap0, nwrap1, nwrap2, nwrap3 = get_nwrap(function() return vec3_type end)
	-- return functions with the target-argument set to the first argument(modify in place)
	local lwrap1, lwrap2, lwrap3 = get_lwrap()

	-- list of functions. If the function has a vector result, it's saved in the last argument(target)
	local vec3_funcs = {
		add_v = v3_add_v3,
		sub_v = v3_sub_v3,
		add_n = v3_add_n,
		sub_n = v3_sub_n,
		mul_n = v3_mul_n,
		mul_v = v3_mul_v3,
		div = v3_div,
		min_n = v3_min_n,
		max_n = v3_max_n,
		min_v = v3_min_v,
		max_v = v3_max_v,
		clamp = v3_clamp,
		neg = v3_neg,
		zero = v3_zero,
		one = v3_one,
		copy_to = v3_copy_to,
		len = v3_len,
		normalize = v3_normalize,
		abs = v3_abs,
		dotp = v3_dotp,
		tostring = v3_tostring,
		equals = v3_equals,

		-- list of left argument wrapped functions. target is first argument
		-- (e.g. l_add_v(a,b) calls add_v(a,b,a))
		l_neg = lwrap1(v3_neg),
		l_normalize = lwrap1(v3_normalize),
		l_abs = lwrap1(v3_abs),
		l_add_v = lwrap2(v3_add_v3),
		l_sub_v = lwrap2(v3_sub_v3),
		l_add_n = lwrap2(v3_add_n),
		l_sub_n = lwrap2(v3_sub_n),
		l_mul_n = lwrap2(v3_mul_n),
		l_mul_v = lwrap2(v3_mul_v3),
		l_div = lwrap2(v3_div),
		l_min_n = lwrap2(v3_min_n),
		l_max_n = lwrap2(v3_max_n),
		l_min_v = lwrap2(v3_min_v),
		l_max_v = lwrap2(v3_max_v),
		l_clamp = lwrap3(v3_clamp),

		-- list of new vector wrapped functions. target us always a new vector
		-- (warning: might be slow due to GC)
		-- (e.g. "n_add_v(a,b)" is equal to "v=vec3();add_v(a,b,v);return v;")
		n_neg = nwrap1(v3_neg),
		n_normalize = nwrap1(v3_normalize),
		n_abs = nwrap1(v3_abs),
		n_add_v = nwrap2(v3_add_v3),
		n_sub_v = nwrap2(v3_sub_v3),
		n_add_n = nwrap2(v3_add_n),
		n_sub_n = nwrap2(v3_sub_n),
		n_mul_n = nwrap2(v3_mul_n),
		n_mul_v = nwrap2(v3_mul_v3),
		n_div = nwrap2(v3_div),
		n_min_n = nwrap2(v3_min_n),
		n_max_n = nwrap2(v3_max_n),
		n_min_v = nwrap2(v3_min_v),
		n_max_v = nwrap2(v3_max_v),
		n_clamp = nwrap3(v3_clamp),

		n_copy = nwrap1(v3_copy_to),
		n_zero = nwrap0(v3_zero),
		n_one = nwrap0(v3_one),
	}

	-- optional meta-methods for the vector
	local __add, __sub, __mul, __div, __unm, __len
	if metafunctions then
		__add = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v3_add_n(a,b,vec3_type())
			elseif b.is_vec3 then
				return v3_add_v3(a,b,vec3_type())
			end
		end

		__sub = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v3_sub_n(a,b,vec3_type())
			elseif b.is_vec3 then
				return v3_sub_v3(a,b,vec3_type())
			end
		end

		__mul = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v3_mul_n(a,b,vec3_type())
			elseif b.is_vec3 then
				return v3_dotp(a,b)
			end
		end

		__div = function(a,b)
			if (type(b)=="number") or (not b.is_vec3) then
				return v3_div(a,b,vec3_type())
			end
		end

		__unm = function(a)
			return v3_neg(a, vec3_type())
		end

		__len = function(a)
			return v3_len(a)
		end
	end

	-- create metatable for type(can't be changed after the ffi.metatype call)
	local vec3_mt = {
		__index = {
			is_vec = true,
			is_vec3 = true,
		},
		__tostring = v3_tostring, -- always included meta-methods
		__eq = v3_equals,
		__add = __add, __sub = __sub, -- optional meta-methods
		__mul = __mul, __div = __div,
		__unm = __unm, __len = __len
	}

	-- add functions to metatype
	for k,v in pairs(vec3_funcs) do
		vec3_mt.__index[k] = v
	end

	-- create metatype
	vec3_type = ffi.metatype("struct vec3_ct", vec3_mt)

	-- return metatype and function list
	return vec3_type, vec3_funcs
end


return {
	vector2 = vector2,
	vector3 = vector3
}
