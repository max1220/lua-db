local terminal_emulator = {}

function terminal_emulator.new()
	-- Contains functions for manipulating a terminal emulator state(e.g. write
	-- bytes to terminal causes cursor movement, escape sequences etc.)
	-- TODO: scrollback buffer?
	local term_emu = {}

	function term_emu:init(term_w, term_h)
		-- prepare the terminal emulator
		self.w = term_w or 80
		self.h = term_h or 25
		self.escape = false
		self.csi = false
		self.buffer = {}
		self.scroll_back_buffer = {}
		self.scroll_fwd_buffer = {}
		self:reset()
	end

	function term_emu:reset_attr()
		-- reset attributes(colors, bold/italic)
		self.fg = false -- current fg color
		self.bg = false -- current bg color
		self.bold = false -- current bold attribute
		self.dim = false -- current dim attribute
		self.italic = false -- current italic attribute
		self.underline = false -- current underline attribute
	end

	function term_emu:reset()
		-- perform a full terminal reset(clear attributes, screen, etc.)
		self:reset_attr()
		self:clear()
		self.cursor_x = 1 -- current cursor x position
		self.cursor_y = 1 -- current cursor y position
	end

	function term_emu:clear(_char)
		-- clear the entire terminal buffer
		for y=1, self.h do
			self.buffer[y] = {}
			self:clear_line(y, nil, nil, _char)
		end
	end

	function term_emu:clear_line(line_y, _xmin, _xmax, _char)
		-- clear a terminal line(at line_y), from xmin to xmax(optional)
		local char = _char or " "
		local xmin = tonumber(_xmin) or 1
		local xmax = tonumber(_xmax) or self.w
		local cline = {}
		for x=xmin, xmax do
			cline[x] = {
				char=char,
				fg=false,
				bg=false,
				bold=false,
				italic=false,
				dim=false,
				underline=false
			}
		end
		self.buffer[line_y] = cline
	end

	function term_emu:resize(new_w, new_h)
		-- resize the terminal buffer(keep content)
		local old_w = self.w
		local old_h = self.h
		local old_buffer = self.buffer
		self.w = tonumber(new_w) or 80
		self.h = tonumber(new_h) or 25
		self.buffer = {}
		self:clear()
		for y=1, math.min(old_h,self.h) do
			for x=1, math.min(old_w,self.w) do
				self.buffer[y][x] = old_buffer[y][x]
			end
		end
	end

	function term_emu:scroll_up(count)
		-- scroll the content of the terminal emulator up by count lines
		for _=1, count do
			local removed_line = self.buffer[1]
			table.insert(self.scroll_back_buffer, removed_line) -- save top removed line in scrollback
			for y=1, self.h-1 do
				self.buffer[y] = self.buffer[y+1] -- move content up
			end
			self:clear_line(self.h) -- add new blank line at bottom
			if #self.scroll_fwd_buffer > 0 then
				-- add content from scroll fwd buffer to line at bottom
				local line = table.remove(self.scroll_fwd_buffer)
				self:copy_line(line, self.h)
			end
		end
	end

	function term_emu:scroll_down(count)
		-- scroll the content of the terminal emulator down by count lines
		for _=1, count do
			local removed_line = self.buffer[self.h]
			table.insert(self.scroll_fwd_buffer, removed_line) -- save top removed line in scrollback
			for y=1, self.h-1 do
				self.buffer[y] = self.buffer[y-1] -- move content down
			end
			self:clear_line(1) -- add new blank line at top
			if #self.scroll_back_buffer > 0 then
				-- add content from scroll back buffer to line at top
				local line = table.remove(self.scroll_back_buffer)
				self:copy_line(line, 1)
			end
		end
	end

	function term_emu:write_sgr(sgr)
		-- handle a complete SGR sequence
		if sgr == 0 then
			-- reset sgr parameters
			self:reset_attr()
		elseif sgr == 1 then
			self.bold = true
		elseif sgr == 2 then
			self.dim = true
		elseif sgr == 3 then
			self.italic = true
		elseif sgr == 4 then
			self.underline = true
		elseif (sgr>=30) and (sgr<=37) then
			-- set fg color(1-8)
			self.fg = sgr-30
		elseif sgr == 38 then
			-- set fg color(8bit/24bit)
			-- TODO
			self.fg = false
		elseif sgr == 39 then
			-- reset fg color
			self.fg = false
		elseif (sgr>=40) and (sgr<=47) then
			-- set bg color(1-8)
			self.bg = sgr-40
		elseif sgr == 48 then
			-- set bg color(8bit/24bit)
			-- TODO
			self.bg = false
		elseif sgr == 49 then
			-- reset bg color
			self.bg = false
		end
	end

	function term_emu:write_csi(csi_str)
		-- handle a complete csi sequence
		if csi_str:match("^(%d+)A$") then
			-- cursor up
			self.cursor_y = self.cursor_y - (tonumber(csi_str:match("^(%d+)A")) or 0 )
		elseif csi_str:match("^(%d+)B$") then
			-- cursor down
			self.cursor_y = self.cursor_y + (tonumber(csi_str:match("^(%d+)B")) or 0)
		elseif csi_str:match("^(%d+)C$") then
			-- cursor forward(right)
			self.cursor_x = self.cursor_x + (tonumber(csi_str:match("^(%d+)C")) or 0 )
		elseif csi_str:match("^(%d+)D$") then
			-- cursor back(left)
			self.cursor_x = self.cursor_x - (tonumber(csi_str:match("^(%d+)D")) or 0 )
		elseif csi_str:match("^(%d+)m$") then
			-- cursor down
			local sgr = tonumber(csi_str:match("^(%d+)m$")) or 0
			self:write_sgr(sgr)
		elseif csi_str:match("^(%d+)S$") then
			-- Scroll up
			local count = tonumber(csi_str:match("^(%d+)S$")) or 1
			self:scroll_up(count)
		elseif csi_str:match("^(%d+)T$") then
			-- Scroll down
			local count = tonumber(csi_str:match("^(%d+)T$")) or 1
			self:scroll_down(count)
		elseif csi_str:match("^(%d+)J$") then
			-- erase display
			local n = tonumber(csi_str:match("^(%d+)B")) or 0
			if n == 3 then
				-- TODO: also reset scrollback
				self:clear()
			elseif n == 2 then
				-- clear entire screen
				self:clear()
			elseif n == 1 then
				-- clear from cursor to start
				self:clear_line(self.cursor_y, 1, self.cursor_x)
				for y=1, self.cursor_y-1 do
					self:clear_line(y)
				end
			else
				-- clear from cursor to end
				self:clear_line(self.cursor_y, self.cursor_x)
				for y=self.cursor_y+1, self.h do
					self:clear_line(y)
				end
			end
		elseif csi_str:match("^(%d+);(%d+)[Hf]$") then
			-- cursor position(row and column)
			local row, column = csi_str:match("^(%d*);(%d*).$")
			row = tonumber(row) or 1
			column = tonumber(column) or 1
			self.cursor_x = math.min(row, self.w)
			self.cursor_y = math.min(column, self.h)
		elseif csi_str:match("^(%d+);(%d+)H$") then
			-- cursor position(row only)
			local row = tonumber(csi_str:match("^(%d*)H$")) or 1
			self.cursor_x = math.min(row, self.w)
		end
	end

	function term_emu:write_escape(char)
		local byte = char:byte()
		if self.csi then
			if (byte < 0x20) or (byte > 0x7F) then
				-- abort sequence(invalid character for csi)
				self.escape = false
				if char ~= "\027" then
					self:write_byte(char)
				end
			elseif (byte > 0x3F) then
				-- end sequence(char indicates function)
				table.insert(self.csi, char)
				local csi_str = table.concat(self.csi)
				self:write_csi(csi_str)
				self.csi = false
				self.escape = false
			else
				-- parameters
				table.insert(self.csi, char)
			end
			return
		end

		if (byte < 0x40) or (byte > 0x7f) then
			-- abort sequence(invalid character to begin a sequence)
			self.escape = false
			if char ~= "\027" then
				self:write_byte(char)
			end
			return
		end
		table.insert(self.escape, char)

		if char == "c" then
			-- reset terminals
			self:clear()
			self:reset()
			self.escape = false
		elseif char == "[" then
			-- begin csi
			self.csi = {}
		end
	end

	function term_emu:write_byte(char)
		-- handle a single byte of input to the terminal

		-- if we're in an escape sequence...
		if self.escape then
			self:write_escape(char)
			return true
		end

		if char == "\n" then
			self.cursor_x = 1
			self.cursor_y = self.cursor_y + 1
		elseif char == "\r" then
			self.cursor_x = 1
		elseif char == "\027" then
			self.escape = {char}
		else
			-- set a character at the cursor
			print("self.cursor_y,self.cursor_x", self.cursor_y,self.cursor_x)
			self.buffer[self.cursor_y][self.cursor_x] = {
				char=char,
				fg=self.fg,
				bg=self.bg,
				bold=self.bold,
				italic=self.italic,
				dim=self.dim,
				underline=self.underline
			}
			self.cursor_x = self.cursor_x + 1
			if self.cursor_x > self.w then
				self.cursor_x = 1
				self.cursor_y = self.cursor_y + 1
			end
		end

		if self.cursor_x > self.w then
			-- TODO: Check if newline?
			self.cursor_x = self.w
		elseif self.cursor_x < 1 then
			self.cursor_x = 1
		end

		if self.cursor_y > self.h then
			local delta = self.cursor_y-self.h
			self:scroll_up(delta)
			self.cursor_y = self.cursor_y-delta
		elseif self.cursor_y < 1 then
			self:scroll_down(1-self.cursor_y)
		end

		return true
	end

	function term_emu:write(str)
		-- handle a sequence of bytes of input to the terminal
		for i=1, #str do
			local char = str:sub(i,i)
			if not self:write_byte(char) then
				return false
			end
		end
		return true
	end

	return term_emu
end

return terminal_emulator
