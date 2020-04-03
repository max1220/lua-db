--luacheck: no max line length

return function(gui)
	gui:append_style("button_element", {
		font = nil,
		padding = 5,
		bg_color = {0,0,0,255},
		border_color = {255,255,255,64},
		hover_bg_color = {255,255,255,32},
		hover_border_color = {255,255,255,32},
		down_bg_color = {255,255,255,48},
		down_border_color = {255,255,255,96},
	})
	gui:append_style("togglebutton_element", {
		on_text = "[#]",
		padding = 5,
		on_bg_color = {0,0,0,255},
		on_border_color = {255,255,255,64},
		off_text = "[ ]",
		off_bg_color = {0,0,0,255},
		off_border_color = {255,255,255,64},
	})

	-- creates a new button element
	function gui.new_button_element(parent, x,y, w,h, text, _bmpfont, bg_color, border_color)
		local button_element = gui.new_element(parent, nil, x,y, w or 0,h or 0)
		button_element.type = "button_element"
		button_element.style = {
			button_bg_color = bg_color,
			button_border_color = border_color,
			bmpfont = _bmpfont
		}

		local padding = button_element:get_style_value("padding", true)
		local bmpfont = button_element:get_style_value("bmpfont", true)
		local text_element = gui.new_text_element_bmpfont(button_element, bmpfont, 0,0, padding, text)
		button_element.text_element = text_element

		button_element.down = false
		button_element.hover = false
		button_element.text_valign = "center"
		button_element.text_halign = "center"
		button_element.autosize = false
		if (not w) or (not h) then
			button_element.autosize = true
		end

		-- center the text element of this button, bases on it's text lenght.
		function button_element:update(new_text)
			self.bg_color = self:get_style_value("bg_color")
			self.down_bg_color = self:get_style_value("down_bg_color")
			self.hover_bg_color = self:get_style_value("hover_bg_color")
			self.border_color = self:get_style_value("border_color")
			self.down_border_color = self:get_style_value("down_border_color")
			self.hover_border_color = self:get_style_value("hover_border_color")
			local _padding = self:get_style_value("padding", true)
			self.text_element.padding = _padding
			self.text_element.style.bmpfont = self:get_style_value("bmpfont", true)
			self.text_element:update(new_text)
			if self.autosize then
				self.w = self.text_element.w
				self.h = self.text_element.h
			end
			self.text_element:align_in_parent(self.text_valign, self.text_halign)
		end
		button_element:update()

		-- draw the button element
		function button_element:draw(target_surface, ox,oy)
			if self.bg_color then
				local r,g,b,a = unpack(self.bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end
			if self.hover and self.hover_bg_color then
				local r,g,b,a = unpack(self.hover_bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end
			if self.down and self.down_bg_color then
				local r,g,b,a = unpack(self.down_bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end

			if self.border_color then
				local r,g,b,a = unpack(self.border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			end
			if self.hover and self.hover_border_color then
				local r,g,b,a = unpack(self.hover_border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			end
			if self.down and self.down_border_color then
				local r,g,b,a = unpack(self.down_border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			end
		end

		-- an event reached the button. Update down and hover state, call callbacks if clicked
		local function button_element_event_handler(self, ev)
			local local_x, local_y = self:global_is_in_element(ev.x, ev.y)
			if ev.type == "mousebuttondown" and local_x then
				self.down = true
				return true
			end
			if ev.type == "mousemotion" and local_x then
				self.hover = true
				--return true
			elseif ev.type == "mousemotion" then
				self.hover = false
			end
			if ev.type == "mousebuttonup" and local_x and self.down then
				if self.on_click and ev.button==1 then
					self:on_click(local_x, local_y)
				elseif self.on_mmb and ev.button==2 then
					self:on_mmb(local_x, local_y)
				elseif self.on_rightclick and ev.button==3 then
					self:on_rightclick(local_x, local_y)
				end
				self.down = false
			elseif ev.type == "mousebuttonup" then
				self.down = false
			end
		end
		table.insert(button_element.event_handlers, button_element_event_handler)

		return button_element
	end






	-- creates a new toggle button element
	function gui.new_button_toggle_element(parent, x,y, w,h, text_on, text_off, bmpfont, _state, bg_color, border_color)
		local togglebutton_element = gui.new_button_element(parent, x,y, w,h, _state and text_on or text_off, bmpfont, bg_color, border_color)
		togglebutton_element.type = "togglebutton_element"
		togglebutton_element.style = {
			on_text = text_on,
			off_text = text_off,
			on_bg_color = bg_color,
			off_bg_color = bg_color,
			on_border_color = border_color,
			off_border_color = border_color,
			bmpfont = togglebutton_element or bmpfont
		}
		togglebutton_element.state = _state

		function togglebutton_element:update(new_text)
			self.down_bg_color = self:get_style_value("down_bg_color")
			self.hover_bg_color = self:get_style_value("hover_bg_color")
			self.down_border_color = self:get_style_value("down_border_color")
			self.hover_border_color = self:get_style_value("hover_border_color")
			self.on_bg_color = self:get_style_value("on_bg_color")
			self.off_bg_color = self:get_style_value("off_bg_color")
			self.on_border_color = self:get_style_value("on_border_color")
			self.off_border_color = self:get_style_value("off_border_color")
			self.text_on = self:get_style_value("on_text")
			self.text_off = self:get_style_value("off_text")

			local _padding = self:get_style_value("padding", true)
			self.text_element.padding = _padding
			self.text_element:update(new_text)
			if self.autosize then
				self.w = self.text_element.w
				self.h = self.text_element.h
			end
			self.text_element:align_in_parent(self.text_valign, self.text_halign)
		end
		togglebutton_element:update()


		-- toggle the togglebutton, change internal state and call callbacks
		function togglebutton_element:on_click()
			self.state = not self.state
			if self.state then
				self:update(self.text_on)
				self:on_toggle_on()
			else
				self:update(self.text_off)
				self:on_toggle_off()
			end
			self:on_toggle(self.state)
		end

		-- draw the togglebutton to a surface
		function togglebutton_element:draw(target_surface, ox,oy)
			if self.state and self.on_bg_color then
				local r,g,b,a = unpack(self.on_bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end
			if (not self.state) and self.off_bg_color then
				local r,g,b,a = unpack(self.off_bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end
			if self.hover and self.hover_bg_color then
				local r,g,b,a = unpack(self.hover_bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end
			if self.down and self.down_bg_color then
				local r,g,b,a = unpack(self.down_bg_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, false, true)
			end

			if self.state and self.on_border_color then
				local r,g,b,a = unpack(self.on_border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			elseif (not self.state) and self.off_border_color then
				local r,g,b,a = unpack(self.off_border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			end
			if self.hover and self.hover_border_color then
				local r,g,b,a = unpack(self.hover_border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			end
			if self.down and self.down_border_color then
				local r,g,b,a = unpack(self.down_border_color)
				target_surface:rectangle(ox,oy,self.w,self.h, r,g,b,a, true, true)
			end
		end

		--luacheck: no unused

		-- User callback
		function togglebutton_element:on_toggle(state)
		end

		-- User callback
		function togglebutton_element:on_toggle_on()
		end

		-- User callback
		function togglebutton_element:on_toggle_off()
		end

		return togglebutton_element
	end
end
