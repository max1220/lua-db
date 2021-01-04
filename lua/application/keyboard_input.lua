local event_loop = require("lua-db.event_loop")

local keyboard_input = {}

--local debug_print = function() end
local debug_print = print


-- add keyboard input capabillities to an application.
-- Does not add a keyboard device automatically!
function keyboard_input.add_to_application(app)
	app.enable_keyboard_inputs = true -- enable keyboard input module
	app.enable_keyboard_inputs_terminal = false -- app requires terminal-style input events
	app.enable_keyboard_inputs_press_release = false -- app requires press-release input events
	app.enable_keyboard_inputs_state = false -- app requires key state tables
	app.keyboard_inputs = {} -- list of keyboard input sources

	app.keyboard_ev_client = event_loop.new_client()
	app.keyboard_ev_client.app = app
	app.ev_loop:add_client(app.keyboard_ev_client) -- add graphics client to event loop

	-- called every iteration from the keyboard_ev_client, (client for the app.ev_loop)
	function app.keyboard_ev_client:on_update(dt)
		if self.app.enable_keyboard_inputs then
			self.app:update_keyboards(dt)
		end
	end

	function app:update_keyboards(dt)
		--debug_print("TODO: Update keyboards")
	end

	function app:auto_add_keyboard_input()
		debug_print("TODO: Auto add keyboards")
	end
end

return keyboard_input
