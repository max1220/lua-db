local event_loop = require("lua-db.event_loop")

local application = {}

--local debug_print = function() end
local debug_print = print


-- An application is a collection of interfaces, added to a application table,
-- that coordinate via event loops. After the basic set of interfaces are
-- loaded(output "drivers", etc.), the application table typically contains
-- some callbacks, (like an :on_draw() function) that can be set to create
-- interactive applications.
-- Ideally, by implementing the callbacks correctly one can create an
-- application that runs on all supported input and output device combinations
-- supported by the drivers.
function application.new(ev_loop)
	local app = {}
	debug_print("Created new application: ", tostring(app))

	app.run = false -- is the application currently running?
	app.ev_loop = ev_loop or event_loop.new() -- the event loop for the application we're preparing.
	app.ev_client = event_loop.new_client() -- the event_loop client for updating the internal logic of an app instance
	app.ev_client.app = app -- used in app.ev_client:on_update()
	app.ev_loop:add_client(app.ev_client) -- add client to event loop
	event_loop.client_sugar_event_callbacks(app.ev_client) -- automatic app.ev_client:on_EVENT_NAME(data) functions

	debug_print("Application event loop: ", tostring(app.ev_loop))
	debug_print("Base event client: ", tostring(app.ev_client))

	app.enable_mouse_inputs = true
	app.enable_mouse_input_rel = true -- app requires relative-style mouse inputs(deltas)
	app.enable_mouse_input_abs = true -- app requires absolute-style mouse inputs(positions)
	app.mouse_inputs = {} -- list of mouse input sources

	-- perform mostly automatic initialization
	function app:init_auto()
		-- add graphics output capabillities to application
		local graphics_output = require("lua-db.application.graphics_output")
		graphics_output.add_to_application(self)

		local graphics_output_sdl = require("lua-db.application.graphics_output_sdl")
		graphics_output_sdl.add_to_application(self)

		local graphics_output_drm = require("lua-db.application.graphics_output_drm")
		graphics_output_drm.add_to_application(self)

		local graphics_output_framebuffer = require("lua-db.application.graphics_output_framebuffer")
		graphics_output_framebuffer.add_to_application(self)

		-- add keyboard input capabillities to application
		local keyboard_input = require("lua-db.application.keyboard_input")
		keyboard_input.add_to_application(self)

		-- add mouse input capabillities to application
		local mouse_input = require("lua-db.application.mouse_input")
		mouse_input.add_to_application(self)

		-- auto-configure an output(SDL, framebuffer, etc.)
		self:auto_add_graphics_output()

		-- auto-configure a keyboard input(from SDL events, Linux uinput, terminal, etc.)
		self:auto_add_keyboard_input()

		-- auto-configure a mouse input(from SDL events, Linux uinput, terminal, etc.)
		self:auto_add_mouse_input()
	end

	-- run the event loop untill the application terminates.
	function app:run_ev_loop()
		debug_print("Running application using internal event loop:", tostring(self.ev_loop))
		self.run = true
		while self.run do
			self.ev_loop:update()
		end
		debug_print("Stopped")
	end
	-- TODO: Implement a "proxy" run for embedding in another application

	-- main update function called in the event loop
	function app.ev_client:on_update(dt)
		if self.app.on_update then
			self.app:on_update(dt)
		end
	end

	-- user callback function called every update iteration
	function app:on_update(dt) end

	return app
end

return application
