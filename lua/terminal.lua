local terminal = {}
--[[
Utillities for working with ANSI terminal esacape sequences.

Exports a single function:

	term = terminal.new_terminal(write_cb, read_cb, terminal_type, supports_unicode)

	write_cb(self, str)

	is a function that outputs to str to the terminal
emulator.

	read_cb(self)

is an optional function that if provided allows feedback from the terminal(
Needed to get terminal size).
The default is to not support reading(some functions return nil).

	term_type

is an optional string(One of "linux", "ansi_3bit", "ansi_4bit", "ansi_8bit", "ansi_24bit").
It determines the assumed capabillities of the terminal emulator.
The default is "ansi_24bit".

The returned term objects has the following functions:
term:set_cursor(x,y)
term:get_cursor(x,y)
w,h = term:get_screen_size()
term:clear_screen()
term:reset_color()
term:set_fg_color(r,g,b)
term:set_bg_color(r,g,b)
]]





function terminal.new_terminal(write_cb, read_cb, term_type, supports_unicode)
	local term = {}
	assert(type(write_cb)=="function")

	-- append drawbuffer drawing routines(:drawbuffer_colors(), :drawbuffer_characters(), etc.)
	local terminal_drawbuffer = require("lua-db.terminal_drawbuffer")
	terminal_drawbuffer(term)

	term.write_cb = write_cb -- used to write to the terminal(emulator).
	term.read_cb = read_cb -- used to read from the terminal.
	term.palettes = require("lua-db.terminal_palettes") -- list of escape codes and r,g,b values. Used for setting colors.
	term.term_type = term_type or "ansi_3bit" -- term_types = "linux", "ansi_3bit", "ansi_4bit", "ansi_8bit", "ansi_24bit"
	term.supports_unicode = term_type ~= "linux"
	term.no_color = false
	if supports_unicode ~= nil then
		term.supports_unicode = supports_unicode
	end

	term.read_buf = {} -- the buffer of last received characters
	term.read_buf_len = 16 -- buffer length
	function term:read() -- read using read_cb if available(returns last character buffer, for easy pattern matching)
		if not term.read_cb then
			return
		end
		local str = self:read_cb() -- should be a string of length 1
		if str then
			table.insert(self.read_buf, str)
			if #self.read_buf>self.read_buf_len then
				table.remove(self.read_buf, 1) -- keep the buffer at read_buf_len entries
			end
		end
		return table.concat(self.read_buf) -- always return the complete buffer
	end

	-- set cursor to x,y
	function term:set_cursor(_x,_y)
		local x = math.floor(tonumber(_x) or 0) + 1
		local y = math.floor(tonumber(_y) or 0) + 1
		return self:write_cb(("\027[%d;%dH"):format(y,x))
	end

	-- set cursor to top-left
	function term:reset_cursor()
		return self:write_cb("\027[;H")
	end

	-- get the cursor position. Only possible if the read_cb is provided, since
	-- the actual terminal(emulator) needs to answer.
	function term:get_cursor()
		self:write_cb("\027[6n")
		-- self:read() returns nil if read is not available, a string otherwise, even if read_cb() returned nil.
		-- Reads up to one character per call(might be zero if read_cb works "non-blocking", returning nil for some calls).
		local input_buf = self:read()
		if input_buf == nil then
			return -- read_cb not available
		end
		for _=1, self.read_buf_len do -- need to fill :read() internal buffer
			local y,x = input_buf:match("\027[(%d+);(%d+)R$") -- match at end to only call per occurance in the buffer
			if y and x then
				return x,y -- found a valid sequence, return cursor coordinates as repored by terminal
			end
			input_buf = self:read() -- atempt again after reading another character
		end
		-- pattern not found in input from read_cb after enough atempts
	end

	-- get the terminal size by ANSI escape sequences
	function term:get_screen_size()
		-- set cursor to a very large x,y value
		self:set_cursor(998,998)
		-- get cursor positions(cursor is at lower-right corner)
		local w,h = self:get_cursor()
		return w,h
	end

	function term:alternate_screen_buffer(enabled)
		if enabled then
			return self:write_cb("\027[?1049h") -- Enable alternative screen buffer
		else
			return self:write_cb("\027[?1049l") -- Disable alternative screen buffer
		end
	end

	function term:mouse_tracking(enabled)
		if enabled then -- see xterm ctlseqs
			self:write_cb("\027[?1000h") -- enable X11-style mouse tracking(report mouse button press and mouse button release)
			self:write_cb("\027[?1003h") -- enable all mouse movement reports
			self:write_cb("\027[?1006h") -- report as decimal for xterm-like
			self:write_cb("\027[?1015h") -- report as decimal for urxvt
		else
			self:write_cb("\027[?1000l") -- disable all mouse tracking
			self:write_cb("\027[?1003l")
			self:write_cb("\027[?1006l")
			self:write_cb("\027[?1015l")
		end
	end

	-- clear the screen
	function term:clear_screen()
		return self:write_cb("\027[2J"..self:set_cursor(0,0))
	end

	-- reset the SGR parameters, clear the screen, and set cursor to top left.
	function term:reset_all()
		self:reset_color()
		self:clear_screen()
		self:reset_cursor()
	end

	-- reset the SGR attributes(fg/bg color, bold, ...)
	function term:reset_color()
		return self:write_cb("\027[0m")
	end

	-- check r,g,b values
	local function check_color(_r,_g,_b)
		local r = math.min(math.max(math.floor(assert(tonumber(_r))), 0), 255)
		local g = math.min(math.max(math.floor(assert(tonumber(_g))), 0), 255)
		local b = math.min(math.max(math.floor(assert(tonumber(_b))), 0), 255)
		return r,g,b
	end

	-- map the r,g,b values to the aviable palette entries
	local function get_palette_entry_for_color(palette, _r,_g,_b)
		local r,g,b = check_color(_r,_g,_b)
		local min_dist = math.huge
		local min_entry
		for i=1, #palette do
			local entry = palette[i]
			local dist = ((entry.r-r)^2) + ((entry.g-g)^2) + ((entry.b-b)^2)
			if dist <= min_dist then
				min_entry = entry
				min_dist = dist
			end
		end
		return min_entry, min_dist
	end

	-- write the terminal escape sequence
	function term:fg_color_ansi_24bit(r,g,b)
		r,g,b = check_color(r,g,b)
		return "\027[38;2;" .. r .. ";" .. g .. ";" .. b .. "m"
	end
	function term:fg_color_ansi_8bit(r,g,b)
		return get_palette_entry_for_color(self.palettes.fg_palette_8bit, r,g,b).code
	end
	function term:fg_color_ansi_4bit(r,g,b)
		return get_palette_entry_for_color(self.palettes.fg_palette_4bit, r,g,b).code
	end
	function term:fg_color_ansi_3bit(r,g,b)
		return get_palette_entry_for_color(self.palettes.fg_palette_3bit, r,g,b).code
	end
	function term:bg_color_ansi_24bit(r,g,b)
		r,g,b = check_color(r,g,b)
		return "\027[48;2;" .. r .. ";" .. g .. ";" .. b .. "m"
	end
	function term:bg_color_ansi_8bit(r,g,b)
		return get_palette_entry_for_color(self.palettes.bg_palette_8bit, r,g,b).code
	end
	function term:bg_color_ansi_4bit(r,g,b)
		return get_palette_entry_for_color(self.palettes.bg_palette_4bit, r,g,b).code
	end
	function term:bg_color_ansi_3bit(r,g,b)
		return get_palette_entry_for_color(self.palettes.bg_palette_3bit, r,g,b).code
	end

	-- set the terminal foreground color(automatic terminal type)
	function term:fg_color(r,g,b)
		if self.no_color then
			return ""
		end
		if self.term_type == "ansi_24bit" then
			-- use the 24-bit colors
			return self:fg_color_ansi_24bit(r,g,b)
		elseif self.term_type == "ansi_8bit" then
			-- use the 216 colors + 24 grey level ansi escape sequences
			return self:fg_color_ansi_8bit(r,g,b)
		elseif self.term_type == "ansi_4bit" then
			-- use the extended 16 ANSI colors(8 normal + 8 bright)
			return self:fg_color_ansi_4bit(r,g,b)
		elseif self.term_type == "ansi_3bit" then
			-- use the basic 8 ANSI colors
			return self:fg_color_ansi_3bit(r,g,b)
		elseif self.term_type == "linux" then
			-- linux supports the 4bit ANSI foreground color
			return self:fg_color_ansi_4bit(r,g,b)
		end
	end

	-- set the terminal background color(automatic terminal type)
	function term:bg_color(r,g,b)
		if self.no_color then
			return ""
		end
		if self.term_type == "ansi_24bit" then
			-- use the 24-bit colors
			return self:bg_color_ansi_24bit(r,g,b)
		elseif self.term_type == "ansi_8bit" then
			-- use the 216 colors + 24 grey level ansi escape sequences
			return self:bg_color_ansi_8bit(r,g,b)
		elseif self.term_type == "ansi_4bit" then
			-- use the extended 16 ANSI colors(8 normal + 8 bright)
			return self:bg_color_ansi_4bit(r,g,b)
		elseif self.term_type == "ansi_3bit" then
			-- use the basic 8 ANSI colors
			return self:bg_color_ansi_3bit(r,g,b)
		elseif self.term_type == "linux" then
			-- linux supports the 4bit ANSI foreground color
			return self:bg_color_ansi_4bit(r,g,b)
		end
	end

	function term:set_fg_color(r,g,b)
		return self:write_cb(self:fg_color(r,g,b))
	end

	function term:set_bg_color(r,g,b)
		return self:write_cb(self:bg_color(r,g,b))
	end

	-- draws a vertical percentage bar using unicode block characters. Len is length in characters, pct the percentage(0-1)
	function term:draw_pct_bar_unicode(len, pct)
		local blocks = {
			string.char(0xE2,0x96,0x8F),
			string.char(0xE2,0x96,0x8E),
			string.char(0xE2,0x96,0x8D),
			string.char(0xE2,0x96,0x8C),
			string.char(0xE2,0x96,0x8B),
			string.char(0xE2,0x96,0x8A),
			string.char(0xE2,0x96,0x89),
		}
		local fill = string.char(0xE2, 0x96, 0x88)
		local str = {}
		local fill_end = math.floor(len*pct)
		local empty_start = math.ceil(len*pct)
		for i=1, len do
			local i_pct = (i-1)/(len-1)
			if i <= fill_end then
				table.insert(str, fill)
			elseif i > empty_start then
				table.insert(str, " ")
			else
				local rem = math.floor(((pct-(fill_end/len))/(1/len))*7)+1
				table.insert(str, blocks[rem])
			end
		end
		return table.concat(str)
	end

	-- draw a percentage bar using only 7bit ASCII characters.
	function term:draw_pct_bar_ascii(len, pct)
		local str = {}
		table.insert(str, "[")
		for i=1, len-2 do
			local cpct = (i-1)/(len-3)
			if cpct<=pct then
				table.insert(str, "#")
			else
				table.insert(str, " ")
			end
		end
		table.insert(str, "]")
		return table.concat(str)
	end

	function term:draw_pct_bar(len, pct)
		if self.supports_unicode then
			return term:draw_pct_bar_unicode(len, pct)
		else
			return term:draw_pct_bar_ascii(len, pct)
		end
	end

	return term
end



return terminal
