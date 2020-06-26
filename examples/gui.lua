#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")
--luacheck: ignore self, no max line length

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_title = "GUI test",
	sdl_width = 800,
	sdl_height = 600,
	limit_fps = 30
}, arg)
cio:init()

-- create drawbuffer of native display size
local w,h = cio:get_native_size()
local db = ldb.new_drawbuffer(w,h, ldb.pixel_formats.abgr8888)
cio.target_db = db

-- create the example fonts
-- TODO: Better path handling for examples
local img_db = ldb.bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")
local char_to_tile = dofile("./examples/data/8x8_font_max1220.lua")
local fonts = {
	normal = ldb.bmpfont.new_bmpfont({
		db = img_db,
		char_w = 8, char_h = 8,
		scale_x = 1, scale_y = 1,
		char_to_tile = char_to_tile
	}),
	black = ldb.bmpfont.new_bmpfont({
		db = img_db,
		char_w = 8, char_h = 8,
		scale_x = 1, scale_y = 1,
		color = {0,0,0},
		char_to_tile = dofile("./examples/data/8x8_font_max1220.lua"),
	}),
	large = ldb.bmpfont.new_bmpfont({
		db = img_db,
		char_w = 8, char_h = 8,
		scale_x = 2, scale_y = 2,
		char_to_tile = char_to_tile
	}),
	large_black = ldb.bmpfont.new_bmpfont({
		db = img_db,
		char_w = 8, char_h = 8,
		scale_x = 2, scale_y = 2,
		color = {0,0,0},
		char_to_tile = dofile("./examples/data/8x8_font_max1220.lua"),
	})
}

-- create root element
local root = ldb.gui.new_element(nil, db, 0,0, w,h)

-- create the FPS display in the top-left corner
local text_element = ldb.gui.new_text_element_bmpfont(root, fonts.large, 0,0, 5, "FPS:")



-- create a container that stacks it's element vertically and contains all GUI elements
local vertical_group = ldb.gui.new_vertical_group_element(root, 0,25, w-50, h-50, "top", 5)



-- create a draggable surface below all elements in the vertical group
local down_draggable_element = ldb.gui.new_draggable_element(vertical_group, 200,20, 100,100)
function down_draggable_element:draw(surface, ox,oy)
	if self.down then
		surface:rectangle(ox,oy, self.w, self.h, 0,0,255,128, false, true)
	else
		surface:rectangle(ox,oy, self.w, self.h, 0,0,255,64, false, true)
	end
end


-- create a large button element in the container that, when clicked, changes its text
local large_button = ldb.gui.new_button_element(vertical_group, 0,0, 200,35, "Click me!", fonts.large)
function large_button:on_click(x, y)
	print("Hello from the button! Clicked at:",x,y)
	self:update("Clicked!")
end
large_button:align_in_parent("center")


-- create a toggle button element that indicates it's state(on/off) using it's color
local toggle_button = ldb.gui.new_button_toggle_element(vertical_group, 0,0, 100,20, "on", "off", fonts.normal)
toggle_button.style.on_bg_color = {0,128,0,255}
toggle_button.style.off_bg_color = {128,0,0,255}
toggle_button.autosize = true
toggle_button:update()
toggle_button:align_in_parent("center")



-- create the top group of buttons that demonstrate the horizontal alignment element
local align_group = ldb.gui.new_horizontal_group_element(vertical_group, 0,0, 200,0, "center", 3)
align_group:align_in_parent("center")
local left_button = ldb.gui.new_button_element(align_group, 0,0, nil,nil, "left", fonts.normal)
function left_button:on_click()
	align_group:align_left()
end
local center_button = ldb.gui.new_button_element(align_group, 0,0, nil,nil, "center", fonts.normal)
function center_button:on_click()
	align_group:align_center()
end
local right_button = ldb.gui.new_button_element(align_group, 0,0, nil,nil, "right", fonts.normal)
function right_button:on_click()
	align_group:align_right()
end

-- the align group should have the height of one of the buttons
align_group.h = center_button.h

-- update the positions of children of the align_group
align_group:update()


-- create sliders for the background color
local bg_color = {128,128,128}
local r_slider = ldb.gui.new_horizontal_slider_element(vertical_group, 0,0, 200, 20, 20, {128,0,0,255})

r_slider:align_in_parent("center")
function r_slider:on_slide(pct)
	local v = math.floor(pct*255)
	bg_color[1] = v
end
local g_slider = ldb.gui.new_horizontal_slider_element(vertical_group, 0,0, 200, 20, 20, {0,128,0,255})

g_slider:align_in_parent("center")
function g_slider:on_slide(pct)
	local v = math.floor(pct*255)
	bg_color[2] = v
end
local b_slider = ldb.gui.new_horizontal_slider_element(vertical_group, 0,0, 200, 20, 20, {0,0,128,255})

b_slider:align_in_parent("center")
function b_slider:on_slide(pct)
	local v = math.floor(pct*255)
	bg_color[3] = v
end
local function update_slider_values()
	r_slider:set_pct(bg_color[1]/255)
	g_slider:set_pct(bg_color[2]/255)
	b_slider:set_pct(bg_color[3]/255)
end
update_slider_values()

