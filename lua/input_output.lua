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
--luacheck: ignore self, no max line length
local input_output = {}


function input_output.new_sdl(config)
	local ldb = require("ldb_core")
	local ldb_sdl = require("ldb_sdl")
	local sdl_io = {}

	-- check required config fields
	local width = assert(tonumber(config.width))
	local height = assert(tonumber(config.height))
	local title = config.title or "input_output"

	-- create the SDL window
	function sdl_io:init()
		self.sdlfb = ldb_sdl.new_sdl2fb(width, height, title)
	end

	-- close the SDL window
	function sdl_io:close()
		self.sdlfb:close()
	end

	-- SDL2 window always has the size we specified
	function sdl_io:get_native_size()
		return width, height
	end

	-- get a drawbuffer with the native pixel format for this output
	function sdl_io:get_native_db()
		local w, h = self:get_native_size()
		local db = ldb.new_drawbuffer(w,h, "abgr8888")
		return db
	end

	-- draw to the SDL2 window
	function sdl_io:update_output(db)
		self.sdlfb:draw_from_drawbuffer(db)
	end

	-- handle input events
	function sdl_io:update_input()
		local ev = self.sdlfb:pool_event()
		while ev do
			if ev.type == "quit" then
				self:close()
				self.stop = true
				break
			end
			self:handle_event(ev)
			ev = self.sdlfb:pool_event()
		end
	end

	-- user callback dummy to handle an event
	function sdl_io:handle_event(_)
	end

	return sdl_io
end


