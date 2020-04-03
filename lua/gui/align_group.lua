return function(gui)
	gui:append_style("horizontal_group_element", {
		spacing = 3,
	})
	gui:append_style("vertical_group_element", {
		spacing = 3,
	})

	-- create a new group that stacks it's children elements horizontaly
	function gui.new_horizontal_group_element(parent, x,y, w,h, align, spacing)
		local horizontal_group = gui.new_element(parent, nil, x,y, w,h)
		horizontal_group.type = "horizontal_group_element"

		horizontal_group.align = align or "left"
		horizontal_group.style.spacing = tonumber(spacing) or 0

		-- update alignment and spacing
		function horizontal_group:update()
			self.element_spacing = self:get_style_value("spacing", true)
			if self.align == "left" then
				self:align_left()
			elseif self.align == "center" then
				self:align_center()
			elseif self.align == "right" then
				self:align_right()
			end
		end

		-- get the combined width of the child elements in the group and the element spacing
		function horizontal_group:get_children_width()
			local width = 0
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					width = width + child.w + self.element_spacing
				end
			end
			width = width - self.element_spacing
			return width
		end

		-- reposition child elements to the left side
		function horizontal_group:align_left()
			local cx = 0
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					child.x = cx
					cx = cx + child.w + self.element_spacing
				end
			end
		end

		-- reposition child elements so that the group of elements is center
		function horizontal_group:align_center()
			local group_w = self:get_children_width()
			local cx = self.w*0.5-group_w*0.5
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					child.x = cx
					cx = cx + child.w + self.element_spacing
				end
			end
		end

		-- reposition child elements to the right side
		function horizontal_group:align_right()
			local group_w = self:get_children_width()
			local cx = self.w-group_w
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					child.x = cx
					cx = cx + child.w + self.element_spacing
				end
			end
		end

		horizontal_group:update()

		return horizontal_group
	end



	-- create a new group that stacks it's children elements verticaly
	function gui.new_vertical_group_element(parent, x,y, w,h, align, spacing)
		local vertical_group = gui.new_element(parent, nil, x,y, w,h)
		vertical_group.type = "vertical_group_element"

		vertical_group.align = align or "left"
		vertical_group.style.spacing = tonumber(spacing) or 0

		-- update alignment and spacing
		function vertical_group:update()
			self.element_spacing = self:get_style_value("spacing", true)
			if self.align == "top" then
				self:align_top()
			elseif self.align == "center" then
				self:align_center()
			elseif self.align == "bottom" then
				self:align_bottom()
			end
		end

		-- get the combined height of the child elements in the group and the element spacing
		function vertical_group:get_children_height()
			local height = 0
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					height = height + child.h + self.element_spacing
				end
			end
			height = height - self.element_spacing
			return height
		end

		-- reposition child elements to the left side
		function vertical_group:align_top()
			local cy = 0
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					child.y = cy
					cy = cy + child.h + self.element_spacing
				end
			end
		end

		-- reposition child elements so that the group of elements is center
		function vertical_group:align_center()
			local group_h = self:get_children_height()
			local cy = self.h*0.5-group_h*0.5
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					child.y = cy
					cy = cy + child.h + self.element_spacing
				end
			end
		end

		-- reposition child elements to the right side
		function vertical_group:align_bottom()
			local group_h = self:get_children_height()
			local cy = self.h-group_h
			for _, child in ipairs(self.children) do
				if not child.ignore_flow then
					child.y = cy
					cy = cy + child.h + self.element_spacing
				end
			end
		end

		vertical_group:update()

		return vertical_group
	end
end
