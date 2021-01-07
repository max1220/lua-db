local event_loop = require("lua-db.event_loop")

local mouse_input = {}

--local debug_print = function() end
local debug_print = print


-- add keyboard input capabillities to an application.
-- Does not add a keyboard device automatically!
function mouse_input.add_to_application(app)
	app.enable_mouse_inputs = true
	app.enable_mouse_input_rel = true -- app requires relative-style mouse inputs(deltas)
	app.enable_mouse_input_abs = true -- app requires absolute-style mouse inputs(positions)
	app.mouse_inputs = {} -- list of mouse input sources

	function app:auto_add_mouse_input()
		debug_print("TODO: Auto add mouse")
	end

	function app:new_mouse_input_sdl()
		-- This requires the SDL output to be enabled first!

	end
end

return mouse_input
