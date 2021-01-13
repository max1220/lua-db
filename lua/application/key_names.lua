-- this file defines the common key_names between different implementations

-- special keys(non-letters). All lower case, words seperated by underscore("_")
local special_key_names = {
	"left_ctrl",
	"left_alt",
	"left_gui",
	"space",
	"right_alt",
	"right_gui",
	"menu",
	"right_ctrl",
	"left_shift",
	"right_shift",
	"capslock",
	"return",
	"backspace",
	"tab",
	"escape",
	"up",
	"down",
	"left",
	"right",
	"delete",
	"end",
	"pagedown",
	"pageup",
	"home",
	"insert",
	"f1",
	"f2",
	"f3",
	"f4",
	"f5",
	"f6",
	"f7",
	"f8",
	"f9",
	"f10",
	"f11",
	"f12",
	"scrolllock",
	"pause"
}

-- letter are just lowercase, no prefix etc.(single characters)!
local letter_key_names = {}
for i=1, 26 do
	table.insert(letter_key_names, string.char(96+i))
end

-- combine all key names, make reverse lookup possible(index by key_name)
local all_key_names = {}
for k,v in ipairs(special_key_names) do
	table.insert(all_key_names, v)
	special_key_names[v] = k
	all_key_names[v] = "special"
end
for k,v in ipairs(letter_key_names) do
	table.insert(all_key_names, v)
	letter_key_names[v] = k
	all_key_names[v] = "letter"
end

-- return 3 tables
return all_key_names, special_key_names, letter_key_names
