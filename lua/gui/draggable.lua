return function(gui)
	-- create an element that can be moved(dragged with lmb) within it's parent.
	function gui.new_draggable_element(parent, x,y, w,h)
		local draggable_element =  gui.new_element(parent, nil, x,y, w,h)
		draggable_element.ignore_flow = true
		draggable_element.type = "draggable_element"

		-- user callbacks
		function draggable_element:on_drag_start(local_x,local_y)
		end
		function draggable_element:on_drag(local_x,local_y)
		end
		function draggable_element:on_drag_end(local_x,local_y)
		end

		local function draggable_element_event_handler(self, ev)
			local local_x, local_y = self:global_is_in_element(ev.x, ev.y)
			if (ev.type == "mousebuttondown") and (ev.button == 1) and local_x and (not self.down) then
				self.down = {x=ev.x, y=ev.y}
				self.orig = {x=self.x, y=self.y}
				self:on_drag_start(local_x, local_y)
				self:on_drag(local_x, local_y)
				return true
			end
			if (ev.type == "mousemotion") and self.down then
				self.x = math.min(math.max(self.orig.x + (ev.x-self.down.x), 0), self.parent.w-self.w)
				self.y = math.min(math.max(self.orig.y + (ev.y-self.down.y), 0), self.parent.h-self.h)
				local_x, local_y = self:global_to_local(ev.x, ev.y)
				self:on_drag(local_x, local_y)
				return true
			end
			if (ev.type == "mousebuttonup") and (ev.button == 1) then
				if self.down then
					local_x, local_y = self:global_to_local(ev.x, ev.y)
					self:on_drag(local_x, local_y)
					self:on_drag_end(local_x, local_y)
				end
				self.down = false
			end
		end
		table.insert(draggable_element.event_handlers, draggable_element_event_handler)

		return draggable_element
	end

end
