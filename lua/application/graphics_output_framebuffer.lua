-- this table get overloaded into the main application table when creating a new application instance
local app = {}

-- add Linux Framebuffer output support to application

-- creaet a new output object for a framebuffer
function app:new_output_framebuffer(config)
	local output = self:new_output_base(config)
	output.type = "output_framebuffer"
	self:debug_print("New framebuffer output: ", tostring(output))

	local fb_dev_path = assert(config.fb_dev_path)

	local ldb_fb = require("ldb_fb")
	local framebuffer,err = ldb_fb.new_framebuffer(fb_dev_path)
	if not framebuffer then
		self:debug_print("getting framebuffer failed: ", tostring(err))
		return nil
	end
	local finfo = framebuffer:get_fixinfo()
	local vinfo = framebuffer:get_varinfo()
	for k,v in pairs(finfo) do
		self:debug_print("Framebuffer finfo:",k,v)
	end
	for k,v in pairs(vinfo) do
		self:debug_print("Framebuffer vinfo:",k,v)
	end

	local drawbuffer = framebuffer:get_drawbuffer()
	if not drawbuffer then
		self:debug_print("Getting drawbuffer from framebuffer failed!")
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
		self:debug_print("auto_output_framebuffer")
		local fb_config = {
			fb_dev_path = os.getenv("FRAMEBUFFER") or "/dev/fb0",
		}
		local output = self:new_output_framebuffer(fb_config)
		return output
	end
end

return app
