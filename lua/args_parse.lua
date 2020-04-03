--[[
Utillity functions for handling command-line parameters.
They each take a list of possible arguments(like lua's arg table),
a name for the argument(without the -- prefix), and a default value.
If the argument is found, a value of the correct type(boolean, string or number),
and the index in the arg table is returned. If it's not found, the default value
(if any) is returned.
]]

local args_parse = {}

-- Decode a flag(boolean) argument. e.g.: --foo, --no_foo
function args_parse.get_arg_flag(args, arg_name, default)
	local flag_str = "--"..arg_name
	local no_flag_str = "--no_"..arg_name
	for i,arg in ipairs(args) do
		if arg==flag_str then
			return true, i
		elseif arg==no_flag_str then
			return false, i
		end
	end
	return default
end

-- decode a string argument. e.g.: --foo=test, foo="hello world"
function args_parse.get_arg_str(args, arg_name, default)
	local normal_pattern = "^--"..arg_name.."=(.*)$"
	local quote_pattern = "^--"..arg_name.."=\"(.*)\"$"
	for i,arg in ipairs(args) do
		local str = arg:match(quote_pattern) or arg:match(normal_pattern)
		if str then
			return str, i
		end
	end
	return default
end

-- decode a numeric argument. e.g.: --foo=123, foo=0xCAFE
function args_parse.get_arg_num(args, arg_name, default)
	local num_pattern = "^--"..arg_name.."=(.*)$"
	for i,arg in ipairs(args) do
		local num_str = arg:match(num_pattern)
		if num_str and (num_str:sub(1,2):lower()=="0x") and tonumber(num_str:sub(3), 16) then
			return tonumber(num_str:sub(3), 16), i
		elseif num_str and tonumber(num_str) then
			return tonumber(num_str), i
		end
	end
	return default
end

function args_parse.terminate(reason)
	-- reset the terminal colors, print red message, and stop
	io.stderr:write("\027[0m\027[31m", reason, "\027[0m\n")
	os.exit(1)
end

return args_parse
