local app = {}

-- TODO: Implement terminal input
-- return new keyboard table for an sdl output talbe
function app:new_interactive_input_terminal_keyboard(output)
	if output.terminal_keyboard then
		-- Only one keyboard instance per SDL window
		return output.terminal_keyboard
	end
	assert(output.type == "output_terminal")
	self:debug_print("new_interactive_input_terminal_keyboard:", output)
	local keyboard = self:new_keyboard_input_base()
	keyboard.enabled = true
	keyboard.type = "keyboard_terminal"
	keyboard.terminal_output = output
	output.terminal_keyboard = keyboard

	function keyboard:update(dt)
		--self.app:debug_print("keyboard update:", dt)
	end

	function keyboard:on_terminal_event(resolved, chars)
		self.app:debug_print("keyboard on_terminal_event", resolved or "", #chars)
	end

	return keyboard
end

function app:auto_add_interactive_input_terminal(output)
	self:debug_print("auto-Adding a terminal keyboard input for terminal output: ", output)
	local keyboard = self:new_interactive_input_terminal_keyboard(output)
	self:add_keyboard_input(keyboard)
end

return app
