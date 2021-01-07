#!/usr/bin/env luajit
local application = require("lua-db.application.application")
local ldb = require("lua-db") -- make sure drawbuffer mt is set!
local app = application.new() -- create new base application
app:init_auto() -- automatically add output/input


-- set a :on_update function
local running = 0
function app:on_update(dt)
	--print("App update: ", 1/dt)
	running = running + dt
end
function app:on_draw(output, dt)
	--print("App draw for output: ", tostring(output), dt)
	--output.drawbuffer:clear(0,0,0,255)
	output.drawbuffer:clear(0,0,0,255)
	output.drawbuffer:set_px(0, 0, 255,255,255,255)
	output.drawbuffer:set_px(output.width-1, 0, 255,255,255,255)
	output.drawbuffer:set_px(0, output.height-1, 255,255,255,255)
	output.drawbuffer:set_px(output.width-1, output.height-1, 255,255,255,255)
	--output.drawbuffer:rectangle(10+math.sin(running)*5,5, 10, 10, 255,255,255,255)
	--output.drawbuffer:rectangle(0,0, 3, 3, 255,255,255,255)
end

app:run_ev_loop()
