local app = {}

-- This module adds SDL input capabillities to an application.

-- return new keyboard table for an sdl output talbe
function app:new_interactive_input_sdl_keyboard(output)
	if output.sdl_keyboard then
		-- Only one keyboard instance per SDL window
		return output.sdl_keyboard
	end
	assert(output.type == "output_sdl")
	self:debug_print("new interactive_input sdl_keyboard", output)
	local keyboard = self:new_keyboard_input_base()
	keyboard.type = "keyboard_sdl"
	keyboard.sdl_output = output
	keyboard.enabled = true
	output.sdl_keyboard = keyboard

	-- convert the sdl scancode string into the key_names used for all inputs
	function keyboard:sdl_scancode_to_internal(scancode)
		local key_name = (scancode:lower():gsub("%s", "_"))
		if self.app.key_names[key_name] then
			-- only return key_names that actually exist
			return key_name
		else
			self:debug_print("SDL scancode",scancode,"can't be resolved to a key_name!")
		end
	end

	-- gets filtered events from interactive_input.lua, app.input_ev_client:on_internal_sdl_raw_event.
	function keyboard:on_sdl_event(ev)
		--self.app:debug_print("Keyboard",self,"for SDL output",self.sdl_output,"got event",ev.type)
		local key_name = self:sdl_scancode_to_internal(ev.scancode)
		if (ev.type == "keydown") and key_name then
			self:trigger_press_release(key_name, true)
		elseif (ev.type == "keyup") and key_name then
			self:trigger_press_release(key_name, false)
		end
	end
	function keyboard:on_add()
		self.app:debug_print("add sdl keyboard!")
	end
	function keyboard:on_remove()
		self.app:debug_print("remove sdl keyboard!")
	end

	return keyboard
end

function app:auto_add_interactive_input_sdl(output)
	self:debug_print("auto-adding SDL input from output:", output)

	local sdl_keyboard = self:new_interactive_input_sdl_keyboard(output)
	self:add_keyboard_input(sdl_keyboard)

	-- TODO: SDL mouse support
end


return app
