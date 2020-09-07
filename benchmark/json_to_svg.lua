#!/usr/bin/env luajit
local args_parse = require("lua-db.args_parse")
local json = require("cjson")

local function new_xml_doc()
	local doc = {}

	doc.cursor = {doc}
	function doc.cursor:leave()
		return (#self.cursor>1) and table.remove(self, 1)
	end
	function doc.cursor:enter(i)
		table.insert(self, (i>0) and self[1][i] or self[1][#self[1]+i-1], 1)
	end
	function doc.cursor:add(e,i)
		return self[1]:add(e,i)
	end

	local function tag_str(e)
		local tag_name = e.tag[1]
		local str = {}
		if type(e.tag[2]) == "table" then
			for k,v in pairs(e.tag[2]) do
				table.insert(str, k.."=\""..v.."\"")
			end
			table.sort(str)
		else
			for i=2, #e.tag do
				table.insert(str, tostring(e.tag[i]))
			end
		end
		table.insert(str, 1, tag_name)
		return table.concat(str, " ")
	end
	local function add_methods(p,e)
		e.add = e.add or p.add
		e.tostring = e.tostring or p.tostring
		for _,v in ipairs(e) do
			if type(v) == "table" then
				add_methods(e, v)
			end
		end
	end
	function doc:add(e,i)
		i = (tonumber(i) and (i<0)) and (#self+i-1) or (i or #self+1)
		table.insert(self,i,e)
		if type(e) == "table" then
			add_methods(self, e)
		end
		return e
	end
	function doc:tostring(_e, _level)
		local level = _level or 0
		local indent = ("\t"):rep(level)
		local str_data = {}
		local this_e = _e or self
		for i=1, #this_e do
			local loop_e = this_e[i]
			local do_end_tag = loop_e.end_tag or (#loop_e > 0)
			if type(loop_e) == "string" then
				table.insert(str_data, indent..loop_e)
			elseif (type(loop_e) == "table") and loop_e.tag then
				table.insert(str_data, indent.."<"..tag_str(loop_e)..(do_end_tag and ">" or " />"))
				if #loop_e > 0 then -- append children elements
					table.insert(str_data, loop_e:tostring(loop_e, level+1))
				end
				if do_end_tag then -- add end tag
					table.insert(str_data, indent.."</"..loop_e.tag[1]..">")
				end
			end
		end
		return table.concat(str_data, "\n")
	end

	return doc
end

local w = args_parse.get_arg_num(arg, "width", 800)
local h = args_parse.get_arg_num(arg, "height", 800)
local xvar = args_parse.get_arg_str(arg, "xvar", "w")
local yvar = args_parse.get_arg_str(arg, "yvar", "avg")

local xformat = args_parse.get_arg_str(arg, "xformat", "%dpx")
local yformat = args_parse.get_arg_str(arg, "yformat", "%.2fs")
local xunit = args_parse.get_arg_num(arg, "xunit", 1)
local yunit = args_parse.get_arg_num(arg, "yunit", 1)

local xgrid = args_parse.get_arg_flag(arg, "xgrid", true)
local ygrid = args_parse.get_arg_flag(arg, "ygrid", true)


local json_files = assert(args_parse.get_loose_args(arg))

--local w,h = 800,800
local min_wh = math.min(w,h)
local border_pct = 0.15
local border_px = min_wh*border_pct
local seg_pct = 0.01
local seg_px = min_wh*seg_pct
--local xvar,yvar = "w","avg"
--local xformat,yformat = "%dpx","%.2fs"
--local xunit,yunit = 1,1



local svg_doc = new_xml_doc()
local root = svg_doc:add({
	tag = {"svg", {
		version = "1.1",
		baseProfile = "tiny",
		xmlns = "http://www.w3.org/2000/svg",
		["xmlns:xlink"] = "http://www.w3.org/1999/xlink",
		--width = "100%",
		--height = "100%",
		viewBox = "0 0 " .. w .. " " .. h
	}},
	{
		tag = {"rect", {x=0,y=0,width=w,height=h,fill="#f0f0f0"}}
	},
	{
		tag = {"rect", {x=border_px,y=border_px,width=w-2*border_px,height=h-2*border_px,fill="#ffffff"}}
	}
})

local function add_xaxis(x_axis_marker)
	local x_axis = root:add({ tag = {"g", { id="x_axis" }} })
	for i=1, #x_axis_marker do
		local x_pct = ((i-1)/(#x_axis_marker-1))
		local x = (x_pct*(w-2*border_px))+border_px
		if xgrid and (i~=1) and (i~=#x_axis_marker) then
			x_axis:add({ tag = {"line", { x1=x, y1=h-border_px, x2=x, y2=border_px, stroke="#eee" } } })
		end
		if i~=1 then
			x_axis:add({ tag = {"line", { x1=x, y1=h-border_px-seg_px, x2=x, y2=h-border_px+seg_px, stroke="#aaa" }}, })
		end
		local text_y = h-border_px*0.5+4
		local text = x_axis:add({ tag = {"text", { x=x, y=text_y, ["font-size"]=14, fill="#666", ["text-anchor"]="middle", transform="rotate(80 "..x..","..text_y..")" }} })
		text:add(tostring(x_axis_marker[i]))
	end
	x_axis:add({ tag = {'line', {x1=border_px, y1=h-border_px, x2=w-border_px, y2=h-border_px, stroke="#000"}}, })
end

local function add_yaxis(y_axis_marker)
	local y_axis = root:add({ tag = {"g", { id="y_axis" }} })
	for i=1, #y_axis_marker do
		local y_pct = 1-((i-1)/(#y_axis_marker-1))
		local y = (y_pct*(1-2*border_pct)+border_pct)*h
		if ygrid and (i~=1) and (i~=#y_axis_marker) then
			y_axis:add({ tag = {"line", { x1=border_px, y1=y, x2=w-border_px, y2=y, stroke="#eee" }} })
		end
		if i ~= 1 then
			y_axis:add({ tag = {"line", { x1=border_px-seg_px, y1=y, x2=border_px+seg_px, y2=y, stroke="#aaa" }}, })
		end
		local text = y_axis:add({ tag = {"text", { x=border_px*0.5, y=y+4, ["font-size"]=14, fill="#666", ["text-anchor"]="middle" }} })
		text:add(tostring(y_axis_marker[i]))
	end
	y_axis:add({ tag = {'line', {x1=border_px, y1=border_px, x2=border_px, y2=h-border_px, stroke="#000"}}, })
end




local data = {}
--for _, json_path in ipairs(arg) do
for _, json_path in ipairs(json_files) do
	local json_file = assert(io.open(json_path))
	local json_data = json.decode(json_file:read("*a"))
	json_data._filename = json_path
	table.insert(data, json_data)
end

local max_x,max_y = 0,0
local min_x,min_y = math.huge,math.huge
for i, test in ipairs(data) do
	for j,test_sample in ipairs(test) do
		max_x = math.max(max_x, test_sample[xvar])
		min_x = math.min(min_x, test_sample[xvar])
		max_y = math.max(max_y, test_sample[yvar])
		min_y = math.min(min_y, test_sample[yvar])
	end
end
min_y=0

local data_points,data_lines
local last_x,last_y
local function add_data_point(test_sample, color)
	local xpct = (test_sample[xvar]-min_x)/(max_x-min_x)
	local ypct = 1-((test_sample[yvar]-min_y)/(max_y-min_y))
	local screen_x = xpct*(w-2*border_px)+border_px
	local screen_y = ypct*(h-2*border_px)+border_px

	--local screen_y = (y/max_y)*(h-2*border_px)+border_px
	if last_x then
		table.insert(data_lines, { tag = {"line", {x1=screen_x, y1=screen_y, x2=last_x, y2=last_y, stroke=color}} })
	end
	table.insert(data_points, { tag = {"circle", {cx=screen_x, cy=screen_y, r=1, fill="#000"}} })
	last_x = screen_x
	last_y = screen_y
end


local x_axis_marker = {}
local y_axis_marker = {}
for j,test_sample in ipairs(data[1]) do
	table.insert(x_axis_marker, xformat:format(test_sample[xvar]*xunit))
	local p = ((j-1)/(#data[1]-1))
	table.insert(y_axis_marker, yformat:format(p*max_y*yunit))
end
add_xaxis(x_axis_marker)
add_yaxis(y_axis_marker)

local r1,r2 = 0,1
local g1,g2 = -math.sqrt(3)/2,-0.5
local b1,b2 = math.sqrt(3)/2,-0.5
local function hsv_to_rgb(hue, sat, val)
	hue=hue*math.pi*2+(math.pi/2)
	local h1,h2 = math.cos(hue), math.sin(hue)
	local r,g,b = h1*r1+h2*r2, h1*g1 + h2*g2, h1*b1 + h2*b2
	return (r+(1-r)*sat)*val, (g+(1-g)*sat)*val, (b+(1-b)*sat)*val
end

local function generate_colors(count)
	local colors = {}
	for i=1, count do
		local hue = ((i-1)/(count-1))*(5/6)
		colors[i] = ("#%.2x%.2x%.2x"):format(hsv_to_rgb(hue, 0.5, (i%2==0) and 255 or 127))
	end
	return colors
end


--local colors = {"lime", "aqua", "fuchsia", "gray", "blue", "green", "maroon", "navy", "olive", "purple", "red", "silver", "teal", "yellow"}
local colors = generate_colors(#data)
local line_labels = { tag = {"g", { id="line_labels" }} }
for i, test in ipairs(data) do
	local color = colors[((i-1)%#colors)+1]
	table.insert(line_labels, { tag = {"circle", { cx=w-border_px+4, cy=border_px+i*12-3, r=2, fill=color } } })
	local _, basename = test._filename:match("(.*/)(.*)%.json$")
	table.insert(line_labels, { tag = {"text", { x=w-border_px+10, y=border_px+i*12, width=border_px, ["font-size"]=12, fill=color, ["text-anchor"]="left" }}, basename })

	data_points = { tag = {"g", { id="data_points_"..i }} }
	data_lines = { tag = {"g", { id="data_lines_"..i }} }
	last_x,last_y=nil,nil
	for j,test_sample in ipairs(test) do
		add_data_point(test_sample, color)
	end
	root:add(data_lines)
	root:add(data_points)
end
root:add(line_labels)


print(svg_doc:tostring())
