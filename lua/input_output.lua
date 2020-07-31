--[[
this Lua module provides a common interface for all supported output methods
and input modules, so the programs can be made independent on
the input or output format used.
It supportes the following input/output methods:
 * output via SDL, input via SDL
 * output via Linux framebuffer, input via Linux uinput
 * output via ANSI terminal, input via ANSI terminal
To archive this, the Linux uinput and terminal input methods map to
SDL-like input event codes. This mapping is configurable.
]]
--TODO: seperate to multiple files, seperate input handling from output handling(mix and match)
--TODO: drawbuffer for scaling/converting bpp
--TODO: function to get drawbuffer for output(correct bpp/pixel order for fastpath in SDL/framebuffer)
--TODO: interface for getting time, deltatime, average delta time
--TODO: remove getch depdendency?
--TODO: add a way of signal handling(catch ctrl-c), for (terminal) cleanup
--luacheck: ignore self, no max line length
local input_output = {}

-- Base system for input/output, supporting multiple drivers under a single API.
-- Drivers are a set of values that overload this table, providing callbacks for output and input.
-- user functions are for the external API, driver functions are for
-- implementing an output driver. The user code should mostly be concerned with
-- the target_db, and the driver code mostly with the output_db.
local ldb_core = require("ldb_core")
local time = require("time")

