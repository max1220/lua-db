#!/usr/bin/env luajit
local ldb = require("lua-db") -- make sure drawbuffer mt is set!
local app = require("lua-db.application.application").new() -- create new base application
app:load_default_modules() -- load default list of modules

-- set a :on_update callback function
local running = 0
function app:on_update(dt)
	running = running + dt
	--print(("FPS: %5.2f(dt: %5.2f) running: %8.2f"):format(1/dt,dt,running))
end
function app:on_draw(output, dt)
	output.drawbuffer:clear(0,0,0,255)
	local r,g,b = ldb.hsv_to_rgb((running*0.1)%1, 1,1)
	output.drawbuffer:rectangle((math.sin(running)+1)*(output.width-40)*0.5+10,10, 20, 20, r,g,b,255)
end

function app:on_key_up(key_name)
	if key_name == "escape" then
		print("Bye!")
		self.run = false
	end
end

app.sdl_width = 640 -- set prefered SDL resolution
app.sdl_height = 480
app.auto_output_sdl = nil -- disable auto-outputs other than terminal TODO: Find better way than overwriting callback
app.auto_output_drm = nil
app.auto_output_framebuffer = nil

app:auto_configuration() -- automatically initialize everything(add output/input automatically, etc.)
return app:run_ev_loop() -- start running the application.
