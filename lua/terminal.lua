local terminal = {}
--[[
Utillities for working with ANSI terminal esacape sequences.
]]



function terminal.new_terminal(write_cb, read_cb, term_type)
	local term = {}
	assert(type(write_cb)=="function")

	term.write_cb = write_cb
	term.read_cb = read_cb
	term.palettes = require("lua-db.terminal_palettes")
	term.term_type = term_type or "ansi" -- term_types = {"linux", "ansi_3bit", "ansi_4bit", "ansi_8bit", "ansi_24bit"}

	function term:set_cursor(_x,_y)
		local x = math.floor(tonumber(_x) or 0) + 1
		local y = math.floor(tonumber(_y) or 0) + 1
		self:write_cb(("\027[%d;%dH"):format(y,x))
	end

	function term:get_cursor()
		if self.read_cb then
			self:write_cb("\027[6n")
			local input = self:read_cb()
			while not input do
				input = self:read_cb()
			end
			local y,x = input:match("\027[(%d+);(%d+)R")
			if y and x then
				return x,y
			end
		end
	end

	function term:get_screen_size()
		self:set_cursor(998,998)
		local w,h = self:get_cursor()
		return w,h
	end

	function term:clear_screen()
		self:write_cb("\027[2J"..self:set_cursor(0,0))
	end

	function term:reset_color()
		self:write_cb("\027[0m")
	end


	local function check_color(_r,_g,_b)
		local r = math.min(math.max(math.floor(assert(tonumber(_r))), 0), 255)
		local g = math.min(math.max(math.floor(assert(tonumber(_g))), 0), 255)
		local b = math.min(math.max(math.floor(assert(tonumber(_b))), 0), 255)
		return r,g,b
	end

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

	function term:set_fg_color_ansi_24bit(_r, _g, _b)
		local r,g,b = check_color(_r,_g,_b)
		return self:write_cb("\027[38;2;" .. r .. ";" .. g .. ";" .. b .. "m")
	end
	function term:set_fg_color_ansi_8bit(r,g,b)
		return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_8bit, r,g,b).code)
	end
	function term:set_fg_color_ansi_4bit(r,g,b)
		return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_4bit, r,g,b).code)
	end
	function term:set_fg_color_ansi_3bit(r,g,b)
		return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_3bit, r,g,b).code)
	end
	function term:set_bg_color_ansi_24bit(_r, _g, _b)
		local r,g,b = check_color(_r,_g,_b)
		return self:write_cb("\027[48;2;" .. r .. ";" .. g .. ";" .. b .. "m")
	end
	function term:set_bg_color_ansi_8bit(r,g,b)
		return self:write_cb(get_palette_entry_for_color(self.palettes.bg_palette_8bit, r,g,b).code)
	end
	function term:set_bg_color_ansi_4bit(r,g,b)
		return self:write_cb(get_palette_entry_for_color(self.palettes.bg_palette_4bit, r,g,b).code)
	end
	function term:set_bg_color_ansi_3bit(r,g,b)
		return self:write_cb(get_palette_entry_for_color(self.palettes.bg_palette_3bit, r,g,b).code)
	end

	function term:set_fg_color(r,g,b)
		if self.term_type == "ansi_24bit" then
			-- use the 24-bit colors
			return self:set_fg_color_ansi_24bit(r,g,b)
		elseif self.term_type == "ansi_8bit" then
			-- use the 216 colors + 24 grey level ansi escape sequences
			return self:set_fg_color_ansi_8bit(r,g,b)
		elseif self.term_type == "ansi_4bit" then
			-- use the extended 16 ANSI colors(8 normal + 8 bright)
			return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_4bit).code)
		elseif self.term_type == "ansi_3bit" then
			-- use the basic 8 ANSI colors
			return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_3bit).code)
		elseif self.term_type == "linux" then
			-- linux supports the 4bit ANSI foreground color
			return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_4bit).code)
		end
	end

	function term:set_bg_color(r,g,b)
		if self.term_type == "ansi_24bit" then
			-- use the 24-bit colors
			return self:set_fg_color_ansi_24bit(r,g,b)
		elseif self.term_type == "ansi_8bit" then
			-- use the 216 colors + 24 grey level ansi escape sequences
			return self:set_fg_color_ansi_8bit(r,g,b)
		elseif self.term_type == "ansi_4bit" then
			-- use the extended 16 ANSI colors(8 normal + 8 bright)
			return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_4bit).code)
		elseif self.term_type == "ansi_3bit" then
			-- use the basic 8 ANSI colors
			return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_3bit).code)
		elseif self.term_type == "linux" then
			-- linux supports the 4bit ANSI foreground color
			return self:write_cb(get_palette_entry_for_color(self.palettes.fg_palette_4bit).code)
		end
	end

	return term
end



return terminal