function input_output.new_framebuffer(config)
	local ldb_fb = require("ldb_fb")
	local input = require("lua-input")
	local event_codes = input.event_codes

	local fb_io = {}

	-- check required config fields
	local fbdev = assert(config.fbdev)
	local kbdev = config.kbdev
	local mousedev = config.mousedev
	fb_io.mouse_width = config.mouse_width
	fb_io.mouse_height = config.mouse_height
	fb_io.mouse_sensitivity = config.mouse_sensitivity or 1

	-- open framebuffer and open input devices
	function fb_io:init()
		io.write("\027[?25l") -- disable cursor(for VT)
		io.flush()
		self.fb = ldb_fb.new_framebuffer(fbdev)
		self.vinfo = self.fb:get_varinfo()
		self.finfo = self.fb:get_fixinfo()
		self.mouse_width = self.mouse_width or self.vinfo.xres
		self.mouse_height = self.mouse_height or self.vinfo.yres
		if kbdev then
			self.kb = assert(input.open(kbdev))
		end
		if mousedev then
			self.mouse = assert(input.open(mousedev))
		end
	end

	-- close the framebuffer and input devices
	function fb_io:close()
		io.write("\027[?25h") --re-enable cursor
		io.flush()
		self.fb:close()
		if self.kb then
			self.kb:close()
		end
		if self.mouse then
			self.mouse:close()
		end
	end

	-- returns the size of the framebuffer
	function fb_io:get_native_size()
		return self.vinfo.xres, self.vinfo.yres
	end

	-- draw to the framebuffer
	function fb_io:update_output(db)
		self.fb:copy_from_db(db)
	end

	-- mapping table from uinput event keys to sdl keys
	local input_key_to_sdl_key = config.key_to_sdl or {
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

	-- translate a single mouse_event from uinput into an SDL-like mouse event
	-- (By keeping track of mouse position, state etc.)
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

	-- check for and handle all outstanding keyboard events
	function fb_io:update_kb_input()
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
	end

	-- check for and handle all outstanding mouse events
	function fb_io:update_mouse_input()
		local mouse_ev = self.mouse:read()
		while mouse_ev do
			if self.handle_raw_mouse_event then
				self:handle_raw_mouse_event(mouse_ev)
			elseif self.handle_event then
				local sdl_ev = sdl_mouse_event_from_input_event(mouse_ev, self.mouse_width,self.mouse_height,self.mouse_sensitivity)
				if sdl_ev then
					self:handle_event(sdl_ev)
				end
			end
			mouse_ev = self.mouse:read()
		end
	end

	-- check for and handle all outstanding input events
	function fb_io:update_input()
		if self.kb then
			self:update_kb_input()
		end
		if self.mouse then
			self:update_mouse_input()
		end
	end

	-- user callback dummy to handle an event
	function fb_io:handle_event(_)
	end

	return fb_io
end


function input_output.new_terminal(config)
	local ldb = require("lua-db")
	local getch = require("lua-getch")

	local term_io = {}
	term_io.event_queue = {}

	-- prepare CIO configuration
	local braile = config.braile
	local halfblocks = config.halfblocks
	local xskip = config.xskip or 1
	local yskip = config.yskip or 1
	local bpp24 = config.bpp24
	local bg = config.bg
	local darken = config.darken or 0.9
	local threshold = config.threshold or 128
	local block_chars = config.block_chars or {" ", ".", "-", "+", "O", "@", "#"}
	local no_colors = config.no_colors
	local blocks_use_chars = config.blocks_use_chars
	local mouse_input = config.mouse_input

	-- TODO: Better mapping table!
	local key_table = config.key_table or {
		[10] = "enter",
		[27] = {
			[91] = {
				[60] = function(get_ch)
					local str = {}
					local ch = get_ch()
					local down
					while ch do
						if ch == 77 then
							ch = nil
							down = true
						elseif ch == 109 then
							ch = nil
							down = false
						else
							table.insert(str, string.char(ch))
							ch = get_ch()
						end
					end
					local id,x,y = table.concat(str):match("^(%d+);(%d+);(%d+)$")
					id = tonumber(id)
					x = tonumber(x)
					y = tonumber(y)
					if id and x and y then
						return "mouse:" .. id .. ":" .. (down and "down" or "up") .. ":" .. x .. ":" .. y
					end
				end,
				[65] = "Up",
				[66] = "Down",
				[67] = "Right",
				[68] = "Left"
			}
		}
	}

	-- utillity functions for setting the terminal background/foreground colors
	local _fg_color = bpp24 and ldb.term.rgb_to_ansi_color_fg_24bpp or ldb.term.rgb_to_ansi_color_fg_216
	local _bg_color = bpp24 and ldb.term.rgb_to_ansi_color_bg_24bpp or ldb.term.rgb_to_ansi_color_bg_216
	if no_colors then
		_fg_color = function() return "" end
		_bg_color = _fg_color
	end


	-- set output buffering mode, get screen size, scroll down, enable mouse input
	local screen_w, screen_h
	function term_io:init()
		io.stdout:setvbuf("full")
		if mouse_input then
			io.write("\027[?1000;1006;1015h")
		end
		io.write("\027[?25l")
		--os.execute("stty -echo")
		screen_w, screen_h = self:get_native_size()
		io.write(("\n"):rep(screen_h))
		io.flush()
	end

	-- leave the terminal in the same state we found it in
	function term_io:close()
		if mouse_input then
			-- TODO: test this?
			io.write("\027[?1000;1006;1015l")
		end
		io.write("\027[?25h")
		io.flush()
	end

	-- get the size in pixels the terminal can display using it's current output mode
	function term_io:get_native_size()
		local term_w,term_h = ldb.term.get_screen_size()
		if braile then
			term_w = term_w*2-2
			term_h = term_h*4-4
		elseif halfblocks then
			term_h = term_h*2
		end
		return math.ceil(term_w*xskip),math.ceil(term_h*yskip)
	end

	-- return a list of terminal lines for the blocks output mode
	function term_io:update_output_blocks(db)
		local lines = ldb.blocks.draw_pixel_callback(screen_w, screen_h, function(x,y)
			local r,g,b,a = db:get_px(x*xskip, y*yskip)
			if (a > 0) and (r+g+b > 0) then
				if blocks_use_chars or no_colors then
					local char_i = math.floor(((r+g+b)/(255*3))*(#block_chars-1))+1
					local char = _fg_color(r,g,b) .. _bg_color(r*0.3,g*0.3,b*0.3) .. block_chars[char_i]
					return r,g,b,char
				else
					return r,g,b
				end
			else
				return 0,0,0
			end
		end, bpp24, no_colors)
		return lines
	end

	-- return a list of terminal lines for the halfblocks output mode
	function term_io:update_output_halfblocks(db)
		local lines = ldb.halfblocks.draw_pixel_callback(screen_w, screen_h, function(x,y)
			local r,g,b,a = db:get_px(x*xskip, y*yskip)
			if (a > 0) and (r+g+b > 0) then
				return r,g,b
			else
				return 0,0,0
			end
		end, bpp24, no_colors, threshold)
		return lines
	end

	-- return a list of terminal lines for the braile output mode
	function term_io:update_output_braile(db)
		local lines = ldb.braile.draw_pixel_callback(screen_w, screen_h, function(x,y)
			local r,g,b,a = db:get_px(x*xskip, y*yskip)
			if (a > 0) and (r+g+b > threshold*3) then
				return 1
			end
			return 0
		end, function(x,y)
			local min_r, min_g, min_b = 255,255,255
			local max_r, max_g, max_b = 0,0,0
			local set = false
			for oy=0, 3 do
				for ox=0, 1 do
					local r,g,b,a = db:get_px(x+ox,y+oy)
					if (a > 0) then
						set = true
						max_r = math.max(max_r, r)
						max_g = math.max(max_g, g)
						max_b = math.max(max_b, b)
						min_r = math.min(min_r, r)
						min_g = math.min(min_g, g)
						min_b = math.min(min_b, b)
					end
				end
			end

			if not set then
				return ""
			end

			if bg then
				return _fg_color(max_r, max_g, max_b) .. _bg_color(min_r*darken, min_g*darken, min_b*darken)
			else
				return _fg_color(max_r, max_g, max_b)
			end
		end)
		return lines
	end

	-- write the drawbuffer to the terminal
	function term_io:update_output(db)
		local lines
		if braile then
			lines = self:update_output_braile(db)
		elseif halfblocks then
			lines = self:update_output_halfblocks(db)
		else
			lines = self:update_output_blocks(db)
		end
		io.write(ldb.term.set_cursor(0,0))
		io.flush()
		io.write(table.concat(lines, ldb.term.reset_color().."\n"))
		io.flush()
	end

	-- resolv the terminal keys, and append the resolved SDL events to event_queue
	function term_io:term_key_to_sdl_events(key_code, key_resolved)
		if key_resolved and key_resolved:sub(1,6)=="mouse:" and mouse_input then
			-- we got a mouse sequence from the terminal
			local button_id,state,x,y = key_resolved:match("^mouse:(%d+):(%S+):(%d+):(%d+)$")
			if not button_id then
				return nil
			end
			--correct the mouse coordinates
			x,y = tonumber(x)*xskip, tonumber(y)*yskip
			if braile then
				x = x * 2
				y = y * 4
			elseif halfblocks then
				y = y * 2
			end
			if state == "up" then
				-- generate a extra mousemotion event when the mouse button is released
				local move_ev = {
					type = "mousemotion",
					x = tonumber(x)-1,
					y = tonumber(y)-1
				}
				table.insert(self.event_queue, move_ev)
			end
			-- generate sdl mouse button up/down event
			local ev = {
				type = "mousebutton"..state,
				x = tonumber(x)-1,
				y = tonumber(y)-1,
				button = tonumber(button_id)+1,
				state = (state == "down") and 1 or 0
			}
			table.insert(self.event_queue, ev)
		elseif key_resolved then
			-- got a SDL mapped key(e.g. "Up", "Left Shift")
			table.insert(self.event_queue, {
				type = "keydown",
				key = key_resolved,
				scancode = key_resolved
			})
			table.insert(self.event_queue, {
				type = "keyup",
				key = key_resolved,
				scancode = key_resolved
			})
		elseif key_code and (key_code>=65 and key_code<=90) then
			-- got an uppercase ASCII character(A-Z)
			-- also pretend the left shift key was pressed before and released after
			local sdl_key = string.char(key_code):upper()
			table.insert(self.event_queue, {
				type = "keydown",
				key = "Left Shift",
				scancode = "Left Shift"
			})
			table.insert(self.event_queue, {
				type = "keydown",
				key = sdl_key,
				scancode = sdl_key
			})
			table.insert(self.event_queue, {
				type = "keyup",
				key = sdl_key,
				scancode = sdl_key
			})
			table.insert(self.event_queue, {
				type = "keyup",
				key = "Left Shift",
				scancode = "Left Shift"
			})
		elseif key_code and (key_code>=97 and key_code<=122) then
			-- got an lowercase ASCII character(A-Z)
			local sdl_key = string.char(key_code):upper()
			table.insert(self.event_queue, {
				type = "keydown",
				key = sdl_key,
				scancode = sdl_key
			})
			table.insert(self.event_queue, {
				type = "keyup",
				key = sdl_key,
				scancode = sdl_key
			})
		end
	end

	-- read new characters from terminal, and convert to SDL events, then pass to event handler callback
	-- may generate multiple events, but only calls the event handler once. (For emulating keyup/keydown on a terminal)
	function term_io:update_input()
		local key_code, key_resolved = getch.get_key_mbs(getch.non_blocking, key_table)
		if self.handle_raw_term then
			self:handle_raw_term(key_code, key_resolved)
		else
			self:term_key_to_sdl_events(key_code, key_resolved)
			local event = table.remove(self.event_queue, 1)
			if event then
				self:handle_event(event)
			end
		end
	end

	-- user callback dummy to handle an event
	function term_io:handle_event(_)
	end

	return term_io
end


function input_output.new_from_args(config, args)
	--[[
		return a CIO instance, based on a default configuration and parsing command-line arguments
		Supported command-line arguments:
		--sdl
			--width=number
			--height=number
			--title=text
		--framebuffer
			--key_table=filename
			--fb=framebuffer device
			--mouse=mouse device
			--kb=keyboard device
			--sensitivity=number(0-100)
		--terminal
			--key_table=filename
			--braile
				--braile_use_bg
				--braile_bg_darken=number(0-100)
			--blocks
				--use_chars
			--mouse
			--halfblocks
			--no_colors
			--bpp24
			--threshold=number
			--xskip=number
			--yskip=number
	]]
	local args_parse = require("lua-db.args_parse")

	local mode = config.default_mode
	if args_parse.get_arg_flag(args, "sdl") then
		mode = "sdl"
	elseif args_parse.get_arg_flag(args, "terminal") then
		mode = "terminal"
	elseif args_parse.get_arg_flag(args, "framebuffer") then
		mode = "framebuffer"
	end

	if args_parse.get_arg_str(args, "fb") then
		mode = "framebuffer"
	end

	local terminal_mode = config.default_terminal_mode
	if args_parse.get_arg_flag(args, "braile") then
		terminal_mode = "braile"
		mode = "terminal"
	elseif args_parse.get_arg_flag(args, "halfblocks") then
		terminal_mode = "halfblocks"
		mode = "terminal"
	elseif args_parse.get_arg_flag(args, "blocks") then
		terminal_mode = "blocks"
		mode = "terminal"
	end
	if mode == "terminal" then
		local bpp24
		local braile_use_bg, braile_darken
		terminal_mode = terminal_mode or config.terminal_mode or "halfblocks"
		local xskip = args_parse.get_arg_num(args, "xskip", config.terminal_xskip)
		local yskip = args_parse.get_arg_num(args, "yskip", config.terminal_yskip)
		local no_colors = args_parse.get_arg_flag(args, "no_colors", config.terminal_no_colors)
		local threshold = args_parse.get_arg_num(args, "threshold", config.terminal_threshold) or 0
		local mouse_input = args_parse.get_arg_flag(args, "mouse", config.terminal_mouse)
		local blocks_use_chars

		if terminal_mode == "braile" then
			braile_use_bg = args_parse.get_arg_flag(args, "braile_use_bg", config.terminal_braile_use_bg)
			if braile_use_bg then
				if args_parse.get_arg_num(args, "braile_bg_darken") then
					braile_darken = 1-(math.max(math.min(args_parse.get_arg_num(args, "braile_bg_darken"), 100), 0)/100)
				end
			end
		end
		if terminal_mode == "blocks" then
			blocks_use_chars = args_parse.get_arg_flag(args, "use_chars")
		end

		bpp24 = args_parse.get_arg_flag(args, "bpp24", config.terminal_bpp24)

		local key_table
		if args_parse.get_arg_str(args, "key_table", config.terminal_key_table) then
			local ok,ret = pcall(require, args_parse.get_arg_str(args, "key_table"))
			if ok then
				key_table = ret
			end
		end

		return input_output.new_terminal({
			braile = (terminal_mode == "braile"),
			halfblocks = (terminal_mode == "halfblocks"),
			key_table = key_table,
			bg = braile_use_bg,
			darken = braile_darken,
			mouse_input = mouse_input,
			bpp24 = bpp24,
			xskip = xskip,
			yskip = yskip,
			no_colors = no_colors,
			threshold = threshold,
			blocks_use_chars = blocks_use_chars
		})
	end


	if mode == "framebuffer" then
		local key_to_sdl

		local fbdev = args_parse.get_arg_str(args, "fb", config.framebuffer_dev) or args_parse.terminate("Must specify --fb= for framebuffer mode")
		local mousedev = args_parse.get_arg_str(args, "mouse", config.framebuffer_mouse_dev)-- or args_parse.terminate("Must specify --mouse= for framebuffer mode")
		local kbdev = args_parse.get_arg_str(args, "kb", config.framebuffer_mouse_dev)-- or args_parse.terminate("Must specify --kb= for framebuffer mode")

		local mouse_sensitivity = args_parse.get_arg_num(args, "sensitivity", config.framebuffer_mouse_sensitivity)
		if args_parse.get_arg_str(args, "key_table") then
			local ok,ret = pcall(require, args_parse.get_arg_str(args, "key_table"))
			if ok then
				key_to_sdl = ret
			end
		else
			key_to_sdl = config.framebuffer_key_table
		end

		return input_output.new_framebuffer({
			fbdev = fbdev,
			mousedev = mousedev,
			kbdev = kbdev,
			key_to_sdl = key_to_sdl,
			mouse_sensitivity = mouse_sensitivity
		})
	end

	if mode == "sdl" then
		local width = args_parse.get_arg_num(args, "width", config.sdl_width) or args_parse.terminate("Must specify --width= for SDL mode")
		local height = args_parse.get_arg_num(args, "height", config.sdl_height) or args_parse.terminate("Must specify --height= for SDL mode")
		local title = args_parse.get_arg_str(args, "title", config.sdl_title)

		return input_output.new_sdl({
			width = width,
			height = height,
			title = title,
		})
	end

	args_parse.terminate("Must specify a mode! Try: --sdl")
end


return input_output
