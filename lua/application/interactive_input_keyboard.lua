local time = require("lua-db.time")

local app = {}

-- add keyboard input capabillities to an application.
-- Does not add a keyboard device automatically!
-- this file contains code shared between modules, e.g. common translation
-- between event types, user facing callbacks, common event trigger functions, global handlers(:on_update), etc.

app.enable_keyboard_inputs = true -- enable keyboard input module
app.enable_keyboard_inputs_terminal = false -- app requires terminal-style input events
app.enable_keyboard_inputs_press_release = false -- app requires press-release input events. Also provides key state table
app.keyboard_inputs = {} -- list of keyboard input sources#
app.key_names = require("lua-db.application.key_names") -- load a list of shared(across different input implementations) key_names

function app:new_keyboard_input_base()
	local keyboard = {}
	self:debug_print("New base keyboard input: ", tostring(keyboard))

	keyboard.type = "keyboard_base"
	keyboard.enabled = false -- should this keyboard be used for the application?
	keyboard.translate_events = true -- perform event translation if needed?
	keyboard.translate_target  = "press_release" -- The target event type for this keyboard("press_release", "terminal")
	keyboard.key_state = {} -- state of all keys(Only available id press_release or translated to press_release)
	keyboard.last_down = {} -- last time the key was pressed
	keyboard.app = self

	-- functions used in drivers to push an event of this type. automatically translates, if needed
	-- state is assumed to evaluate to true if a key is down, false otherwise
	function keyboard:trigger_press_release(key_name, state)
		if not self.enabled then
			return
		end
		self.app.input_ev_client:push_event("input_keyboard_press_release", key_name, state)
		if self.translate_events and self.translate_target~="press_release" then
			self.app:debug_print("TODO: Implement event translation from press_release to terminal style events")
		end
		--self.app:debug_print("keyboard:", key_name, state, self.key_state[key_name])
		-- only trigger callbacks on an actual state change, not on key repeats
		if state and (not self.key_state[key_name]) then -- from key is normal to key is pressed
			self.key_state[key_name] = true
			self.last_down[key_name] = time.gettime_monotonic()
			self:state_change()
			if self.app.on_key_down then
				self.app:on_key_down(keyboard, key_name)
			end
			if self.app["on_key_down_"..key_name] then
				self.app["on_key_down_"..key_name](self.app,self)
			end
		elseif (not state) and self.key_state[key_name] then -- from key is pressed to key is normal
			self.key_state[key_name] = false
			self.last_down[key_name] = time.gettime_monotonic()
			self:state_change()
			if self.app.on_key_up then
				self.app:on_key_up(keyboard, key_name)
			end
			if self.app["on_key_up_"..key_name] then
				self.app["on_key_up_"..key_name](self.app,self)
			end
		end
	end
	function keyboard:trigger_terminal(resolved, chars)
		if not self.enabled then
			return
		end
		self.app.input_ev_client:push_event("input_keyboard_terminal", self, sequence)
		if self.translate_events and self.translate_target~="terminal" then
			self.app:debug_print("TODO: Implement event translation from terminal to press_release style events")
			-- TODO: call self:trigger_press_release(key_name, true), wait, call self:trigger_press_release(key_name, false)
		end
	end

	function keyboard:state_change()
		if self.on_state_change then
			self.app.input_ev_client:push_event("input_keyboard_state", self)
			self:on_state_change()
		end
	end

	-- driver callback function(e.g. check for events on the device)
	function keyboard:update()end

	return keyboard
end

function app:add_keyboard_input(keyboard)
	self:debug_print("Adding keyboard:", keyboard, keyboard.type)
	if keyboard.on_add then
		keyboard:on_add()
	end
	self.input_ev_client:push_event("input_add_keyboard_input_event", keyboard)
	table.insert(self.keyboard_inputs, keyboard)
end

function app:remove_keyboard_input(keyboard)
	for i,ikeyboard in ipairs(self.keyboard_inputs) do
		if ikeyboard == keyboard then
			self:debug_print("Remove keyboard: ", keyboard, keyboard.type)
			table.remove(self.keyboard_inputs, i)
			if keyboard.on_remove then
				keyboard:on_remove()
			end
			app.output_ev_client:push_event("input_remove_keyboard_input_event", keyboard)
			return true
		end
	end
end

function app:update_keyboards(dt)
	if self.enable_keyboard_inputs then
		--self:debug_print("Update keyboards")
		for i,ikeyboard in ipairs(self.keyboard_inputs) do
			ikeyboard:update(dt)
		end
	end
end


return app
