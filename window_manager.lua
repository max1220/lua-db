local gui = require("gui")
local window_manager = {}


function window_manager.new_window_group(config)
	local elements = config.elements
	local style = config.style
	
	local function remove_from_t(t, e)
		for i=1, #t do
			if t[i] == e then
				table.remove(t, i)
				return true
			end
		end
	end
	
	local function make_draggable_callback()
		local down
		local function handle_mouse_event(self, x,y,ev,rx,ry)
			local x = x or rx
			local y = y or ry
			if ev.type == "mousebuttondown" then
				if ev.button == 1 then
					down = {x,y}
					self.always_handle_mouse_event = true
				end
			elseif ev.type == "mousebuttonup" and (ev.button == 1) then
				down = nil
				self.always_handle_mouse_event = false
			elseif ev.type == "mousemotion" then
				if down then
					local dx = (x - down[1])
					local dy = (y - down[2])
					self.x = self.x + dx
					self.y = self.y + dy
					self.window.x = self.x + 1
					self.window.y = self.y + self.height
				end
			end
			return false
		end
		return handle_mouse_event
	end
	
	local function make_resizeable_callback()
		local down
		local function handle_mouse_event(self, x,y,ev)
			if ev.type == "mousebuttondown" then
				if ev.button == 3 then
					down = {x,y}
					self.always_handle_mouse_event = true
				end
			elseif ev.type == "mousebuttonup" and (ev.button == 3) then
				down = nil
				self.always_handle_mouse_event = false
			elseif ev.type == "mousemotion" then
				if down then
					local dx = (x - down[1])
					local dy = (y - down[2])
					self.x = self.x + dx
					self.y = self.y + dy
					local new_w = math.max(self.window.width - dx, self.window.min_width or 0, 0)
					local new_h = math.max(self.window.height - dy, self.window.min_height or 0, 0)
					self.width = new_w+2
					self.window.width = new_w
					self.window.height = new_h
					self.window.x = self.x + 1
					self.window.y = self.y + self.height
				end
			end
			return false
		end
		return handle_mouse_event
	end

	local function unpack_color(color)
		return color[1], color[2], color[3], color[4]
	end
	
	local function unpack_color_3(color, ...)
		return color[1], color[2], color[3], ...
	end
	
	-- load style
	local default_titlebar_background_color = style.default_titlebar_background_color or {64,64,64,255}
	local default_titlebar_border_color = style.default_titlebar_border_color or {128,128,128,255}
	local titlebar_height = style.titlebar_height or 20
	local titlebar_font = assert(style.titlebar_font)
	local default_window_background_color = style.default_window_background_color or {192,192,192,255}
	local default_window_border_color = style.default_window_border_color or {128,128,128,255}
	local default_titlebar_button_background_color = style.default_titlebar_button_background_color or {160,160,160,255}
	local default_titlebar_button_line_color = style.default_titlebar_button_line_color or {224,64,64}
	local default_titlebar_focus_background_color = style.default_titlebar_focus_background_color or {64,64,128,255}
	
	-- this function creates a titlebar element for a window element and attaches it to the window
	local function titlebar_for_window(window)
		local titlebar_background_color = window.titlebar_background_color or default_titlebar_background_color
		local titlebar_focus_background_color = window.titlebar_focus_background_color or default_titlebar_focus_background_color
		local titlebar_border_color = window.titlebar_border_color or default_titlebar_border_color
		local titlebar_button_background_color = window.titlebar_button_background_color or default_titlebar_button_background_color
		local titlebar_button_line_color = window.titlebar_button_line_color or default_titlebar_button_line_color
		
		local titlebar_e = gui.new_callback({
			x = window.x - 1,
			y = window.y - titlebar_height,
			width = window.width + 2,
			height = titlebar_height
		})
		function titlebar_e:callback(db, ox,oy)
			local bg_color = self.window.focus and titlebar_focus_background_color or titlebar_background_color
			db:set_rectangle(ox+1,oy+1,self.width-2, self.height-2, unpack_color(bg_color))
			db:set_box(ox,oy, self.width,self.height, unpack_color(titlebar_border_color))
			titlebar_font:draw_string(db, self.window.title or "Unnamed window", ox+5,oy+6)
			db:set_rectangle(math.floor(ox+self.width-titlebar_height+1),oy+1,titlebar_height-2, titlebar_height-2, unpack_color(titlebar_button_background_color))
			db:set_line_anti_aliased(ox+self.width-titlebar_height+4,oy+4,  ox+self.width-5,oy+titlebar_height-5, unpack_color_3(titlebar_button_line_color, 1))
			db:set_line_anti_aliased(ox+self.width-titlebar_height+4,oy+titlebar_height-5,  ox+self.width-5,oy+4, unpack_color_3(titlebar_button_line_color, 1))
		end
		local draggable_cb = make_draggable_callback()
		local resizeable_cb = make_resizeable_callback()
		function titlebar_e:handle_mouse_event(x,y,ev)
			draggable_cb(self, x,y,ev)
			resizeable_cb(self, x,y,ev)
			if x > self.width - titlebar_height then
				-- close button
				if (ev.type == "mousebuttondown") and (ev.button == 1) then
					if titlebar_e.window.on_close then
						titlebar_e.window:on_close()
					end
					titlebar_e.window:close()
				elseif (ev.type == "mousebuttondown") and (ev.button == 3) then
					print("todo context menu")
				end
			else
				-- titlebar
				if (ev.type == "mousebuttondown") and (ev.button == 1) then
					self.window:focus_self()
				end
			end
		end
		return titlebar_e
	end


	-- this will hold a list of elements that will get drawn as the contents of windows
	local windows = {}
	
	-- a list of titlebars
	local titlebars = {}
	
	-- the list that will contain all windows and titlebars
	local elements_list = {}
	
	-- ẃindow functions
	function windows:focus(window)
		for i,_window in ipairs(self) do
			if window == _window then
				_window.zindex = 200
				_window.titlebar.zindex = 200
				_window.focus = true
			else
				_window.zindex = 100
				_window.titlebar.zindex = 100
				_window.focus = false
			end
		end
	end
	function windows:minimize(_window)
		for i, window in ipairs(self) do
			if window == _window then
				window.visible = false
				window.titlebar.visible = false
			end
		end
	end
	function windows:unminimize(_window)
		for i, window in ipairs(self) do
			if window == _window then
				window.visible = true
				window.titlebar.visible = true
			end
		end
	end
	function windows:rollup(_window)
		for i, window in ipairs(self) do
			if window == _window then
				window.visible = false
			end
		end
	end
	function windows:rolldown(_window)
		for i, window in ipairs(self) do
			if window == _window then
				window.visible = true
			end
		end
	end
	function windows:remove_window(window)
		remove_from_t(self, window)
		remove_from_t(titlebars, window.titlebar)
		remove_from_t(elements_list, window)
		remove_from_t(elements_list, window.titlebar)
	end
	function windows:make_window(element)
		-- add window functions
		element.focus_self = function(self) windows:focus(self) end
		element.minimize = function(self) windows:minimize(self) end
		element.unminimize = function(self) windows:unminimize(self) end
		element.rollup = function(self) windows:rollup(self) end
		element.rolldown = function(self) windows:rolldown(self) end
		element.close = function(self) windows:remove_window(self) end
		
		-- add titlebar
		local titlebar = titlebar_for_window(element)
		titlebar.window = element
		element.titlebar = titlebar
		element.is_window = true
		
		table.insert(titlebars, titlebar)
		table.insert(windows, element)
		table.insert(elements_list, titlebar)
		table.insert(elements_list, element)
		return element, titlebar
	end
	

	-- make a window from each supplied element
	for i, element in ipairs(elements) do
		windows:make_window(element)
	end

	-- the group that will be returned
	config.elements = elements_list
	local windows_e = gui.new_group(config)
	
	-- this function will be called for content element to draw the border of the window, and determine if the window gets drawn
	function windows_e:on_draw_element(element, target_db)
		-- draw window decoration
		if not element.is_window then
			return true
		end
		
		local x,y = element:get_position()
		local window_border_color = element.border_color or default_window_border_color
		local window_background_color = element.background_color or default_window_background_color
		
		-- window background
		if window_background_color then
			target_db:set_rectangle(x,y,element.width, element.height, window_background_color[1], window_background_color[2], window_background_color[3], window_background_color[4])
		end
		
		-- window outline
		if window_border_color then
			target_db:set_box(x-1,y-1,element.width+2, element.height+2, window_border_color[1], window_border_color[2], window_border_color[3], window_border_color[4])
		end
		
		-- still draw the image
		return true
	end
	
	-- call this function with the time since it has been last called to call the :update function for each window
	function windows_e:update(dt)
		for i, window in ipairs(windows) do
			if window.update then
				window:update(dt)
			end
		end
		gui.resort_elements(elements_list)
	end
	
	-- forward keyboard events to the window with focus
	function windows_e:handle_key_event(key, event)
		for i, window in ipairs(windows) do
			if window.focus and window.handle_key_event then
				window:handle_key_event(key, event)
				return
			end
		end
	end
	
	return windows_e
	
end


return window_manager
