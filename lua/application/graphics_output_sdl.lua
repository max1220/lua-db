-- this table get overloaded into the main application table when creating a new application instance
local app = {}

-- add SDL output support to application
-- app events:
--  internal_sdl_raw_event
-- application-callable functions:
--  app:new_output_sdl(config)
--  app:auto_output_sdl()

-- turn a generic output prototype table(returned by app:new_output_base, from graphics_output.lua)
-- into an sdl output table
function app:new_output_sdl(config)
	local output = self:new_output_base(config)
	output.type = "output_sdl"
	self:debug_print("New SDL output: ", tostring(output))

	local width, height = assert(tonumber(output.config.width)), assert(tonumber(output.config.height))
	local title = output.config.title or "Untitled"

	local ldb_sdl = require("ldb_sdl")
	local sdlfb = ldb_sdl.new_sdl2fb(width, height, title)
	local drawbuffer = sdlfb:get_drawbuffer()

	-- fill required fields
	output.width = width
	output.height = height
	output.drawbuffer = drawbuffer
	output.enabled = true

	-- usefull for interoperabillity(e.g. SDL input)
	output.sdlfb = sdlfb

	-- how long to wait for SDL events initially?
	output.sdl_pool_timeout_initial = 1/120

	-- how long to wait for SDL events in a loop
	output.sdl_pool_timeout = 0

	function output:before_draw()
		local ev = self.sdlfb:pool_event(self.sdl_pool_timeout_initial)
		while ev do
			-- TODO: On resize event, re-get drawbuffer, push resize event in app.ev_loop, update output etc.
			if ev.type == "quit" then
				self.app:debug_print("Output received SDL quit event ", ev, output)
				self.remove = true
				return
			else
				self.app.output_ev_client:push_event("internal_sdl_raw_event", output, ev)
			end
			ev = self.sdlfb:pool_event(self.sdl_pool_timeout)
		end
	end
	function output:after_draw()
		if self.sdlfb then -- after removing the output in an event handler we might not have a sdlfb
			self.sdlfb:update_drawbuffer()
		end
	end
	function output:on_add()
		self.app:debug_print("Adding SDL output: ", tostring(self))
	end
	function output:on_remove()
		self.app:debug_print("Removing SDL output: ", tostring(self))
		-- TODO: Figure out how removing the SDL inputs etc. should work
		self.drawbuffer:close()
		self.drawbuffer = nil
		self.sdlfb:close()
		self.sdlfb = nil
		self.enabled = false
	end

	return output
end

-- function to try to auto-configure an SDL output module
function app:auto_output_sdl()
	if pcall(require, "ldb_sdl") and os.getenv("DISPLAY") then
		self:debug_print("auto_output_sdl")
		local sdl_config = {
			width = tonumber(self.sdl_width) or 800, -- TODO: Get this from some application-set preference
			height = tonumber(self.sdl_height) or 600
		}
		local output = self:new_output_sdl(sdl_config)
		return output
	end
end

return app
