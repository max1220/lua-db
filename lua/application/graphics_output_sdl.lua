local graphics_output_sdl = {}

--local debug_print = function() end
local debug_print = print


-- add SDL output support to application
-- app events:
--  internal_sdl_raw_event
-- application-callable functions:
--  app:new_output_sdl(config)
--  app:auto_output_sdl()
function graphics_output_sdl.add_to_application(app)

	debug_print("Adding SDL output capabillity to application: ", tostring(app))

	-- turn a generic output prototype table(returned by app:new_output_base, from graphics_output.lua)
	-- into an sdl output table
	function app:new_output_sdl(config)
		local output = self:new_output_base(config)
		debug_print("New SDL output: ", tostring(output))

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
		output.pool_timeout = 0

		function output:before_draw()
			local ev = self.sdlfb:pool_event(self.pool_timeout)
			while ev do
				if ev.type == "quit" then
					debug_print("Output received SDL quit event ", ev, output)
					self.app:remove_output(self)
				--elseif ev.type == "windowevent" then
					-- TODO: On resize event, re-get drawbuffer, push resize event in app.ev_loop, update output etc.
				else
					self.app.ev_loop:push_event("internal_sdl_raw_event", ev)
				end
				ev = self.sdlfb:pool_event(self.pool_timeout)
			end
		end
		function output:after_draw()
			self.sdlfb:update_drawbuffer()
		end
		function output:on_add()
			debug_print("Adding SDL output: ", tostring(self))
		end
		function output:on_remove()
			debug_print("Removing SDL output: ", tostring(self))
		end

		return output
	end

	-- function to try to auto-configure an SDL output module
	function app:auto_output_sdl()
		if pcall(require, "ldb_sdl") and os.getenv("DISPLAY") then
			local sdl_config = {
				width = 800, -- TODO
				height = 600
			}
			local output = self:new_output_sdl(sdl_config)
			return output
		end
	end
end

return graphics_output_sdl
