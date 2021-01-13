-- this table get overloaded into the main application table when creating a new application instance
local app = {}

-- This module adds DRM/modeset output support to application

-- Return a output table for a drm output
function app:new_output_drm(config)
	local output = self:new_output_base(config)
	output.type = "output_drm"
	self:debug_print("New DRM output: ", tostring(output))

	local dri_dev_path = assert(config.dri_dev_path)
	local monitor_num = assert(config.monitor_num)

	local ldb_drm = require("ldb_drm")
	local card = ldb_drm.new_card(dri_dev_path)
	if not card then
		return nil
	end
	self:debug_print("Got card: ", tostring(card))

	local ok, err = card:prepare()
	if not ok then
		self:debug_print("drm prepare failed: ", tostring(err))
		return nil
	end
	local info = card:get_info()
	if not info[monitor_num] then
		self:debug_print("drm info failed!")
		return nil
	end
	local monitor_info = info[monitor_num]
	self:debug_print("Got info: ", tostring(monitor_info))
	for k,v in pairs(monitor_info) do
		self:debug_print("Got info: ", tostring(k), tostring(v))
	end

	local drawbuffer = card:get_drawbuffer(monitor_num)
	if not drawbuffer then
		self:debug_print("Getting DRM drawbuffer failed!")
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


return app
