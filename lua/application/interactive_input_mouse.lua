local app = {}

-- Default configuration
app.enable_mouse_inputs = true
app.enable_mouse_input_rel = true -- app requires relative-style mouse inputs(deltas)
app.enable_mouse_input_abs = true -- app requires absolute-style mouse inputs(positions)
app.mouse_inputs = {} -- list of mouse input sources

function app:auto_add_mouse_input()
	self:debug_print("TODO: Auto add mouse")
end
function app:new_mouse_input_sdl()
	-- This requires the SDL output to be enabled first!
end

return app
