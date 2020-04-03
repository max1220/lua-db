--luacheck: no max line length
return function(gui)
	gui:append_style("menu_container_element", {

	})

	-- create a menu elemenmt that can contain many sub-menus.
	function gui.new_context_menu_element(parent, __menu, bmpfont)
		local menu_container = gui.new_element(parent, nil, 0,0, parent.w,parent.h)
		menu_container.type = "menu_container_element"
		menu_container.ignore_flow = true
		menu_container.style = {
			width = nil,
			spacing = 0,
			item_height = nil,
			item_style = { bg_color = false, border_color = false},
			menu_style = { bg_color = {32,32,32,192}, border_color = {128,128,128,255} },
			bmpfont = bmpfont,
		}
		menu_container.menu = __menu

		function menu_container:add_menu(x,y, menu)
			local menu_element = gui.new_element(self, nil, x,y, 0,0)
			menu_element.type = "menu_element"
			menu_element:set_style_values(self:get_style_value("menu_style"))
			menu_element.bg_color = menu_element:get_style_value("bg_color") or menu_container:get_style_value("bg_color")
			menu_element.border_color = menu_element:get_style_value("border_color") or menu_container:get_style_value("border_color")
			local item_height = menu.item_height or self:get_style_value("item_height")
			local menu_w = menu.width or self:get_style_value("width")
			local menu_spacing = menu.spacing or self:get_style_value("spacing", true)
			local menu_bmpfont = self:get_style_value("bmpfont", true)
			local item_style = self:get_style_value("item_style")
			local spacing

			function menu_element.draw(_self, target_db, target_ox, target_oy)
				if _self.bg_color then
					local r,g,b,a = unpack(_self.bg_color)
					target_db:rectangle(target_ox, target_oy, _self.w, _self.h, r,g,b,a, false, true)
				end
				if _self.border_color then
					local r,g,b,a = unpack(_self.border_color)
					target_db:rectangle(target_ox, target_oy, _self.w, _self.h, r,g,b,a, true, true)
				end
			end

			function menu_element.close_submenus()
				for _,item in ipairs(menu) do
					local submenu_element = item.submenu_element
					if submenu_element then
						submenu_element:close_submenus()
						self:remove_element(submenu_element)
						item.submenu_element = nil
					end
				end
			end
			local cy = 0
			local max_w = 0
			for _,item in ipairs(menu) do
				local item_bmpfont = item.bmpfont or menu_bmpfont
				spacing = item.spacing or menu_spacing
				local item_button =	gui.new_button_element(menu_element, 0,cy, nil, nil, item.text or "", item_bmpfont)
				item_button.autosize = false
				item_button.w = menu_w or item_button.w
				item_button.h = item.height or item_height or item_button.h
				max_w = math.max(max_w, item_button.w)
				item.element = item_button
				if item_style then
					item_button:set_style_values(item_style)
				end
				if item.style then
					item_button:set_style_values(item.style)
				end
				cy = cy + item_button.h + spacing
				function item_button.on_click(_self)
					if item.callback then
						-- normal item clicked
						item:callback()
						self:close()
					elseif item.submenu_element then
						-- already open submenu button clicked
						menu_element:close_submenus()
					elseif item.submenu then
						-- (closed) submenu button clicked
						menu_element:close_submenus()
						item.submenu_element = self:add_menu(x+_self.w, y+_self.y, item.submenu)
					end
				end
				item_button:update()
			end
			if not menu_w then
				for _,item in ipairs(menu) do
					item.element.w = max_w
				end
			end
			menu_element.w = menu_w or max_w
			menu_element.h = cy - spacing
			return menu_element
		end

		function menu_container:close()
			if self.top_menu_element then
				self.top_menu_element:close_submenus()
				self.children = {}
				self.top_menu_element = nil
			end
		end

		function menu_container:show(x,y)
			if self.top_menu_element then
				self:close()
			end
			self.top_menu_element = self:add_menu(assert(tonumber(x)),assert(tonumber(y)),self.menu)
		end


		-- event handler to hide the menu if we click in a non-menu area
		local function menu_container_event_handler(self, ev)
			if ev.type ~= "mousebuttondown" then
				return false
			end
			if not self.top_menu_element then
				return false
			end
			for _, child in ipairs(self.children) do
				if child:global_is_in_element(ev.x, ev.y) then
					return false -- event position is in a child
				end
			end
			-- Clicked in an empty area, hide menu
			self:close()
		end
		table.insert(menu_container.event_handlers, menu_container_event_handler)

		local function menu_container_parent_pre_event_handler(self, ev)
			if (ev.type == "mousebuttonup") and (ev.button == 3) then
				local local_x, local_y = menu_container:global_is_in_element(ev.x, ev.y)
				if not local_x then
					return false
				end
				for _,child in ipairs(self.children) do
					if child:global_is_in_element(ev.x, ev.y) and (child ~= menu_container) then
						return false
					end
				end
				--down = true
				menu_container:show(local_x, local_y)
				return true
			end
		end
		table.insert(menu_container.parent.event_handlers, 1, menu_container_parent_pre_event_handler)

		return menu_container
	end
































	--[[

	-- create a menu elemenmt that can contain many sub-menus.
	function gui.new_context_menu_element(parent, w, _menu, bmpfont)
		local menus_element = gui.new_element(parent, nil, 0,0, parent.w,parent.h)
		menus_element.type = "context_menu_element"
		menus_element.ignore_flow = true
		menus_element.menu_x = 0
		menus_element.menu_y = 0
		menus_element.style = {
			bmpfont = bmpfont,

		}

		local function get_menu_height(menu)
			local elements_h = 0
			for _,item in ipairs(menu) do
				local item_h = item.height or bmpfont.char_h
				elements_h = elements_h + item_h
			end
			return elements_h
		end

		local function add_menu_item_callback(item)
			function item.element:on_click()
				if item.callback then
					item:callback()
					menus_element:hide()
				end
			end
		end

		local add_menu
		local function add_menu_item_submenu(item)
			function item.element:on_click()
				local submenu_index
				local menu_index
				for i, child in ipairs(menus_element.children) do
					if child == item.submenu.element then
						submenu_index = i
					end
					if child == item.menu.element then
						menu_index = i
					end
				end

				-- hide all menu's further in the menu tree that this menu
				menus_element:hide(menu_index)
				if submenu_index then
					item.submenu_active = false
				else
					add_menu(item.submenu,item.menu.element.y+item.element.y)
					item.submenu_active = true
				end
				menus_element:update_positions()
			end
			item.submenu_active = false
		end

		add_menu = function(menu, offset_y)
			menu.height = get_menu_height(menu)
			menu.element = gui.new_element(menus_element, nil, 0,offset_y or 0, w,menu.height)
			function menu.element:draw(surface, ox,oy)
				surface:rectangle(ox,oy,self.w,self.h,32,32,32,255)
				surface:rectangle(ox,oy,self.w,self.h,64,64,64,255, true)
			end
			local y = 0
			for _,item in ipairs(menu) do
				item.menu = menu
				item.height = item.height or bmpfont.char_h

				item.element = gui.new_button_element(menu.element, bmpfont, 0, y, w, item.height, item.text)
				y = y + item.height
				item.element.hover_bg_color = {48,48,48,255}
				item.element.down_bg_color = {16,16,16,255}
				item.element.text_halign = "left"
				item.element:update_text()

				if item.callback then
					add_menu_item_callback(item)
				elseif item.submenu then
					add_menu_item_submenu(item)
				end
			end
			menus_element:update_positions()
		end

		-- position the menus and submenus horizontally
		function menus_element:update_positions()
			local x = self.menu_x
			for _,child in ipairs(self.children) do
				child.x = x
				x = x + child.w-1
			end
		end

		local down = false
		local function menus_element_event_handler(self, ev)
			local local_x, local_y = self.parent:global_is_in_element(ev.x, ev.y)
			if self.visible and local_x then
				for _, child in ipairs(self.children) do
					if child:global_is_in_element(ev.x, ev.y) then
						return false -- event is in a child, run child event handlers
					end
				end
				if ev.type == "mousebuttondown" then
					self:hide()
				end
			end
			return false
		end
		table.insert(menus_element.event_handlers, menus_element_event_handler)


		local function menus_element_parent_event_handler(self, ev)
			local local_x, local_y = self:global_is_in_element(ev.x, ev.y)
			if (ev.type == "mousebuttondown") and (ev.button == 3) and local_x then
				for _,child in ipairs(self.children) do
					-- TODO: property to ignore context menu
					if child:global_is_in_element(ev.x, ev.y) and (child ~= menus_element) then
						return false
					end
				end
				down = true
				return true
			end
			if (ev.type == "mousebuttonup") and (ev.button == 3) and down then
				menus_element:show(local_x, local_y)
				down = false
				return true
			end
		end
		table.insert(menus_element.parent.event_handlers, 1, menus_element_parent_event_handler)

		function menus_element:hide(_min_d)
			local min_d = tonumber(_min_d) or 0
			for i=min_d+1, #menus_element.children do
				menus_element.children[i] = nil
			end
			if #menus_element.children == 0 then
				self.visible = false
			end
		end

		function menus_element:show(x,y)
			menus_element.menu_x = x or menus_element.menu_x
			menus_element.menu_y = y or menus_element.menu_y
			self:hide()
			add_menu(_menu, menus_element.menu_y)
			menus_element:update_positions()
			self.visible = true
		end

		--menus_element:show()
		return menus_element
	end


	]]
end
