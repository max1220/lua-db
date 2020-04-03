return function(gui)
	gui:append_style("horizontal_slider_element", {
		drag_w = 20,
		bg_color = {0,0,0,255},
		border_color = {255,255,255,64},
		drag_bg_color = {255,255,255,64},
		drag_down_bg_color = {255,255,255,48},
		drag_draw = nil
	})
	gui:append_style("vertical_slider_element", {
		drag_w = 20,
		bg_color = {0,0,0,255},
		border_color = {255,255,255,64},
		drag_bg_color = {255,255,255,64},
		drag_down_bg_color = {255,255,255,48},
		drag_draw = nil
	})

	-- create a horizontal slider(Like a scrollbar)
	function gui.new_horizontal_slider_element(parent, x,y, w,h, drag_w, bg_color)
		local horizontal_slider = gui.new_element(parent, nil, x,y, w,h)
		horizontal_slider.type = "horizontal_slider_element"
		horizontal_slider.style = {
			horizontal_slider_bg_color = bg_color
		}
		local drag_element = gui.new_draggable_element(horizontal_slider, 0,0, drag_w,h)
		horizontal_slider.drag_element = drag_element

		function horizontal_slider:update()
			self.drag_element.style.draw = self:get_style_value("drag_draw")
			self.bg_color = self:get_style_value("bg_color")
			self.border_color = self:get_style_value("border_color")
			self.drag_bg_color = self:get_style_value("drag_bg_color")
			self.drag_down_bg_color = self:get_style_value("drag_down_bg_color")
			self.drag_element.w = drag_w
			self.drag_element.h = self.h
		end
		horizontal_slider:update()

		function horizontal_slider:draw(surface, ox,oy)
			if self.bg_color then
				local r,g,b,a =  unpack(self.bg_color)
				surface:rectangle(ox,oy, self.w, self.h, r,g,b,a, false, true)
			end
			if self.border_color then
				local r,g,b,a =  unpack(self.border_color)
				surface:rectangle(ox,oy, self.w, self.h, r,g,b,a, true, true)
			end
		end
		function horizontal_slider:get_pct()
			local pct = drag_element.x/(horizontal_slider.w-drag_element.w)
			return pct
		end
		function horizontal_slider:set_pct(pct)
			self.drag_element.x = pct*(horizontal_slider.w-drag_element.w)
		end
		local function horizontal_slider_event_handler(self, ev)
			local local_x, local_y = self:global_is_in_element(ev.	x, ev.y)
			local drag_local_x, drag_local_y = self.drag_element:global_is_in_element(ev.	x, ev.y)
			if (ev.type == "mousebuttondown") and local_x and (not drag_local_x) then
					self.drag_element.x = math.min(math.max(local_x-self.drag_element.w*0.5, 0), self.w-self.drag_element.w)
					self.drag_element.down = {x=ev.x, y=ev.y}
					self.drag_element.orig = {x=self.drag_element.x, y=self.drag_element.y}
					--self.drag_element:on_drag(self.drag_element.x, self.drag_element.y)
				return true
			end
		end
		table.insert(horizontal_slider.event_handlers, horizontal_slider_event_handler)


		function drag_element:draw(surface, ox,oy)
			local r,g,b,a =  unpack(self.parent.drag_bg_color)
			if self.down then
				r,g,b,a =  unpack(self.parent.drag_down_bg_color)
			end
			surface:rectangle(ox+1,oy+1, self.w-2, self.h-2, r,g,b,a, false, true)
		end
		function drag_element:on_drag()
			self.parent:on_slide(self.parent:get_pct())
		end

		-- User callback function
		function horizontal_slider:on_slide(pct)
		end

		return horizontal_slider
	end

	-- create a vertical slider(Like a scrollbar)
	function gui.new_vertical_slider_element(parent, x,y, w,h, drag_h, bg_color)
		local vertical_slider = gui.new_element(parent, nil, x,y, w,h)
		vertical_slider.type = "vertical_slider_element"
		vertical_slider.style = {
			vertical_slider_bg_color = bg_color
		}
		vertical_slider.drag_h = drag_h
		local drag_element = gui.new_draggable_element(vertical_slider, 0,0, w, drag_h)
		vertical_slider.drag_element = drag_element

		function vertical_slider:update(_new_pct)
			self.bg_color = self:get_style_value("bg_color")
			self.border_color = self:get_style_value("border_color")
			self.drag_bg_color = self:get_style_value("drag_bg_color")
			self.drag_down_bg_color = self:get_style_value("drag_down_bg_color")
			self.drag_element.w = self.w
			self.drag_element.h = self.drag_h
			if _new_pct then
				self.drag_element.x = _new_pct*(self.w-self.drag_element.w)
			end
		end
		vertical_slider:update(0)

		function vertical_slider:draw(surface, ox,oy)
			if self.bg_color then
				local r,g,b,a =  unpack(self.bg_color)
				surface:rectangle(ox,oy, self.w, self.h, r,g,b,a, false, true)
			end
			if self.border_color then
				local r,g,b,a =  unpack(self.border_color)
				surface:rectangle(ox,oy, self.w, self.h, r,g,b,a, true, true)
			end
		end
		function vertical_slider:get_pct()
			local pct = drag_element.y/(self.h-self.drag_element.h)
			return pct
		end
		function vertical_slider:set_pct(pct)
			self.drag_element.x = pct*(self.w-self.drag_element.w)
		end

		function drag_element:draw(surface, ox,oy)
			local r,g,b,a
			if self.parent.drag_bg_color then
				r,g,b,a =  unpack(self.parent.drag_bg_color)
			end
			if self.down and self.parent.drag_down_bg_color then
				r,g,b,a =  unpack(self.parent.drag_down_bg_color)
			end
			if r then
				surface:rectangle(ox+1,oy+1, self.w-2, self.h-2, r,g,b,a, false, true)
			end
		end
		function drag_element:on_drag()
			self.parent:on_slide(self.parent:get_pct())
		end

		-- User callback function
		function vertical_slider:on_slide(pct)
		end

		return vertical_slider
	end
end
