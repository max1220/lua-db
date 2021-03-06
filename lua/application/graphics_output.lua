local event_loop = require("lua-db.event_loop")

-- this table get overloaded into the main application table when creating a new application instance
local app = {}

-- This module adds graphics output capabillities to an application.
-- Use app:auto_add_graphics_output() or add output manually using app:add_output(output).
-- See app:new_output_base() for required fields in the output table.
-- app events:
--  graphics_add_output_event
--  graphics_remove_output_event
-- application-callable functions:
--  app:add_output(output)
--  app:remove_output
--  app:auto_add_graphics_output()
-- application callbacks:
--  app:on_draw(output, dt)

-- default configuration:
app.enable_graphics = true -- enable graphics output module
app.quit_on_last_output_remove = true -- stop the running application if all outputs are closed?
app.graphic_outputs = {} -- list of outputs and info about outputs

function app:init_graphics_output()
	self:debug_print("init_graphics_output: ", self)

	self.output_ev_client = event_loop.new_client()
	self.output_ev_client.app = self
	self.ev_loop:add_client(self.output_ev_client)
	event_loop.client_sugar_event_callbacks(self.output_ev_client)
end

-- called every iteration from the main ev_client:on_update(in application.lua).
function app:update_graphics_output(dt)
	--self:debug_print("update_graphics_output: ", self, dt)
	if self.enable_graphics then
		for _,output in ipairs(self.graphic_outputs) do
			if output.enabled then
				self:update_output(output, dt)
			end

		end
		for i,output in ipairs(self.graphic_outputs) do
			if output.remove then
				self:debug_print("Remove output: ", output, output.type)
				table.remove(self.graphic_outputs, i)
				if output.on_remove then
					output:on_remove()
				end
				self.output_ev_client:push_event("graphics_remove_output_event", output)
				if self.quit_on_last_output_remove then
					self.run = false
				end
				break
			end
		end
	end
end

-- called to update the specified output if enabled
function app:update_output(output, dt)
	--debug_print("Updating output: ", output, dt)
	if output.before_draw then
		output:before_draw() -- call driver pre-user draw function
	end
	if self.on_draw then
		self:on_draw(output, dt) -- call user draw function for output
	end
	if output.after_draw then
		output:after_draw() -- call driver after_draw function
	end
end

-- add an output to this application
function app:add_output(output)
	for _,v in ipairs(self.graphic_outputs) do
		if v == output then
			return output -- don't add outputs twice
		end
	end

	self:debug_print("Add output: ", output, output.type)
	table.insert(self.graphic_outputs, output)
	if output.on_add then
		output:on_add()
	end
	self.output_ev_client:push_event("graphics_add_output_event", output)
	return output
end

-- remove an output from this application
--function app:remove_output(output)
--end

-- return a new generic output prototype table.
function app:new_output_base(config)
	local output = {}
	self:debug_print("New base output: ", tostring(output))

	output.type = "output_base" -- name for this type of output device
	output.app = self -- required, reference to application this output is used with.
	output.enabled = false -- if set truethy enables this output(otherwise this device is ignored)
	output.config = config -- Store driver configuration here using the config parameter! (Not strictly required, but almost always needed)
	output.x_offset = 0 -- set to 0 if not applicable
	output.y_offset = 0 -- set to 0 if not applicable

	output.width = nil -- required to be filled in by driver
	output.height = nil -- required to be filled in by driver
	output.drawbuffer = nil -- required to be filled in by driver

	-- driver callback function called when removing this output
	--function output:on_remove() end

	-- driver callback function called when adding this output
	--function output:on_add() end

	-- driver callback function called before the user draw happens
	--function output:before_draw() end

	-- driver callback function called after the user draw happens
	--function output:after_draw() end

	return output
end

-- attempt to automatically configure graphics output.
-- if the DISPLAY envirioment variable is set, attempts to use the SDL output.
-- Otherwise, DRM is tried, then framebuffer. Then the user is asked about
-- output configuration on the terminal.
function app:auto_add_graphics_output()
	self:debug_print("Auto-adding a graphics output.")
	local output

	if self.auto_output_sdl then
		output = self:auto_output_sdl()
		if output then
			self:debug_print("Auto-configuration output returned for SDL: ", tostring(output))
		end
	end

	if not output and self.auto_output_drm then
		output = self:auto_output_drm()
		if output then
			self:debug_print("Auto-configuration output returned for DRM: ", tostring(output))
		end
	end

	if not output and self.auto_output_framebuffer then
		output = self:auto_output_framebuffer()
		if output then
			self:debug_print("Auto-configuration output returned for Framebuffer: ", tostring(output))
		end
	end

	if not output then
		output = self:new_output_terminal({
			enable_unicode = true,
			terminal_type = "ansi_24bit",
			enable_mouse_tracking = true,
			--terminal_draw_mode = "braile"
			terminal_draw_mode = "colors"
		})
	end

	while not output do
		-- ask the user for an output subsystem suggestion.
		print("The application has requested graphical output capabillities, but auto-configuration failed.")
		print("Options:")
		print(" term - Run in terminal(requires unicode and ANSI 24-bit color escape support)")
		print(" term_basic - Run in a basic terminal")
		print(" sdl [width] [height] [title]")
		print(" drm [dri_path]")
		print(" fb [fb_path]")
		print(" exit - stop application")

		io.write(">")
		local input = io.read("*l")
		if input == "exit" then
			-- TODO: Check if this causes issues when embedding into other applications
			print("Terminating...")
			os.exit(0)
		elseif (input == "term") or (input == "term_basic") then
			local basic = (input == "term_basic")
			local term_config = {
				enable_unicode = not basic,
				terminal_type = basic and "linux" or "ansi_24bit",
				terminal_draw_mode = basic and "characters" or "colors",
				enable_mouse_tracking = not basic,
			}
			output = self:new_output_terminal(term_config)
		elseif input:match("^sdl") then
			local w,h = input:match("^sdl (%d+) (%d+)")
			local title = input:match("^sdl %d+ %d+ .+$")
			local sdl_config = {
				width = tonumber(w) or 800,
				height = tonumber(h) or 600,
				title = title
			}
			output = self:new_output_sdl(sdl_config)
		elseif input:match("^drm") then
			local monitor_num = input:match("^drm (%d+)")
			local dri_dev = input:match("^drm %d+ .+$")
			local drm_config = {
				dri_dev_path = dri_dev,
				monitor_num = monitor_num
			}
			output = self:new_output_drm(drm_config)
		elseif input:match("^fb") then
			local fb_dev = input:match("^fb .+$")
			local fb_config = {
				fb_dev_path = fb_dev
			}
			output = self:new_output_framebuffer(fb_config)
		end
	end

	if output then
		self:debug_print("configured an output:", output, output.type)
		return self:add_output(output)
	end
end

return app
