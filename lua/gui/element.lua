--luacheck: no max line length

return function(gui)
	-- create a new base element.
	function gui.new_element(parent, surface, x,y, w,h)
		local element = {}
		element.type = "element"

		if parent then
			table.insert(parent.children, element)
		end

		-- position in parent
		element.x = assert(tonumber(x))
		element.y = assert(tonumber(y))

		-- dimensions of element in parent
		element.w = assert(tonumber(w))
		element.h = assert(tonumber(h))

		-- store reference to parent
		element.parent = parent

		-- apply automatic flow?
		element.ignore_flow = false

		-- element style override
		element.style = {}

		-- does this element have a surface(at least one element needs a surface to draw on)
		element.surface = surface

		-- store a list of children. Order is renderorder.
		element.children = {}

		-- append functions usefull for all elements


		-- get a styleable value. Dont cache this value!
		function element:get_style_value(key, required)
			if self.style[key] ~= nil then
				-- element has an override for this style
				return self.style[key]
			end
			local global_key = self.type .. "_" .. key
			if gui.style[global_key] ~= nil then
				-- we have a global default style
				return gui.style[global_key]
			end
			if required then
				-- we require the style value, but it's not present!
				error("Required style value not specified: "..tostring(key))
			end
		end

		function element:set_style_values(style_values)
			for k,v in pairs(style_values) do
				self.style[k] = v
			end
		end

		-- remove specified element from children(and children's children if recursive is set)
		function element:remove_element(remove_element, recursive)
			for i,child_element in ipairs(self.children) do
				if child_element == remove_element then
					table.remove(self.children, i)
					return child_element, self
				elseif (#child_element.children > 0) and recursive then
					child_element:remove_element(remove_element, true)
				end
			end
		end

		-- align the element in it's parent along an axis.
		function element:align_in_parent(halign, valign)
			if halign == "left" then
				self.x = 0
			end
			if halign == "right" then
				self.x = self.parent.w-self.w
			end
			if halign == "center" then
				self.x = self.parent.w*0.5-self.w*0.5
			end
			if valign == "top" then
				self.y = 0
			end
			if valign == "bottom" then
				self.y = self.parent.h-self.h
			end
			if valign == "center" then
				self.y = self.parent.h*0.5-self.h*0.5
			end
		end


		-- return the list of children that intersect this point
		-- TODO: test this
		function element:get_elements_at_point(global_x,global_y, order)
			local list = {}

			for i=1, #self.children do
				if order then
					i = #self.children - (i-1)
				end
				local child = self.children[i]
				if child and child:global_is_in_element(global_x,global_y) then
					local child_elements = child:get_elements_at_point(global_x,global_y)
					for _, child_element in ipairs(child_elements) do
						if order then
							table.insert(list, 1, child_element)
						else
							table.insert(list, child_element)
						end
					end
					table.insert(list, child)
				end
			end
			return list
		end

		-- propagate an event down(to children, children of children, ...), until an event handler returns true
		function element:propagate_event_down(ev, order)
			for _, event_handler in ipairs(self.event_handlers) do
				local handled = event_handler(self, ev)
				if handled then
					return handled
				end
			end
			for i=1, #self.children do
				if order then
					i = #self.children - (i-1)
				end
				local child = self.children[i]
				if child then
					local handled = child:propagate_event_down(ev, order)
					if handled then
						return handled
					end
				end
			end
		end

		-- propagate an event up(to parents, parents of parents, ...), until an event handler returns true
		function element:propagate_event_up(ev)
			for _, event_handler in ipairs(self.event_handlers) do
				local handled = event_handler(self, ev)
				if handled then
					return handled
				end
			end
			if self.parent then
				local handled = self.parent:propagate_event_up(ev)
				if handled then
					return handled
				end
			end
		end

		-- draw this element and all its child elements
		function element:handle_draw()
			local targete_surface, target_ox,target_oy = self:get_surface()
			if self.style.draw then
				self.style.draw(self, targete_surface, target_ox, target_oy)
			else
				self:draw(targete_surface, target_ox, target_oy)
			end
			for _,child in ipairs(self.children) do
				child:handle_draw()
			end
			if self.surface and self.parent then
				local parent_surface, parent_ox,parent_oy = self.parent:get_surface()
				self.surface:origin_to_target(parent_surface, self.x+parent_ox, self.y+parent_oy)
			end
		end

		-- get surface to draw on, and offset in it. If element has no surface,
		-- look up parent surfaces recursivly, keeping track offsets in the parent elements.
		function element:get_surface()
			if self.surface then
				return self.surface, 0,0
			end
			if self.parent then
				local parent_surface, parent_ox,parent_oy = self.parent:get_surface()
				return parent_surface, self.x+parent_ox, self.y+parent_oy
			end
		end

		-- get the position of the element in the root window
		function element:get_absolute_position()
			if self.parent then
				local parent_ox,parent_oy = self.parent:get_absolute_position()
				return self.x+parent_ox, self.y+parent_oy
			end
			return 0,0
		end

		-- return the global coordinates(coordinates in the root element) for the given local(to the element) coordinates
		function element:local_to_global(local_x, local_y)
			local ox, oy = self:get_absolute_position()
			return ox+local_x, oy+local_y
		end

		-- return the local(to the element) coordinates for the given global(coordinates in the root element) coordinates
		function element:global_to_local(global_x, global_y)
			local ox, oy = self:get_absolute_position()
			return global_x-ox, global_y-oy
		end

		-- return the local(to the element) coordinates for the given global(coordinates in the root element) coordinates,
		-- if the coordinates are the element.
		function element:global_is_in_element(global_x, global_y)
			local ox, oy = self:get_absolute_position()
			local local_x,local_y = global_x-ox, global_y-oy
			if (local_x>=0) and (local_y>=0) and (local_x<self.w) and (local_y<self.h) then
				return local_x,local_y
			end
		end

		-- User callback.
		function element:draw(target_surface, ox,oy)
			--target_surface:rectangle(ox,oy,self.w,self.h, 255,255,255,128, false, true) --fill with alpha
			--target_surface:rectangle(ox,oy,self.w,self.h, 255,0,255,255, true, false) -- outline,no alpha
		end

		-- User callback list. Functions in this list are called in order.
		-- Each function is called with the element as first argument, and the
		-- event as second. If this function returns true, the event should not be passed to other event handlers.
		element.event_handlers = {}

		return element
	end
end
