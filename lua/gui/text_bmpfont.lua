--luacheck: no max line length

return function(gui)
	gui:append_style("text_element_bmpfont", {
		bmpfont = nil,
		padding = 0,
	})

	-- creates a new text element.
	function gui.new_text_element_bmpfont(parent, bmpfont, x,y, padding, text)
		local text_element = gui.new_element(parent, nil, x,y, 0,0)
		text_element.type = "text_element_bmpfont"
		text_element.style = {
			bmpfont = bmpfont,
			padding = padding,
		}
		text_element.text = tostring(assert(text))

		function text_element:update(_new_text)
			local new_text = _new_text or self.text or ""
			self.bmpfont = self:get_style_value("bmpfont", true)
			self.padding = self:get_style_value("padding", true)
			self.w = 2*self.padding + self.bmpfont:length_text(new_text)
			self.h = 2*self.padding + self.bmpfont.char_h*self.bmpfont.scale_y
			self.text = new_text
		end
		text_element:update(text)

		function text_element:draw(target_surface, ox,oy)
			self.bmpfont:draw_text(target_surface, self.text, ox+self.padding,oy+self.padding)
		end

		return text_element
	end

end
