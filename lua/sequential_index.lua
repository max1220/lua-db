-- This is a utillity function for running sequences of index operations on
-- a table.
-- This function is used to parse ANSI input key sequences, among other things.
-- callback() is a function that is called to get a indexes into the seq_table recursively.
-- Example:
--  seq_table = { foo = { bar = "Hello World!" } }
--  indexes = {"foo", "bar"}
--  function callback() return table.remove(indexes, 1) end
--  print(sequential_index(callback, seq_table))

-- It works like this:
-- Index seq_table by the return value of callback().
-- If no value was found, return nil.
-- If the value at that index is a function, call the function, and use it as the value.
-- If the value is now a table(and does not have a __noindex value), return:
--  recursively call sequential_index, replacing seq_table by the value.
-- Otherwise, if a non-table value was found, return it.
-- Always returns the last return value from callback() as 2nd return value
local function sequential_index(callback, seq_table, iterations)
	iterations = tonumber(iterations) or math.huge
	local key = callback()
	local value = seq_table[key]
	if type(value) == "function" then
		value = value(callback, key)
	end
	if (iterations>0) and (type(value) == "table") and (not value.__noindex) then
		-- we're in a sequence, get more indexes recursively(with maximum limit)
		return sequential_index(callback, value, iterations-1)
	elseif value then
		-- we resolved a sequence of indexes to a non-indexable value, return it!
		return value, key
	else
		-- we couldn't resolve an index(sequence was rejected)
		return nil, key
	end
end

return sequential_index
