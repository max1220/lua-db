local graphics_output_framebuffer = {}

--local debug_print = function() end
local debug_print = print


-- add DRM/modeset output support to application
function graphics_output_framebuffer.add_to_application(app)

	debug_print("Adding framebuffer output capabillity to application: ", tostring(app))

	function app:new_output_framebuffer(config)
		local output = self:new_output_base(config)
		debug_print("New framebuffer output: ", tostring(output))

		local fb_dev_path = assert(config.fb_dev_path)

		local ldb_fb = require("ldb_fb")
		local framebuffer,err = ldb_fb.new_framebuffer(fb_dev_path)
		if not framebuffer then
			debug_print("getting framebuffer failed: ", tostring(err))
			return nil
		end
		local finfo = framebuffer:get_fixinfo()
		local vinfo = framebuffer:get_varinfo()


		local drawbuffer = framebuffer:get_drawbuffer()
		if not drawbuffer then
			debug_print("Getting drawbuffer from framebuffer failed!")
		end

		-- fill required fields
		output.enabled = true
		output.width = vinfo.xres
		output.height = vinfo.yres
		output.drawbuffer = drawbuffer

		output.framebuffer = framebuffer
		output.vinfo = vinfo
		output.finfo = finfo

		return output
	end


	-- try to auto-configure the Linux Framebuffer module
	function app:auto_output_framebuffer()
		if pcall(require, "ldb_fb") then
			local fb_config = {
				fb_dev_path = os.getenv("FRAMEBUFFER") or "/dev/fb0",
			}
			local output = self:new_output_framebuffer(fb_config)
			return output
		end
	end

end

return graphics_output_framebuffer
