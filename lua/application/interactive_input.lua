local event_loop = require("lua-db.event_loop")

-- this table get overloaded into the main application table when creating a new application instance
local app = {}
app.enable_input = true

-- This module adds interactive input capabillities to an application.

-- Initialize the input system(create an event client for the drivers, set global callbacks, etc.)
-- This function does not add a input devices automatically!
function app:init_interactive_input()
	self:debug_print("init_interactive_input: ", self)

	self.input_ev_client = event_loop.new_client()
	self.input_ev_client.app = self
	self.ev_loop:add_client(self.input_ev_client)
	event_loop.client_sugar_event_callbacks(self.input_ev_client)

	-- dispatcher for SDL events received by an SDL window(in graphics_output_sdl.lua, new_output_sdl().before_draw).
	function self.input_ev_client:on_internal_sdl_raw_event(output, ev)
		--debug_print("on_internal_sdl_raw_event", output, ev)
		if output.sdl_keyboard and ((ev.type == "keydown") or (ev.type == "keyup")) and ev.scancode then
			output.sdl_keyboard:on_sdl_event(ev)
		end
	end

	-- dispatcher for terminal input
	function self.input_ev_client:on_internal_terminal_raw_event(output, resolved, chars)
		--self.app:debug_print("on_internal_terminal_raw_event_resolved", output, resolved)
		if output.terminal_keyboard then
			output.terminal_keyboard:on_terminal_event(resolved, chars)
		end
	end
end

function app:update_interactive_input(dt)
	if self.update_keyboards then
		self:update_keyboards(dt)
	end
	if self.update_mouses then
		self:update_mouses(dt)
	end
end

function app:auto_add_interactive_input()
	self:debug_print("Auto-adding interactive input")
	self.enable_keyboard_inputs_press_release = true

	for i,ioutput in ipairs(self.graphic_outputs) do
		if (ioutput.type == "output_sdl") and self.auto_add_interactive_input_terminal then
			self:auto_add_interactive_input_sdl(ioutput)
		elseif (ioutput.type == "output_terminal") and self.auto_add_interactive_input_terminal then
			self:auto_add_interactive_input_terminal(ioutput)
		end
	end

end

return app
