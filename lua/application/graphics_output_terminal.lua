-- this table get overloaded into the main application table when creating a new application instance
local app = {}

-- This module implements supports for outputing graphics to a terminal.

-- return a output table for a terminal-like output.
function app:new_output_terminal(config)
	local ldb_core = require("ldb_core")
	local terminal = require("lua-db.terminal")

	local output = self:new_output_base(config)
	output.type = "output_terminal"
	self:debug_print("New terminal output: ", tostring(output))

	local term_type = assert(config.terminal_type)
	local unicode = assert(config.enable_unicode)

	local term = terminal.new_terminal_getch(term_type, unicode)
	if not term then
		return
	end

	local w,h = term:get_screen_size()
	if not w then
		self:debug_print("Can't determine terminal size!")
		os.exit(1)
	end
	local pixels_per_char_x = 1
	local pixels_per_char_y = 1
	output.drawbuffer_to_terminal = term.drawbuffer_characters

	if config.terminal_draw_mode == "colors" then
		output.drawbuffer_to_terminal = term.drawbuffer_colors
	elseif config.terminal_draw_mode == "sextant" then
		output.drawbuffer_to_terminal = term.drawbuffer_sextant
		pixels_per_char_x,pixels_per_char_y = 2,3
	elseif config.terminal_draw_mode == "braile" then
		output.drawbuffer_to_terminal = term.drawbuffer_braile
		pixels_per_char_x,pixels_per_char_y = 2,4
	elseif config.terminal_draw_mode == "quadrants" then
		output.drawbuffer_to_terminal = term.drawbuffer_quadrants
		pixels_per_char_x,pixels_per_char_y = 2,2
	elseif config.terminal_draw_mode == "vhalf" then
		output.drawbuffer_to_terminal = term.drawbuffer_vhalf
		pixels_per_char_x,pixels_per_char_y = 1,2
	elseif config.terminal_draw_mode == "hhalf" then
		output.drawbuffer_to_terminal = term.drawbuffer_hhalf
		pixels_per_char_x,pixels_per_char_y = 2,1
	end

	h = (tonumber(config.terminal_force_width) or h or 25)*pixels_per_char_y
	w = (tonumber(config.terminal_force_width) or w or 80)*pixels_per_char_x

	local drawbuffer = ldb_core.new_drawbuffer(w,h)


	function output:before_draw()
		--local str = self.terminal:read(1/30) -- TODO: Make this make more sense.
		local resolved, chars = self.terminal:read_key(1/30)
		self.app.output_ev_client:push_event("internal_terminal_raw_event", self, resolved, chars)
	end
	function output:after_draw()
		-- TODO: Draw using braile etc.
		self.terminal:reset_all()
		self.terminal:set_cursor()

		self.drawbuffer_to_terminal(self.terminal, self.drawbuffer, self.lines_buf)

		for i=1, #self.lines_buf do
			local line = self.lines_buf[i]
			self.terminal:write(table.concat(line))
			if i ~= #self.lines_buf then
				self.terminal:write("\n")
			end
		end
		self.terminal:write()
	end
	function output:on_add()
		-- TODO: set a terminal title?
		-- TODO: Enable the mouse-tracking in the terminal _input_ driver
		os.execute("stty -echo") -- TODO: Replace with native function, maybe in lua-getch?
		self.terminal:hide_cursor()
		self.terminal:alternate_screen_buffer(true)
		if self.config.enable_mouse_tracking then
			self.terminal:mouse_tracking(true)
		end
		self.terminal:reset_all()
		self.enable_debug_output = false -- don't write debug output to terminal!
	end
	function output:on_remove()
		if self.config.enable_mouse_tracking then
			self.terminal:mouse_tracking(false)
		end
		self.terminal:alternate_screen_buffer(false)
		os.execute("stty +echo")
		self.enable_debug_output = true -- don't write debug output to terminal!
	end

	-- fill required fields
	output.enabled = true
	output.width = w
	output.height = h
	output.drawbuffer = drawbuffer

	output.terminal = term
	output.lines_buf = {}

	return output
end

return app
