local gui = {}


-- forward a set of parameters to all functions in a list until one returns false.
-- first argument is a list of functions, or a function.
-- other arguments are passed as-is to the functions
local function function_chain(functions, ...)
	if type(functions) ~= "table" then
		functions = {functions}
	end
	for i, _function in ipairs(functions) do
		if not _function(...) then
			break
		end
	end
end


-- create a new empty element from a configuration table
function gui.new_element(config)
	local element = {}
	
	-- an element is a rectangular region that is drawn to and that can get mouse/keyboard events
	element.width = assert(tonumber(config.width))
	element.height = assert(tonumber(config.height))
	
	-- position relative to parent(or screen if no parent)
	element.x = assert(tonumber(config.x))
	element.y = assert(tonumber(config.y))
	
	-- the lowest zindex is drawn first
	element.zindex = tonumber(config.zindex) or 100
	
	-- used to hide the element
	if config.visible ~= nil then
		element.visible = config.visible
	else
		element.visible = true
	end

	-- get the absolute poisiton for this element by tracing it's parents positions
	function element:get_position()
		local ox,oy = 0,0
		if self.parent then
			ox,oy = self.parent:get_position()
		end
		local sx = ox+self.x
		local sy = oy+self.y
		return sx,sy
	end
	
	-- check if the element-relative point is in the element
	function element:rel_point_in_element(x,y)
		if (x >= 0) and (x < self.width) and (y >= 0) and (y < self.height) then
			return x,y
		end
	end

	-- translate the global position to a position in the element
	function element:abs_point_in_element(x,y)
		local sx,sy = self:get_position()
		local rx = x - sx
		local ry = y - sy
		if self:rel_point_in_element(rx,ry) then
			return rx,ry
		else
			return nil,nil,rx,ry
		end
	end
	
	return element
end


-- create a new surface gui element. Draws a drawbuffer.
function gui.new_surface(config)
	local db = assert(config.db)
	local scale = tonumber(config.scale) or 1
	config.width = config.width or db:width()*scale
	config.height = config.height or db:height()*scale

	local surface = gui.new_element(config)
	surface.type = "surface"
	surface.scale = scale
	surface.db = db
	function surface:on_draw(target_db)
		local x,y = self:get_position()
		self.db:draw_to_drawbuffer(target_db, x,y, 0,0, self.width,self.height, self.scale)
	end
	return surface
end


-- create a new callback renderer. The callback is called with the target draw buffer and it's coordinates when rendering the element.
function gui.new_callback(config)
	local callback_e = gui.new_element(config)
	callback_e.type = "callback"
	callback_e.callback = config.callback
	function callback_e:on_draw(target_db)
		local x,y = self:get_position()
		self:callback(target_db,x,y)
	end
	return callback_e
end


-- create a new group of elements
function gui.new_group(config)
	local elements = assert(config.elements)
	if not (config.width and config.height) then
		local max_x = 0
		local max_y = 0
		for _,element in ipairs(elements) do
			max_x = math.max(max_x, element.x+element.width)
			max_y = math.max(max_y, element.y+element.height)
		end
		config.width = max_x
		config.height = max_y
	end
	
	local group = gui.new_element(config)
	group.type = "group"
	group.on_draw_element = config.on_draw_element
	group.elements = elements
	for _,element in ipairs(elements) do
		element.parent = group
	end
	
	-- forward draw calls to group elements
	function group:on_draw(target_db)
		for _,element in ipairs(self.elements) do
			local run = true
			if group.on_draw_element then
				run = group:on_draw_element(element, target_db)
			end
			if run and element.on_draw and element.visible then
				element:on_draw(target_db)
			end
		end
	end
	
	-- forward mouse events
	function group:handle_mouse_event(x,y, event)
		local ox,oy = self:get_position()
		return not gui.handle_mouse_event(self.elements, x+ox,y+oy, event)
	end
	
	-- forward key events
	function group:handle_key_event(key, event)
		return gui.handle_key_event(self.elements, key, event)
	end
	
	return group
end


