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

-- decode a string argument. e.g.: --foo=test, --foo="hello world"
function args_parse.get_arg_str(args, arg_name, default)
	local normal_pattern = "^%-%-"..arg_name.."=(.*)$"
	local quote_pattern = "^%-%-"..arg_name.."=\"(.*)\"$"
	for i,arg in ipairs(args) do
		local str = arg:match(quote_pattern) or arg:match(normal_pattern)
		if str then
			return str, i
		end
	end
	return default
end

-- helper to convert empty string to false
function args_parse.empty_str_to_false(str)
	return (str~="" and str)
end

-- helper function that automatically removes an argument once it has been matched
-- should work with: get_arg_num, get_arg_str, get_arg_flag
function args_parse.remove_if_match(fn, args, ...)
	local ret, match_i = fn(args, ...)
	if match_i and tonumber(match_i) then
		table.remove(args, match_i)
	end
	return ret, match_i
end

-- decode a numeric argument. e.g.: --foo=123, foo=0xCAFE
function args_parse.get_arg_num(args, arg_name, default)
	local num_pattern = "^%-%-"..arg_name.."=(.*)$"
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

--get list of loose arguments(starting without --)
function args_parse.get_loose_args(args)
	local loose = {}
	for _,arg_str in ipairs(args) do
		if not arg_str:match("^%-%-") then
			table.insert(loose, arg_str)
		end
	end
	if #loose > 0 then
		return loose
	end
end

function args_parse.terminate(reason)
	-- reset the terminal colors, print red message, and stop
	io.stderr:write("\027[0m\027[31m", reason, "\027[0m\n")
	os.exit(1)
end

-- utillity function to return a simple logger function with a log level that can be specified in the arguments
-- lua usage:
--local log,logf = args_parse.logger_from_args(args, "error", "warning", "info", "debug")
--logf("info", "Hello world at unix timestamp: %d!", os.time())
-- supported arguments:
--log=stderr				# set default log type to stderrr
--log=file.txt				# set default log output to file.txt
--log=disabled				# disable all log output(unless enabled)
--log_append				# append to the default log
--log_error=stderr			# log error log level to stderr
--log_warning=stdout		# log warning log level to stdout
--log_debug=debug.txt		# log debug log level to file debug.txt
--log_debug_append			# append to log debug log file
--no_log_info				# disable info log level
--log_debug2				# enable debug2 log level
function args_parse.logger_from_args(args, ...)
	local default_log_type_str = args_parse.empty_str_to_false(args_parse.get_arg_str(args, "log"))
	local default_log_file = io.stderr
	if default_log_type_str == "stderr" then
		default_log_file = io.stderr
	elseif default_log_type_str == "stdout" then
		default_log_file = io.stdout
	elseif default_log_type_str and (default_log_type_str~="disabled") then
		local append = args_parse.get_arg_flag(args, "default_log_append")
		local file = io.open(default_log_type_str, (append and "a") or "w")
		if not file then
			return args_parse.terminate("Invalid log type or can't open file:", default_log_type_str)
		end
		default_log_file = file
	end

	local log_levels = {}
	for i, log_level in ipairs({...}) do
		local log_entry = {name=log_level, enabled=not (default_log_type_str=="disabled"), file=default_log_file}
		log_levels[i] = log_entry
		log_levels[log_level] = log_entry
	end

	for _,log_entry in ipairs(log_levels) do
		local log_type_str = args_parse.empty_str_to_false(args_parse.get_arg_str(args, "log_"..log_entry.name))
		if log_type_str=="stderr" then
			log_entry.file = io.stderr
		elseif log_type_str=="stdout" then
			log_entry.file = io.stdout
		elseif log_type_str=="disabled" then
			log_entry.enabled = false
		elseif log_type_str then
			local append = args_parse.get_arg_flag(args, "log_"..log_entry.name.."_append")
			local file = io.open(log_type_str, (append and "a") or "w")
			if not file then
				return args_parse.terminate("Invalid log type or can't open file:", log_type_str)
			end
			log_entry.file = file
		end
		local log_bool = args_parse.get_arg_flag(args, "log_"..log_entry.name)
		if log_bool ~= nil then
			log_entry.enabled = log_bool
		end
	end

	local function log(log_level, ...)
		local log_fmt = "[%s %s]:\t %s\n"
		local date_fmt = "%H:%M:%S"
		local log_entry = assert(log_levels[log_level], "Bad log level specified")
		local arg_str = {}
		for _,arg in pairs({...}) do
			arg_str[#arg_str+1] = tostring(arg)
		end
		arg_str = table.concat(arg_str, "\t")
		if log_entry.enabled then
			log_entry.file:write(log_fmt:format(log_entry.name, os.date(date_fmt), arg_str))
		end
		return arg_str
	end
	local function logf(log_level, fmt, ...)
		return log(log_level, fmt:format(...))
	end
	return log,logf,log_levels
end

return args_parse