-- create a surface that if clicked draws pixels
local drawing_surface = ldb.new_drawbuffer(200,200, "abgr8888")
drawing_surface:clear(255,255,255,255)
local drawing_element = ldb.gui.new_element(vertical_group, drawing_surface, 0,0, 200, 200)
drawing_element:align_in_parent("center")
drawing_element.draw_color = {0,0,0}
local function drawing_element_event_handler(self, ev)
	local local_x, local_y = self:global_is_in_element(ev.x, ev.y)
	if (ev.type == "mousebuttondown") and local_x and ev.button == 1 then
		self.down = {local_x, local_y}
		return true
	end
	if (ev.type == "mousemotion") and local_x then
		if self.down then
			drawing_surface:line(self.down[1], self.down[2], local_x, local_y, self.draw_color[1], self.draw_color[2], self.draw_color[3], 255)
			self.down = {local_x, local_y}
		end
	end
	if (ev.type == "mousebuttonup") and (ev.button == 1) then
		self.down = false
	end
	if (ev.type == "mousebuttondown") and (ev.button == 3) and local_x then
		return true
	end
	if (ev.type == "mousebuttonup") and (ev.button == 3) and local_y then
		return true
	end
end
table.insert(drawing_element.event_handlers, drawing_element_event_handler)
function drawing_element:draw(target_surface, ox, oy)
	for i=0, 10 do
		target_surface:set_px(ox+i,oy,255,0,0,255)
		target_surface:set_px(ox,oy+i,255,0,0,255)
		target_surface:set_px(ox+i,oy+i,255,0,0,255)
	end
end


local colors_group = ldb.gui.new_horizontal_group_element(vertical_group, 0,0, 200,20, "center", 3)
local colors = {
	{0,0,0,255},
	{255,0,0,255},
	{0,255,0,255},
	{0,0,255,255},
	{255,255,0,255},
	{0,255,255,255},
	{255,0,255,255},
	{255,255,255,255},
}
for _, color in ipairs(colors) do
	local color_button = ldb.gui.new_button_element(colors_group, 0,0, 20,20, "", fonts.normal)
	color_button.bg_color = color
	function color_button:on_click()
		drawing_element.draw_color = color
	end
	function color_button:on_rightclick()
		drawing_surface:clear(unpack(color))
	end
end

-- update the positions of children of the align_group
colors_group:update()

-- align group in parent
colors_group:align_in_parent("center")



local scroll_container = ldb.gui.new_scroll_container_element(vertical_group, 0,0, 200,100, 600,200)
scroll_container:align_in_parent("center")
-- create a large button element in the scroll container
ldb.gui.new_button_element(scroll_container.scroll_content, 0,90, 50,20, "test", fonts.normal)


-- create a draggable surface above all elements in the vertical group
local top_draggable_element = ldb.gui.new_draggable_element(vertical_group, 20,20, 100,100)
function top_draggable_element:draw(surface, ox,oy)
	if self.down then
		surface:rectangle(ox,oy, self.w, self.h, 255,0,0,128, false, true)
	else
		surface:rectangle(ox,oy, self.w, self.h, 255,0,0,64, false, true)
	end
end

-- All vertical group elements now have thier size. update the positions of the child elements
vertical_group:update()
vertical_group:align_in_parent("center")






-- create a context menu
local menu = {
	{
		text = "entry 1",
		callback = function(self) print(self.text) end
	},
	{
		text = "entry 2",
		callback = function(self) print(self.text) end
	},
	{
		text = "BG color >",
		submenu = {
			{
				text = "Red",
				style = { bg_color = {255,0,0,64} },
				callback = function(self) bg_color = {255,0,0,255}; update_slider_values()  end
			},
			{
				text = "Green",
				style = { bg_color = {0,255,0,64} },
				callback = function(self) bg_color = {0,255,0,255}; update_slider_values()  end
			},
			{
				text = "Blue",
				style = { bg_color = {0,0,255,64} },
				callback = function(self) bg_color = {0,0,255,255}; update_slider_values() end
			},
			{
				text = "Black",
				style = { bg_color = {0,0,0,64} },
				callback = function(self) bg_color = {0,0,0,255}; update_slider_values()  end
			},
			{
				text = "White",
				style = { bg_color = {255,255,255,64} },
				callback = function(self) bg_color = {255,255,255,255}; update_slider_values()  end
			},
		}
	},
	{
		text = "submenu >",
		submenu = {
			{
				text = "4 subentry 1",
				callback = function(self) print(self.text) end
			},
			{
				text = "4 subentry 2",
				callback = function(self) print(self.text) end
			},
			{
				text = "4 subsubmenu",
				submenu = {
					{
						text = "subsubsubmenu",
						submenu = {
							{
								text = "foo",
								callback = function(self) print(self.text) end
							},
							{
								text = "bar",
								callback = function(self) print(self.text) end
							}
						}
					}
				}
			}
		}
	},
	{
		text = "entry 3",
		callback = function(self) print(self.text) end
	}
}
ldb.gui.new_context_menu_element(vertical_group, menu, fonts.normal)






-- handle an input_output event(Only forward mousebutton up/down)
function cio:on_event(ev)
	if ev.type == "mousebuttondown" then
		root:propagate_event_down(ev, true)
	elseif ev.type == "mousebuttonup" then
		root:propagate_event_down(ev, true)
	elseif ev.type == "mousemotion" then
		root:propagate_event_down(ev, true)
	end
end


function cio:on_update(dt)
	text_element.text = ("FPS: %05.1f"):format(1/dt)
end

function cio:on_draw(target_db)
	local r,g,b = unpack(bg_color)
	db:clear(r,g,b, 255)

	-- draw all descendants of the root element
	root:handle_draw()
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
