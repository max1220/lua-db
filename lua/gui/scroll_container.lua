--luacheck: no max line length
local ldb_core = require("ldb_core")
return function(gui)
	gui:append_style("scroll_container_element", {
		scrollbar_width = 20,
		horizontal_slider_style = {},
		vertical_slider_style = {},
		bg_color = {0,0,0,255}
	})

	-- create a container for a larger element that can be scrolled using two sliders(vertical/horizontals)
	function gui.new_scroll_container_element(parent, x,y, container_w,container_h, scroll_content_w, scroll_content_h)
		local scroll_container_element = gui.new_element(parent, nil, x,y, container_w,container_h)
		scroll_container_element.type = "scroll_container_element"

		function scroll_container_element:global_is_in_element(global_x, global_y)
			local ox, oy = self:get_absolute_position()
			local local_x,local_y = global_x-ox, global_y-oy
			if (local_x>=0) and (local_y>=0) and (local_x<self.w) and (local_y<self.h) then
				return local_x,local_y
			end
		end

		function scroll_container_element:update(new_w, new_h, new_scroll_w, new_scroll_h)
			self.scrollbar_width = self:get_style_value("scrollbar_width", true)
			self.bg_color = self:get_style_value("bg_color", true)
			self.w = new_w or self.w
			self.h = new_h or self.h
			local window_w = self.w-self.scrollbar_width
			local window_h = self.h-self.scrollbar_width
			self.scroll_content.w = new_scroll_w or self.scroll_content.w
			self.scroll_content.h = new_scroll_h or self.scroll_content.h
			self.horizontal_slider.x = 0
			self.horizontal_slider.y = window_h
			self.horizontal_slider.w = window_w
			self.horizontal_slider.h = self.scrollbar_width
			self.horizontal_slider.drag_element.w = (self.w/self.scroll_content.w)*(self.w-self.scrollbar_width)
			self.horizontal_slider.drag_element.h = self.scrollbar_width
			self.vertical_slider.x = window_w
			self.vertical_slider.y = 0
			self.vertical_slider.w = self.scrollbar_width
			self.vertical_slider.h = window_h
			self.vertical_slider.drag_element.w = self.scrollbar_width
			self.vertical_slider.drag_element.h = (self.h/self.scroll_content.h)*(self.h-self.scrollbar_width)

			if (not self.scroll_content.surface) or (self.scroll_content.surface:width()~=window_w) or (self.scroll_content.surface:height()~=window_h) then
				local pxfmt = self.scroll_content.surface and self.scroll_content.surface:pixel_format()
				self.scroll_content.surface = ldb_core.new_drawbuffer(window_w, window_h, pxfmt)
			end
		end

		local horizontal_slider = gui.new_horizontal_slider_element(scroll_container_element, 0, 0, 0, 0, 10)
		scroll_container_element.horizontal_slider = horizontal_slider
		horizontal_slider.scroll_container = scroll_container_element
		function horizontal_slider:on_slide(pct)
			local scroll_x = pct * (-self.parent.scroll_content.w+(self.parent.w-self.parent.scrollbar_width))
			self.scroll_container.scroll_content.x = scroll_x
		end

		local vertical_slider = gui.new_vertical_slider_element(scroll_container_element, 0, 0, 10, 0, 10)
		scroll_container_element.vertical_slider = vertical_slider
		vertical_slider.scroll_container = scroll_container_element
		function vertical_slider:on_slide(pct)
			local scroll_y = pct * (-self.parent.scroll_content.h+(self.parent.h-self.parent.scrollbar_width))
			self.scroll_container.scroll_content.y = scroll_y
		end




		local scroll_content_element = gui.new_element(scroll_container_element, nil, 0,0, scroll_content_w, scroll_content_h)
		scroll_content_element.type = "scroll_content_element"
		scroll_container_element.scroll_content = scroll_content_element
		function scroll_content_element:get_surface()
			return self.surface, self.x, self.y
		end

		function scroll_content_element:handle_draw()
			local targete_surface, target_ox,target_oy = self:get_surface()
			if self.parent.bg_color then
				local r,g,b,a = unpack(self.parent.bg_color)
				self.surface:clear(r,g,b,a)
			end
			self:draw(targete_surface, target_ox, target_oy)
			for _,child in ipairs(self.children) do
				child:handle_draw()
			end
			local parent_surface, parent_ox, parent_oy = self.parent:get_surface()
			self.surface:origin_to_target(parent_surface, parent_ox, parent_oy)
		end

		scroll_container_element:update(container_w,container_h, scroll_content_w, scroll_content_h)

		return scroll_container_element
	end
end