function input_output.new_base(config)
	local base = {}

	-- specifies the drawbuffer target that forwarded to draw callbacks(Internal pixel representation)
	base.target_width = math.floor(assert(tonumber(config.target_width)), "Width must be an integer!")
	base.target_height = math.floor(assert(tonumber(config.target_height)), "Height must be an integer!")
	base.target_format = "abgr8888" -- internal pixel format(Needs to have more bpp than output_format if output_dither is specified)

	-- specifies the drawbuffer and transformations required for the final output. (Output pixel representation)
	base.output_copy = false
	base.output_width = base.target_width -- output size, might be overwritten by driver to actual size
	base.output_height = base.target_height
	base.output_dither = config.output_dither -- use dithering to reduce colors to output pixel format?
	base.output_scale_x = config.output_scale_x or 1 -- scale the target db this ammount when drawing to the output
	base.output_scale_y = config.output_scale_y or 1
	base.output_ox = 0 -- draw the target db at this offset in the output
	base.output_oy = 0
	base.output_format = "abgr8888" -- pixel format the output supports
	base.title = config.title or "" -- Title for the window or terminal, if applicable

	base.bg_color = nil -- e.g. {0,0,0,0}
	base.limit_fps = config.limit_fps -- set to try to limit fps
	base.min_sleep = 0.001 -- miminum time in s to go sleep while limiting fps

	function base:realtime()
		return time.realtime()
	end

	function base:sleep(seconds)
		return time.sleep(seconds)
	end

	function base:init()
		-- user function. Call before use to initialize output facillities
		if self.on_init then
			self:on_init()
		end
		self:target_resize()
		self:output_resize()

		base.now = self:realtime()
		base.last = self.now
		base.dt = 0
	end

	function base:close()
		-- user function. Stop the output facillities(Close window/cleanup terminal etc.)
		if self.on_close then -- user callback
			self:on_close()
		end
		if self.on_cleanup then -- driver cleanup
			self:on_cleanup()
		end
	end

	function base:get_native_size()
		-- user function. get the prefered output size for this output
		return base.output_width, base.output_height
	end

	function base:get_native_db(width, height)
		-- get a drawbuffer of the specified dimensions in the prefered pixel format
		return ldb_core.new_drawbuffer(width or self.output_width, height or self.output_height, ldb_core.pixel_formats[self.target_format])
	end

	function base:target_resize(target_width, target_height)
		-- user function. resize the target_db
		self.target_width = math.floor(tonumber(target_width) or self.target_width)
		self.target_height = math.floor(tonumber(target_height) or self.target_height)
		self.target_db = ldb_core.new_drawbuffer(self.target_width, self.target_height, ldb_core.pixel_formats[self.target_format])
		if self.on_target_resize then
			self:on_target_resize(self.target_width, self.target_height)
		end
	end

	function base:output_resize(output_width, output_height)
		-- driver function. resize the output_db to the new dimensions
		self.output_width = math.floor(tonumber(output_width) or self.output_width)
		self.output_height = math.floor(tonumber(output_height) or self.output_height)
		if self.output_copy then
			self.output_db = ldb_core.new_drawbuffer(self.output_width, self.output_height, ldb_core.pixel_formats[self.output_format])
		end
		if self.on_output_resize then
			self:on_output_resize()
		end
	end

	function base:update()
		-- user function. Update internal state, call user and driver callback
		self.last = self.now
		self.now = self:realtime()
		self.dt = self.now - self.last

		if self.limit_fps then
			-- try to limit fps, by pooling for input and/or sleeping for the remaining frame time
			local dt_target = 1/self.limit_fps
			-- remaining_time is the ammount of time spent not sleeping in the last iteration
			local remaining_time = dt_target-(self.dt-(self.sleep_dt or 0))
			if remaining_time > self.min_sleep then
				-- we have some time over, sleep or pool
				local sleep_start = self:realtime()
				if self.on_event_pool then
					self:on_event_pool(remaining_time)
				else
					self:sleep(remaining_time)
				end
				-- record time spent sleeping
				self.sleep_dt = self:realtime()-sleep_start
			else
				-- no time left over, don't try to sleep, just get events
				self.sleep_dt = 0
				self:on_event_pool()
			end
		else
			-- always pool events as fast as possible
			if self.on_event_pool then
				self:on_event_pool()
			end
		end

		-- run user update, now that events have been handled
		if self.on_update then
			self:on_update(self.dt)
		end

		-- clear the background if needed
		if self.bg_color then
			self.target_db:clear(unpack(self.bg_color))
		end

		-- call user :on_draw function to draw on target_db
		if self.on_draw then
			self:on_draw(self.target_db)
		end

		-- apply dither on the target db, so that when we copy to the output
		-- with a lower bpp, no information is lost.
		if self.output_dither then
			self.target_db:floyd_steinberg(self.output_dither)
		end

		-- copy the target_db to the output_db
		if self.output_copy then
			self.target_db:origin_to_target(self.output_db, self.output_ox, self.output_oy, 0,0, self.target_width, self.target_height, self.output_scale_x, self.output_scale_y)
		end

		-- call the driver on_output_draw, to draw the output_db to the output device(screen etc.)
		if self.on_output_draw then
			self:on_output_draw()
		end
	end

	--[[ Driver callbacks ]]

	function base:on_cleanup()
		-- called when the driver code should close(perform cleanup, close window, etc.).
	end

	function base:on_init()
		-- called when the driver code should initialize
	end

	function base:on_event_pool(timeout)
		-- called when the driver code should pool for events, e.g. for inputs.
		-- if a timeout is specified and driver supports it, timeout is an optional
		-- timeout that is used together with limit_fps to lower cpu usage by pooling
		-- up to the time till the next frame needs to be drawn.
	end

	function base:on_output_draw()
		-- called when an output frame is ready, but before the target is
		-- scaled/dithered and drawn to the output_db.
	end

	function base:on_target_resize()
		-- called when the target_db has been resized
	end

	function base:request_resize(output_width, output_height)
		-- called when the user wants to resize to specified output dimensions.
		-- should call self:output_resize() if the output has been resized, to
		-- call callbacks and update internal state.
	end

	--[[
	Resize controll flow

	The goal is to support:
		fixed dimensions outputs(such as a linux framebuffer, or fixed-size terminal)
		resizeable outputs(such as a SDL window, or a terminal)

	user = user provided function
	base = function provided by the base input/output facillity
	driver = function provided by the implementation
	All are merged in a single table, usually aviable via self.



	Scenario 1: window resize(Window _has_ new dimensions, target needs to be adjusted)
		in driver:on_event_pool(), if resize event received, calls
		base:output_resize() to adjust output db dimensions, which calls
		user:on_output_resize(), which if it can resize, calls
		base:target_resize() to adjust the target db dimensions, which calls
		driver:on_target_resize(), to position the target_db on the output_db
	Scenario 2: request resolution(User wants new dimensions, output and target need to be adjusted)
		in user:update(), if you want to resize, call
		driver:request_resize(), which if successfull calls
		base:output_resize(), to adjust the output db(see above), calls
		user:on_output_resize() --> base:target_resize() --> driver:on_target_resize()
	]]

	--[[ User callbacks ]]
	function base:on_output_resize()
		-- called when the output_db has been resized.
		-- call self:target_resize(new_w, new_h) here to resize the target_db.
		-- This will also be called if you request_resize(), and still needs to
		-- call self:target_resize(new, new_h) to update the actual size.
	end

	function base:on_close()
		-- called before the driver close, ((after the close event was received)
	end

	function base:on_draw(target_db)
		-- called when the target_db should be drawn on.
	end

	function base:on_update(dt)
		-- called after input, before drawing
	end

	function base:on_event(event)
		-- called when an event happened(e.g. mouse, keyboard, window, ...)
	end

	return base
end


function input_output.new_sdl2fb(config)
	local ldb_sdl = require("ldb_sdl")

	local sdlio = input_output.new_base(config)

	function sdlio:on_init()
		self.output_width = self.target_width*self.output_scale_x
		self.output_height = self.target_height*self.output_scale_y

		self.sdl2fb = ldb_sdl.new_sdl2fb(self.output_width, self.output_height, self.title)
		self.target_format = "abgr8888" -- for fastpath

		-- Only enable the output_db copy step if we need to scale
		-- TODO: more efficient way of drawing scaled content using SDL C API?
		self.output_copy = not (self.output_scale_x==1 and self.output_scale_y==1)
	end

	function sdlio:on_close()
		self.sdl2fb:close()
	end

	function sdlio:on_output_draw()
		self.sdl2fb:draw_from_drawbuffer(self.output_db or self.target_db)
	end

	function sdlio:on_event_pool(timeout)
		local start = self:realtime()
		local ev = self.sdl2fb:pool_event(timeout) --wait using optional timeout
		while ev do
			if ev.type == "quit" then
				-- terminate because the window should close
				self:close()
				break
			end

			-- call user callback
			if self.on_event then
				self:on_event(ev)
			end

			if timeout then
				local remaining_time = timeout - (self:realtime() - start)
				-- we handled some events, but the next frame isn't due yet.
				if remaining_time > self.min_sleep then
					ev = self.sdl2fb:pool_event(remaining_time)
				else
					ev = self.sdl2fb:pool_event()
				end
			else
				ev = self.sdl2fb:pool_event()
			end
		end

		if timeout then
			-- determine if the timeout has expired
			local remaining_time = (timeout or 0) - (self:realtime() - start)
			if remaining_time > self.min_sleep then
				self:sleep(remaining_time)
			end
		end
	end

	return sdlio
end


function input_output.new_from_args(config, args)
	--[[
		return a CIO instance, based on a default configuration and parsing command-line arguments
		Supported command-line arguments:
		general:
			--output_scale=number(>0, scale along both axis)
			--output_scale_x=number(>0, scale along x axis)
			--output_scale_y=number(>0, scale along y axis)
			--dither=number(dither target bpp)
			--limit_fps=number(Limit to target fps)
		--sdl
			--width=number
			--height=number
			--title=text
	]]
	local args_parse = require("lua-db.args_parse")

	-- parse generic options
	local output_scale_x = config.output_scale_x or 1
	local output_scale_y = config.output_scale_y or 1
	local dither = config.output_dither
	local limit_fps = config.limit_fps

	if args_parse.get_arg_num(args, "output_scale") then
		local scale = args_parse.get_arg_num(args, "output_scale")
		output_scale_x = scale
		output_scale_y = scale
	else
		if args_parse.get_arg_num(args, "output_scale_x") then
			output_scale_x = args_parse.get_arg_num(args, "output_scale_x")
		end
		if args_parse.get_arg_num(args, "output_scale_y") then
			output_scale_y = args_parse.get_arg_num(args, "output_scale_y")
		end
	end
	if args_parse.get_arg_num(args, "limit_fps") then
		limit_fps = args_parse.get_arg_num(args, "limit_fps")
		if limit_fps <= 0 then
			limit_fps = false
		end
	end
	if args_parse.get_arg_num(args, "dither") then
		dither = args_parse.get_arg_num(args, "dither")
		if dither <= 0 then
			dither = false
		end
	end

	local mode = config.default_mode
	if args_parse.get_arg_flag(args, "sdl") then
		mode = "sdl"
	elseif args_parse.get_arg_flag(args, "terminal") then
		mode = "terminal"
	elseif args_parse.get_arg_flag(args, "framebuffer") then
		mode = "framebuffer"
	elseif args_parse.get_arg_str(args, "framebuffer") then
		mode = "framebuffer"
	elseif args_parse.get_arg_str(args, "fb") then
		mode = "framebuffer"
	end

	if (mode == "sdl") and (not config.disable_sdl)then
		local width = args_parse.get_arg_num(args, "width", config.sdl_width) or args_parse.terminate("Must specify --width= for SDL mode")
		local height = args_parse.get_arg_num(args, "height", config.sdl_height) or args_parse.terminate("Must specify --height= for SDL mode")
		local title = args_parse.get_arg_str(args, "title", config.sdl_title)

		return input_output.new_sdl2fb({
			output_scale_x = output_scale_x,
			output_scale_y = output_scale_y,
			output_dither = dither,
			limit_fps = limit_fps,

			target_width = width,
			target_height = height,
			title = title,
		})
	end

	-- TODO: Re-Implement other modes(WIP, needs better input handling, probably C library)
	args_parse.terminate("Must specify a mode! Try: --sdl")
end


return input_output
