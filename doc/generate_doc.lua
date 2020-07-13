#!/usr/bin/env lua5.1
--[[
This script merges a document tree definition with it's content for export.

The documentation is split into two parts:
 * The content(typically markdown)
 * A document tree(Lua/JSON) that describes the structure of the documentation.
This script reads a document tree from a file, then generates output based on
that document tree. This script can merge the content files into a "flat"
representation, and auto-generate a (HTML-)menu and HTML anchors.

See generate_doc.md for more information.
]]



--[[
Markup-related functions.
item is an entry from the the document tree.
]]

-- return the name of a local page HTML anchor
local function item_to_anchor_id(item)
	return (item.title:gsub("%A", "_"))
end

-- return the complete HTML anchor to be referenced in the menu
local function generate_anchor(item)
	return ('<a name="%s"></a>'):format(item_to_anchor_id(item))
end

-- return a link to the external HTML page for this item
local function item_to_link(item)
	return item.file:gsub("(%.md)$", "%.html")
end

-- generate a markdown menu line that references a local HTML anchor
local function menu_entry_anchor(item)
	return " * " .. ('<a href="#%s">%s</a>'):format(item_to_anchor_id(item), item.title)
end

-- generate a markdown menu line that links to an external HTML page
local function menu_entry_link(item)
	return " * " .. ('<a href="%s">%s</a>'):format(item_to_link(item), item.title)
end

-- generate a markdown menu line without a link
local function menu_entry_plain(item)
	return " * " .. item.title
end





--[[
recursive functions for generating the merged document and menu from a document tree.
]]

-- generate the menu markdown for the specified document tree.
-- entry_for is a function that returns a markdown menu line for an item.
local generate_menu_markdown
generate_menu_markdown = function(tree, entry_for)
	local menu_markdown = {}
	for _,item in ipairs(tree) do
		if item.title then
			-- add a menu entry to the markdown
			local menu_entry = entry_for(item)
			table.insert(menu_markdown, menu_entry)
		end
		if item.children then
			-- recursivly add menu entries, indented by 2 spaces
			local _, submenu = generate_menu_markdown(item.children, entry_for)
			for _,summenu_item_str in ipairs(submenu) do
				table.insert(menu_markdown, "  " .. summenu_item_str)
			end
		end
	end
	return table.concat(menu_markdown, "\n"), menu_markdown
end

-- merge the document tree into a flat markdown document
local merge_markdown
merge_markdown = function(tree, anchor_for)
	local markdown = {}
	for _,item in ipairs(tree) do
		if anchor_for and item.title then
			-- generate a page anchor "reference point" in the document
			table.insert(markdown, anchor_for(item))
		end
		if item.file then
			local f = assert(io.open(item.file), "Can't open file specified in document tree: " .. tostring(item.file))
			local md = f:read("*a")
			f:close()
			table.insert(markdown, md)
		end
		if item.children then
			-- recursivly add content markdown
			local _, submds = merge_markdown(item.children, anchor_for)
			for _, submd in ipairs(submds) do
				table.insert(markdown, submd)
			end
		end
	end
	return table.concat(markdown, "\n\n\n"), markdown
end





--[[
Command-line parsing and output functions
]]

-- merge the content(no menu, no anchors)
local function mode_merge(tree)
	return merge_markdown(tree)
end

-- export a merged pure markdown document with an unclickable menu(no HTML)
local function mode_plain(tree)
	local menu = generate_menu_markdown(tree, menu_entry_plain)
	local content = merge_markdown(tree)
	return menu .. "\n\n\n" .. content
end

-- export markdown with HTML for local page anchors and a clickable HTML menu
local function mode_anchor(tree)
	local menu = generate_menu_markdown(tree, menu_entry_anchor)
	local content = merge_markdown(tree, generate_anchor)
	return menu .. "\n\n\n" .. content
end

-- export menu markdown with external links(no content)
local function mode_link(tree)
	local menu = generate_menu_markdown(tree, menu_entry_link)
	return menu
end

-- write a log message to stderr
local function log(...)
	io.stderr:write(table.concat({...}, "\t") .. "\n")
end

local function print_help()
	log("This script merges a document tree definition with it's content for export.")
	log()
	log("Usage:")
	log((arg[0] or "generate_doc.lua") .. " tree [output] [--merge/--plain/--html_anchor/--html_link] [--help]")
	log()
	log(" tree is the file path to a document tree in JSON or Lua format.")
	log(" output is the optional output file path(Default is stdout)")
	log(" --merge only merges the content(no menu, no anchors)")
	log(" --plain exports a merged pure markdown document with an unclickable menu(no HTML)")
	log(" --html_anchor exports markdown with HTML for local page anchors and a clickable HTML menu")
	log(" --html_menu only exports menu markdown with external links(no content)")
	log(" --help prints this message")
end

-- what to export
local mode

-- tree_path contains the file path for the document tree.
-- output_path contains the file path of an output file, or nil for stdout
local tree_path, output_path

-- parse command-line options
for _, arg_str in ipairs(arg) do
	if arg_str:match("^%-%-") then
		if mode then
			log("Can only set one mode!")
			print_help()
			os.exit(1)
		elseif arg_str == "--merge" then
			mode = mode_merge
		elseif arg_str == "--plain" then
			mode = mode_plain
		elseif arg_str == "--html_anchor" then
			mode = mode_anchor
		elseif arg_str == "--html_menu" then
			mode = mode_link
		elseif arg_str == "--help" then
			print_help()
			os.exit(0)
		else
			log("Unknown mode: " .. arg_str)
			print_help()
			os.exit(1)
		end
	elseif tree_path then
		output_path = arg_str
	else
		tree_path = arg_str
	end
end
if not tree_path then
	log("Missing document tree argument!")
	print_help()
	os.exit(1)
end
if not mode then
	mode = mode_merge
end

-- check document tree file exists
local tree_f = io.open(tree_path, "r")
if not tree_f then
	log("Can't open tree file: " .. tostring(tree_path))
	os.exit(2)
end
tree_f:close()

-- try to load the document tree
local document_tree
if tree_path:lower():match("%.json$") then
	-- load document tree in JSON format using any aviable JSON library
	local ok, json = pcall(require, "cjson")
	if not ok then
		local _ok, _json = pcall(require, "dkjson")
		if not _ok then
			log("Can't find cjson or dkjson lua module! Please donwload one of them.")
			log("e.g. 'wget \"https://raw.githubusercontent.com/LuaDist/dkjson/master/dkjson.lua\"'")
			os.exit(4)
		end
		json = _json
	end
	local f = io.open(tree_path, "r")
	local _ok, tree = pcall(json.decode(f:read("*a")))
	f:close()
	if not _ok then
		log("Can't decode document tree: ", tostring(tree))
		os.exit(5)
	end
	document_tree = tree
else
	-- load document tree in Lua format
	if not tree_path:lower():match("%.lua$") then
		log("Warning: Assuming Lua file format for document tree!")
	end
	local ok, tree = pcall(dofile, tree_path)
	if not ok then
		log("Can't parse document tree:", tostring(tree))
		os.exit(3)
	end
	document_tree = tree
end

local document = mode(document_tree)

-- export the generated document
if output_path then
	-- output to a file
	local f = io.open(output_path, "w")
	if not f then
		log("Can't open output file: " .. tostring(output_path))
		os.exit(6)
	end
	f:write(document)
	f:close()
else
	-- write to stdout
	io.write(document)
end
