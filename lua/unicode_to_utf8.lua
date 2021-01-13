-- Safe utillity function for turning a unicode codepoint into a utf-8 sequence.
-- Uses Lua internal utf8 library when supported, external library if available
-- and working as expected, or a pure-lua version that should work everywhere.

local function unicode_to_utf8(c)
	assert((55296 > c or c > 57343) and c < 1114112, "Bad Unicode code point: "..tostring(c)..".")
	if c < 128 then
		return string.char(c)
	elseif c < 2048 then
		return string.char(192 + c/64, 128 + c%64)
	elseif c < 55296 or 57343 < c and c < 65536 then
		return string.char(224 + c/4096, 128 + c/64%64, 128 + c%64)
	elseif c < 1114112 then
		return string.char(240 + c/262144, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
	end
end

-- prefer the native UTF8 facillity in Lua 5.3
if utf8 then
	unicode_to_utf8 = utf8.char
elseif pcall(require, "utf8") then -- also allow compatible external UTF-8 module
	local _unicode_to_utf8 = require("utf8").char
	if _unicode_to_utf8(0x2588)=="█" then
		unicode_to_utf8 = _unicode_to_utf8
	end
end

return unicode_to_utf8
