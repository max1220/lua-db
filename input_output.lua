local ldb = require("lua-db.lua_db")

local input_output = {}


function input_output.new_sdl(config)
	local sdl2fb = require("sdl2fb")

	local sdl_io = {}

	-- check required config fields
	local width = assert(tonumber(config.width))
	local height = assert(tonumber(config.height))
	local scale = tonumber(config.scale)
	local title = config.title or "unnamed"

	local scale_db
	if scale and scale > 1 then
		scale_db = ldb.new(width*scale, height*scale)
	else
		scale = 1
	end

	-- create the SDL window
	function sdl_io:init()
		self.sdlfb = sdl2fb.new(width*scale, height*scale, title)
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
		if scale > 1 then
			db:draw_to_drawbuffer(scale_db, 0,0, 0,0, width, height, scale, true)
			self.sdlfb:draw_from_drawbuffer(scale_db,0,0)
		else
			self.sdlfb:draw_from_drawbuffer(db,0,0)
		end
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

function input_output.new_terminal(config)
	local ldb = require("lua-db")
	local getch = require("lua-getch")

	local term_io = {
		event_queue = {}
	}
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
				[65] = "up",
				[66] = "down",
				[67] = "right",
				[68] = "left"
			}
		}
	}

	local term_w, term_h
	function term_io:init()
		-- enable mouse codes
		--io.stdout:setvbuf("full")
		io.write("\027[?1000;1006;1015h")
		--os.execute("stty -echo")
		term_w, term_h = ldb.term.get_screen_size()
	end

	function term_io:close()

	end

	function term_io:get_native_size()
		local term_w, term_h = ldb.term.get_screen_size()
		if braile then
			term_w = term_w*2-2
			term_h = term_h*4-4
		elseif halfblocks then
			term_h = term_h*2
		end
		return math.ceil(term_w*xskip),math.ceil(term_h*yskip)
	end

	function term_io:update_output(db)
		local lines
		local len
		local _floor = math.floor
		local _fg_color = bpp24 and ldb.term.rgb_to_ansi_color_fg_24bpp or ldb.term.rgb_to_ansi_color_fg_216
		local _bg_color = bpp24 and ldb.term.rgb_to_ansi_color_bg_24bpp or ldb.term.rgb_to_ansi_color_bg_216
		if no_colors then
			_fg_color = function() return "" end
			_bg_color = _fg_color
		end
		if braile then
			lines = ldb.braile.draw_pixel_callback(db:width()/xskip, db:height()/yskip, function(x,y)
				local r,g,b,a = db:get_pixel(x*xskip, y*yskip)
				if (a > 0) and (r+g+b > threshold*3) then
					return 1
				end
				return 0
			end, function(x,y, char_num)
				local min_r, min_g, min_b = 255,255,255
				local max_r, max_g, max_b = 0,0,0
				local set = false
				for oy=0, 3 do
					for ox=0, 1 do
						local r,g,b,a = db:get_pixel(x+ox,y+oy)
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
		elseif halfblocks then
			local term_w, term_h = ldb.term.get_screen_size()
			lines = ldb.halfblocks.draw_pixel_callback(term_w, term_h*2, function(x,y)
				local r,g,b,a = db:get_pixel(x*xskip, y*yskip)
				if (a > 0) and (r+g+b > 0) then
					return r,g,b
				else
					return 0,0,0
				end
			end, bpp24, no_colors, threshold)
		else
			local term_w, term_h = ldb.term.get_screen_size()
			lines = ldb.blocks.draw_pixel_callback(term_w, term_h, function(x,y)
				local r,g,b,a = db:get_pixel(x*xskip, y*yskip)
				if (a > 0) and (r+g+b > 0) then
					if blocks_use_chars or no_colors then
						local char_i = _floor(((r+g+b)/(255*3))*(#block_chars-1))+1
						local char = _fg_color(r,g,b) .. _bg_color(r*0.3,g*0.3,b*0.3) .. block_chars[char_i]
						return r,g,b,char
					else
						return r,g,b
					end
				else
					return 0,0,0
				end
			end, bpp24, no_colors)
		end
		--io.write(ldb.term.clear_screen())
		io.write(ldb.term.set_cursor(0,0))
		io.flush()
		io.write(table.concat(lines, ldb.term.reset_color().."\n"))
		io.flush()
	end

	local function insert_key_events(t, code)
		table.insert(t, {
			type = "keydown",
			key = code,
			scancode = code
		})
		table.insert(t, {
			type = "keyup",
			key = code,
			scancode = code
		})
	end

	local function term_key_to_sdl_events(key_code, key_resolved)
		local events = {}

		if key_resolved then
			local button_id,state,x,y = key_resolved:match("^mouse:(%d+):(%S+):(%d+):(%d+)$")
			if braile and button_id then
				x = tonumber(x) * 2
				y = tonumber(y) * 4
			elseif halfblocks and button_id then
				y = tonumber(y) * 2
			end
			if x and y then
				x = x * xskip
				y = y * yskip
			end
			if state == "up" then
				local move_ev = {
					type = "mousemotion",
					x = tonumber(x)-1,
					y = tonumber(y)-1
				}
				table.insert(events, move_ev)
			end
			if button_id then
				local ev = {
					type = "mousebutton"..state,
					x = tonumber(x)-1,
					y = tonumber(y)-1,
					button = tonumber(button_id)+1,
					state = (state == "down") and 1 or 0
				}
				table.insert(events, ev)
			end
		end

		if key_resolved == "left" then
			insert_key_events(events,  "Left")
		elseif key_resolved == "right" then
			insert_key_events(events,  "Right")
		elseif key_resolved == "up" then
			insert_key_events(events,  "Up")
		elseif key_resolved == "down" then
			insert_key_events(events,  "Down")
		elseif key_code and key_code ~= 0 then
			insert_key_events(events,  string.char(key_code):upper())
			--print("key_code:", string.char(key_code):upper())
		end
		return events
	end

	function term_io:update_input()
		local key_code, key_resolved = getch.get_key_mbs(getch.non_blocking, key_table)
		if self.handle_raw_term then
			self:handle_raw_term(key_code, key_resolved)
		elseif self.handle_event then
			for i, event in ipairs(term_key_to_sdl_events(key_code, key_resolved)) do
				table.insert(self.event_queue, event)
			end
			local event = table.remove(self.event_queue, 1)
			if event then
				self:handle_event(event)
			end
		end
	end

	function term_io:handle_event(ev)
		-- user callback to handle an event
	end

	return term_io
end



function input_output.new_from_args(config, args)
	--[[
		--sdl
			--width=number
			--height=number
			--title=text
			--scale=number
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
			--halfblocks
			--no_colors
			--bpp24
			--threshold=number
			--xskip=number
			--yskip=number
	]]
	
	local function get_arg_flag(arg_name)-- example: --foo
		local flag_str = "--"..arg_name
		for i,arg in ipairs(args) do
			if arg==flag_str then
				return true, i
			end
		end
	end
	local function get_arg_str(arg_name)-- example: --foo=test, foo="hello world"
		local normal_pattern = "^--"..arg_name.."=\"(.*)\"$"
		local quote_pattern = "^--"..arg_name.."=\"(.*)\"$"
		for i,arg in ipairs(args) do
			local str = arg:match(quote_pattern) or arg:match(normal_pattern)
			if str then
				return str, i
			end
		end
	end
	local function get_arg_num(arg_name)-- example: --foo=123, foo=0xCAFE
		local num_pattern = "^--"..arg_name.."=(.*)$"
		for i,arg in ipairs(args) do
			local num_str = arg:match(num_pattern)
			if num_str and (num_str:sub(1,2):lower()=="0x") and tonumber(num_str:sub(3), 16) then
				return tonumber(num_str:sub(3), 16), i
			elseif num_str and tonumber(num_str) then
				return tonumber(num_str), i
			end
		end
	end
	local function terminate(reason)
		io.stderr:write("\027[0m\027[31m", reason, "\027[0m\n")
		os.exit()
	end
	
	local mode = config.default_mode
	if get_arg_flag("sdl") then
		mode = "sdl"
	elseif get_arg_flag("terminal") then
		mode = "terminal"
	elseif get_arg_flag("framebuffer") then
		mode = "framebuffer"
	end
	
	local terminal_mode
	if get_arg_flag("braile") then
		terminal_mode = "braile"
		mode = "terminal"
	elseif get_arg_flag("halfblocks") then
		terminal_mode = "halfblocks"
		mode = "terminal"
	elseif get_arg_flag("blocks") then
		terminal_mode = "blocks"
		mode = "terminal"
	end
	if mode == "terminal" then
		local key_table, bpp24
		local braile_use_bg, braile_darken
		terminal_mode = terminal_mode or config.terminal_mode or "braile"
		local xskip = get_arg_num("xskip") or config.terminal_xskip
		local yskip = get_arg_num("yskip") or config.terminal_yskip
		local no_colors = get_arg_flag("no_colors")
		local threshold = get_arg_num("threshold") or config.terminal_threshold or 0
		local blocks_use_chars
		
		if terminal_mode == "braile" then
			braile_use_bg = get_arg_flag("braile_use_bg") or config.terminal_braile_use_bg
			if braile_use_bg then
				if get_arg_num("braile_bg_darken") then
					braile_darken = 1-(math.max(math.min(get_arg_num("braile_bg_darken"), 100), 0)/100)
				end
			end
		end
		if terminal_mode == "blocks" then
			blocks_use_chars = get_arg_flag("use_chars")
		end
		
		bpp24 = get_arg_flag("bpp24") or config.terminal_bpp24
		
		if get_arg_str("key_table") then
			local ok,ret = pcall(require, get_arg_str("key_table"))
			if ok then
				key_table = ret
			end
		else
			key_table = config.terminal_key_table
		end
		
		return input_output.new_terminal({
			braile = (terminal_mode == "braile"),
			halfblocks = (terminal_mode == "halfblocks"),
			bg = braile_use_bg,
			darken = braile_darken,
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
		
		local fbdev = get_arg_str("fb") or config.framebuffer_dev or terminate("Must specify --fb= for framebuffer mode")
		local mousedev = get_arg_str("mouse") or config.framebuffer_mouse_dev or terminate("Must specify --mouse= for framebuffer mode")
		local kbdev = get_arg_str("kb") or config.framebuffer_mouse_dev or terminate("Must specify --kb= for framebuffer mode")
		
		local mouse_sensitivity = get_arg_num("sensitivity") or config.framebuffer_mouse_sensitivity
		if get_arg_str("key_table") then
			local ok,ret = pcall(require, get_arg_str("key_table"))
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
			mouse_sensitivity = mouse_sensitivity
		})
	end
	
	if mode == "sdl" then
		local width, height = get_arg_num("width") or config.sdl_width or terminate("Must specify --width= for SDL mode"), get_arg_num("height") or config.sdl_height or terminate("Must specify --height= for SDL mode")
		local scale = get_arg_num("scale") or config.sdl_scale
		local title = get_arg_str("title") or config.sdl_title
		
		
		return input_output.new_sdl({
			width = width,
			height = height,
			scale = scale,
			title = title,
		})
	else
		terminate("Must specify a mode! Try: --sdl")
	end
	
end


return input_output
