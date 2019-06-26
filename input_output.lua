local input_output = {}



function input_output.new_sdl(config)

	local sdl2fb = require("sdl2fb")

	local sdl_io = {}
	
	-- check required config fields
	local width = assert(tonumber(config.width))
	local height = assert(tonumber(config.height))
	local title = config.title or "unnamed"
	
	-- create the SDL window
	function sdl_io:init()
		self.sdlfb = sdl2fb.new(width, height, title)
	end
	
	-- close the SDL window
	function sdl_io:close()
		self.sdlfb:close()
	end
	
	-- SDL2 window always has the size we specified
	function sdl_io:get_native_size()
		return width, height
	end
	
	-- draw to the SDL2 window
	function sdl_io:update_output(db)
		self.sdlfb:draw_from_drawbuffer(db,0,0)
	end
	
	-- handle input events
	function sdl_io:update_input()
		local ev = self.sdlfb:pool_event()
		while ev do
			if ev.type == "quit" then
				self:close()
				break
			end
			if self.handle_event then
				self:handle_event(ev)
			end
			ev = self.sdlfb:pool_event()
		end
	end
	
	function sdl_io:handle_event(ev)
		-- user callback to handle an event
	end
	
	return sdl_io
	
end

function input_output.new_framebuffer(config)

	local lfb = require("lua-fb")
	local input = require("lua-input")
	local event_codes = input.event_codes

	local fb_io = {}
	
	-- check required config fields
	local fbdev = assert(config.fbdev)
	local kbdev = assert(config.kbdev)
	local mousedev = assert(config.mousedev)
	fb_io.mouse_width = config.mouse_width
	fb_io.mouse_height = config.mouse_height
	fb_io.mouse_sensitivity = config.mouse_sensitivity or 1

	-- open framebuffer and open input devices
	function fb_io:init()
		self.fb = lfb.new(fbdev)
		self.vinfo = self.fb:get_varinfo()
		self.finfo = self.fb:get_fixinfo()
		self.mouse_width = self.mouse_width or self.vinfo.xres
		self.mouse_height = self.mouse_height or self.vinfo.yres
		self.kb = assert(input.open(kbdev))
		self.mouse = assert(input.open(mousedev))
	end
	
	-- close the framebuffer and input devices
	function fb_io:close()
		self.fb:close()
		self.kb:close()
		self.mouse:close()
	end
	
	-- returns the size of the framebuffer
	function fb_io:get_native_size()
		return self.vinfo.xres, self.vinfo.yres
	end
	
	-- draw to the framebuffer
	function fb_io:update_output(db)
		self.fb:draw_from_drawbuffer(db, 0,0)
	end
	
	-- mapping table from uinput event keys to sdl keys
	local input_key_to_sdl_key = {
		[event_codes.KEY_Q] = "Q",
		[event_codes.KEY_W] = "W",
		[event_codes.KEY_E] = "E",
		[event_codes.KEY_R] = "R",
		[event_codes.KEY_T] = "T",
		[event_codes.KEY_Y] = "Y",
		[event_codes.KEY_U] = "U",
		[event_codes.KEY_I] = "I",
		[event_codes.KEY_O] = "O",
		[event_codes.KEY_P] = "P",
		[event_codes.KEY_A] = "A",
		[event_codes.KEY_S] = "S",
		[event_codes.KEY_D] = "D",
		[event_codes.KEY_F] = "F",
		[event_codes.KEY_G] = "G",
		[event_codes.KEY_H] = "H",
		[event_codes.KEY_J] = "J",
		[event_codes.KEY_K] = "K",
		[event_codes.KEY_L] = "L",
		[event_codes.KEY_Z] = "Z",
		[event_codes.KEY_X] = "X",
		[event_codes.KEY_C] = "C",
		[event_codes.KEY_V] = "V",
		[event_codes.KEY_B] = "B",
		[event_codes.KEY_N] = "N",
		[event_codes.KEY_M] = "M",
		[event_codes.KEY_UP] = "Up",
		[event_codes.KEY_DOWN] = "Down",
		[event_codes.KEY_LEFT] = "Left",
		[event_codes.KEY_RIGHT] = "Right",
		[event_codes.KEY_LEFTCTRL] = "Left Ctrl",
		[event_codes.KEY_LEFTSHIFT] = "Left Shift",
		[event_codes.KEY_LEFTALT] = "Left Alt",
		[event_codes.KEY_ENTER] = "Return",
		[event_codes.KEY_SPACE] = "Space",
		[event_codes.KEY_TAB] = "Tab",
		[event_codes.KEY_BACKSPACE] = "Backspace",
	}
	
	-- translate a single kb_event from uinput into an SDL-like event
	local function sdl_key_event_from_input_event(kb_ev)
		if (kb_ev.type == event_codes.EV_KEY) and (input_key_to_sdl_key[kb_ev.code]) then
			if kb_ev.value == 0 then
				-- key up
				return {
					type = "keyup",
					key = input_key_to_sdl_key[kb_ev.code],
					scancode = input_key_to_sdl_key[kb_ev.code]
				}
			else
				-- key down
				return {
					type = "keydown",
					key = input_key_to_sdl_key[kb_ev.code],
					scancode = input_key_to_sdl_key[kb_ev.code]
				}		
			end
		end
	end
	
	-- translate a single mouse_event from uinput into an SDL-like mouse event(By keeping track of mouse position, state etc.)
	local mouse_x = 0
	local mouse_y = 0
	local mouse_buttons = {}
	local function sdl_mouse_event_from_input_event(mouse_ev, width, height, sensitivity)
		if mouse_ev.type == event_codes.EV_REL then
			local xrel = 0
			local yrel = 0
			if mouse_ev.code == event_codes.REL_X then
				xrel = mouse_ev.value*sensitivity
			elseif mouse_ev.code == event_codes.REL_Y then
				yrel = mouse_ev.value*sensitivity
			end
			mouse_x = math.min(math.max(mouse_x + xrel, 0), width-1)
			mouse_y = math.min(math.max(mouse_y + yrel, 0), height-1)
			return {
				type = "mousemotion",
				buttons = mouse_buttons,
				x = mouse_x,
				y = mouse_y,
				xrel = xrel,
				yrel = yrel
			}
		elseif mouse_ev.type == event_codes.EV_KEY then
			local button_id
			if mouse_ev.code == event_codes.BTN_LEFT then
				button_id = 1
				mouse_buttons["left"] = (mouse_ev.value ~= 0)
			elseif mouse_ev.code == event_codes.BTN_RIGHT then
				button_id = 3
				mouse_buttons["right"] = (mouse_ev.value ~= 0)
			elseif mouse_ev.code == event_codes.BTN_MIDDLE then
				button_id = 2
				mouse_buttons["middle"] = (mouse_ev.value ~= 0)
			end
			
			local state = 0
			local type = "mousebuttonup"
			if mouse_ev.value ~= 0 then
				type = "mousebuttondown"
				state = 1
			end
			
			return {
				type = type,
				x = mouse_x,
				y = mouse_y,
				button = button_id,
				state = state
			}
		end
	end
	
	-- check all input devices, call handle_event callback for generated events
	function fb_io:update_input()
		local kb_ev = self.kb:read()
		while kb_ev do
			if self.handle_raw_key_event then
				self:handle_raw_key_event(kb_ev)
			elseif self.handle_event then
				local sdl_ev = sdl_key_event_from_input_event(kb_ev)
				if sdl_ev then
					self:handle_event(sdl_ev)
				end
			end
			kb_ev = self.kb:read()
		end
		
		local mouse_ev = self.mouse:read()
		while mouse_ev do
			if self.handle_raw_mouse_event then
				self:handle_raw_mouse_event(mouse_ev)
			elseif self.handle_event then
				local sdl_ev = sdl_mouse_event_from_input_event(mouse_ev, self.mouse_width, self.mouse_height, self.mouse_sensitivity)
				if sdl_ev then
					self:handle_event(sdl_ev)
				end
			end
			mouse_ev = self.mouse:read()
		end
		
	end
	
	function fb_io:handle_event(ev)
		-- user callback to handle an event
	end
	
	return fb_io
	
end

function input_output.new_terminal()
	-- TODO
	-- get size of 
	-- center on terminal?
	-- braile vs blocks
	-- color modes
	
	local term_io = {}
	
	function term_io:init()
		
	end
	
	function term_io:close()
		
	end
	
	function term_io:get_native_size()
		
	end
	
	function term_io:update_output(db)
		
	end
	
	function term_io:update_input()
		
	end
	
	function term_io:handle_event(ev)
		-- user callback to handle an event
	end
	
	return io

end



return input_output