-- create a new clickable button
function gui.new_button(config)
	local text = assert(config.text)
	local font = assert(config.font)

	local text_width = #text*font.char_w
	local m = config.margin or 5
	config.width = config.width or (text_width + m*2)
	config.height = config.height or (font.char_h + m*2)
	local button = gui.new_element(config)
	button.type = "button"
	button.text = text
	button.on_click = config.on_click
	button.on_mouse_enter = config.on_mouse_enter
	button.on_mouse_leave = config.on_mouse_leave
	
	button.background_color = config.background_color or {64,64,64,255}
	button.border_top_left_color = config.border_top_left_color or {224,224,224,255}
	button.border_bottom_right_color = config.border_bottom_right_color or {128,128,128,128}
	
	button.background_color_hover = config.background_color_hover or {64,64,96,255}
	
	function button:on_draw(target_db)
		local x,y = self:get_position()
		local bg = self.background_color
		local b_tl = self.border_top_left_color
		local b_br = self.border_bottom_right_color
		local bg_hover = self.background_color_hover
		
		if self.mouse_in_element and bg_hover then
			target_db:set_rectangle(x, y, self.width-1, self.height-1, bg_hover[1], bg_hover[2], bg_hover[3], bg_hover[4])
		elseif bg then
			target_db:set_rectangle(x, y, self.width-1, self.height-1, bg[1], bg[2], bg[3], bg[4])
		end
		
		if b_br then
			target_db:set_line(x+self.width-1, y, x+self.width-1, y+self.height-1, b_br[1], b_br[2], b_br[3], b_br[4])
			target_db:set_line(x, y+self.height-1, x+self.width-1, y+self.height-1, b_br[1], b_br[2], b_br[3], b_br[4])
		end
		if b_tl then
			target_db:set_line(x, y, x+self.width-1, y, b_tl[1], b_tl[2], b_tl[3], b_tl[4])
			target_db:set_line(x, y, x, y+self.height-1, b_tl[1], b_tl[2], b_tl[3], b_tl[4])
		end
		font:draw_string(target_db, self.text, x+m, y+m)
	end
	
	function button:handle_mouse_event(x,y,event)
		local ex,ey = self:rel_point_in_element(x,y)
		if event.type == "mousebuttondown" then
			if self.on_click and ex and ey then
				self:on_click()
				return true
			end
		elseif event.type == "mousemotion" then
			if self.mouse_in_element and (not ex) and (not ey) then
				if self.on_mouse_leave then
					self:on_mouse_leave()
				end
				self.always_handle_mouse_event = false
				self.mouse_in_element = false
			elseif (not self.mouse_in_element) and ex and ey then
				if self.on_mouse_enter then
					self:on_mouse_enter()
				end
				self.always_handle_mouse_event = true
				self.mouse_in_element = true
			end
		end
		return true
	end
	
	return button
end


-- sort elements by zindex, also recursivly resort groups
function gui.resort_elements(elements)
	local function sort_by_z(elements)
		table.sort(elements, function(a,b)
			if a.type == "group" then
				sort_by_z(a.elements)
			end
			if b.type == "group" then
				sort_by_z(b.elements)
			end
			if a.zindex == b.zindex then
				if a.x == b.x then
					return a.y < b.y
				else
					return a.x < b.x
				end
			else
				return a.zindex < b.zindex
			end
		end)
	end
	sort_by_z(elements)
end


-- draw a list of elements to a drawbuffer
function gui.draw_elements(target_db, elements)
	-- draw each visible element
	for i, element in ipairs(elements) do
		if element.on_draw and element.visible then
			element:on_draw(target_db)
		end
	end
end


-- TODO: Move the handle_mouse_event and handle_key_event to a seperate window manager class
-- handle a top-level mouse event for a list of elements.
function gui.handle_mouse_event(elements, x,y, event)
	local handled = false
	for i, element in ipairs(elements) do
		local rx,ry,_rx,_ry = element:abs_point_in_element(x,y)
		if element.handle_mouse_event and ((rx and ry) or element.always_handle_mouse_event) then
			local run = element:handle_mouse_event(rx or _rx,ry or _ry, event)
			if not run then
				break
			end
			handled = true
		end
	end
	return handled
end


-- handle a keyboard event
gui.keystate = {}
function gui.handle_key_event(elements, key, event, i)
	local i = i or 0
	local handled = false
	for i, element in ipairs(elements) do
		if element.handle_key_event then
			local run = element:handle_key_event(key, event)
			if not run then
				break
			end
		end
		handled = true
	end
	return handled
end



return gui
