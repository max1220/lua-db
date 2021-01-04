local graphics_output_drm = {}

--local debug_print = function() end
local debug_print = print


-- add DRM/modeset output support to application
function graphics_output_drm.add_to_application(app)

	debug_print("Adding DRM output capabillity to application: ", tostring(app))

	-- turn a generic output prototype table into an drm output table
	function app:new_output_drm(config)
		local output = self:new_output_base(config)
		debug_print("New DRM output: ", tostring(output))

		local dri_dev_path = assert(config.dri_dev_path)
		local monitor_num = assert(config.monitor_num)

		local ldb_drm = require("ldb_drm")
		local card = ldb_drm.new_card(dri_dev_path)
		if not card then
			return nil
		end
		debug_print("Got card: ", tostring(card))

		local ok, err = card:prepare()
		if not ok then
			debug_print("drm prepare failed: ", tostring(err))
			return nil
		end
		local info = card:get_info()
		if not info[monitor_num] then
			debug_print("drm info failed!")
			return nil
		end
		local monitor_info = info[monitor_num]
		debug_print("Got info: ", tostring(monitor_info))
		for k,v in pairs(monitor_info) do
			debug_print("Got info: ", tostring(k), tostring(v))
		end

		local drawbuffer = card:get_drawbuffer(monitor_num)
		if not drawbuffer then
			debug_print("Getting DRM drawbuffer failed!")
		end

		-- fill required fields
		output.enabled = true
		output.width = monitor_info.width
		output.height = monitor_info.height
		output.drawbuffer = drawbuffer

		output.drm_card = card
		output.drm_info = monitor_info

		return output
	end

	-- try to auto-configure the DRM module
	function app:auto_output_drm()
		if pcall(require, "ldb_drm") then
			local drm_config = {
				dri_dev_path = os.getenv("DRICARD") or "/dev/dri/card0",
				monitor_num = tonumber(os.getenv("DRIMONITORNUM")) or 1,
			}
			local output = self:new_output_drm(drm_config)
			return output
		end
	end

end

return graphics_output_drm
