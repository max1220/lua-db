local event_loop = require("lua-db.event_loop")

local application = {}

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

	app.run = false -- is the application currently running?
	app.ev_loop = ev_loop or event_loop.new() -- the event loop for the application we're preparing.
	app.ev_client = event_loop.new_client() -- the event_loop client for updating the internal logic of an app instance
	app.ev_client.app = app -- used in app.ev_client:on_update()
	app.ev_loop:add_client(app.ev_client) -- add client to event loop
	event_loop.client_sugar_event_callbacks(app.ev_client) -- automatic app.ev_client:on_EVENT_NAME(data) functions

	-- Create a debug log function that can optionally disable output to stdout at runtime, for terminal applications.
	app.debug_log = {}
	app.enable_debug_output = true
	app.log_file = io.stderr
	app.debug_print = function(self, ...)
		if not self.enable_debug_output then
			return
		end
		local t = {...}
		for k,v in ipairs(t) do
			t[k] = tostring(v)
		end
		self.log_file:write(table.concat(t, "\t"), "\n")
		self.log_file:flush()
		table.insert(self.debug_log, t)
	end

	app:debug_print("New Application: ", app)
	app:debug_print("Application event loop: ", app.ev_loop)
	app:debug_print("Base event client: ", app.ev_client)

	-- recursively copy content from source to target
	local function merge(target, source)
		for k,v in pairs(source) do
			if target[k] then
				error("Application Require merge conflict!")
			elseif type(v) == "table" then
				target[k] = merge({}, v)
			else
				target[k] = v
			end
		end
		return target
	end

	-- load an application module, by deep-copying the loaded module table over the application.
	function app:require(module)
		merge(self, require(module))
	end

	function app:load_default_modules()
		-- add graphics output capabilities to application
		self:require("lua-db.application.graphics_output")

		-- load output "drivers"
		self:require("lua-db.application.graphics_output_sdl")
		self:require("lua-db.application.graphics_output_drm")
		self:require("lua-db.application.graphics_output_framebuffer")
		self:require("lua-db.application.graphics_output_terminal")

		-- add interactive input capabilities to application
		self:require("lua-db.application.interactive_input")
		self:require("lua-db.application.interactive_input_keyboard")
		self:require("lua-db.application.interactive_input_mouse")

		-- load input "drivers"(TODO: SDL input driver requires the SDL output to be already loaded)
		self:require("lua-db.application.interactive_input_sdl")
		self:require("lua-db.application.interactive_input_terminal")
		--require("lua-db.application.interactive_input_terminal").add_to_application(self)


	end

	-- perform mostly automatic initialization and configuration
	function app:auto_configuration()
		-- perform graphics initialization
		self:init_graphics_output()

		-- auto-configure an output(SDL, framebuffer, etc.)
		self:auto_add_graphics_output()

		-- perform input initialization
		self:init_interactive_input()

		-- auto-configure input devices(Some inputs require an output to be available!)
		self:auto_add_interactive_input()
	end

	-- run the event loop until the application terminates.
	function app:run_ev_loop()
		self:debug_print("Running application using internal event loop:", tostring(self.ev_loop))
		self.run = true
		while self.run do
			self.ev_loop:update()
		end
		self:debug_print("Stopped")
	end
	-- TODO: Implement a "proxy" run for embedding in another application

	-- main update function called in the event loop
	function app.ev_client:on_update(dt)
		-- call graphics module update
		if self.app.update_interactive_input  then
			self.app:update_interactive_input(dt)
		end

		-- call user on_update function
		if self.app.on_update then
			self.app:on_update(dt)
		end

		-- call graphics module update
		if self.app.enable_graphics  then
			self.app:update_graphics_output(dt)
		end
	end

	-- user callback function called every update iteration
	function app:on_update(dt) end

	return app
end

return application
