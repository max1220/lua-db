local term = {}
--[[

utillities for working with terminal esacape sequences(Mostly ANSI)
for setting/getting terminal parameters(e.g. foreground color)
]]



-- set the cursor to specified coordinates. x,y start at 0,0
function term.set_cursor(x,y)
	local x = math.floor(tonumber(x) or 0) + 1
	local y = math.floor(tonumber(y) or 0) + 1
	
	return ("\027[%d;%dH"):format(y,x)
end


-- get the screen size(requires tput or bash)
function term.get_screen_size()
	local p = io.popen("tput lines")
	local lines = tonumber(p:read("*a"))
	local cols
	if lines then
		p:close()
		p = io.popen("tput cols")
		cols = assert(tonumber(p:read("*a")))
	else
		p:close()
		p = io.popen("stty size")
		lines, cols = p:read("*a"):match("^(%d+) (%d+)")
		if not lines then
			-- no tput/stty, use bash variables(requires bash)
			lines = os.getenv("LINES")
			cols = os.getenv("COLUMNS")
		end
	end
	p:close()
	return tonumber(cols), tonumber(lines)
end


-- clear the screen(empty all character cells and go to 0,0
function term.clear_screen()
	return "\027[2J"..term.set_cursor(0,0)
end


-- return to default fg/bg color
function term.reset_color()
	return "\027[0m"
end


-- set the new foreground color to the specified r,g,b[0-255] values in 24-bit colorspace
function term.rgb_to_ansi_color_fg_24bpp(r, g, b)
	local r = math.floor(assert(tonumber(r)))
	local g = math.floor(assert(tonumber(g)))
	local b = math.floor(assert(tonumber(b)))
	return "\027[38;2;" .. r .. ";" .. g .. ";" .. b .. "m"
end


-- set the new background color to the specified r,g,b[0-255] values in 24-bit colorspace
function term.rgb_to_ansi_color_bg_24bpp(r, g, b)
	local r = math.floor(assert(tonumber(r)))
	local g = math.floor(assert(tonumber(g)))
	local b = math.floor(assert(tonumber(b)))
	return "\027[48;2;" .. r .. ";" .. g .. ";" .. b .. "m"
end


-- return a ANSI 24-level grey code, or black/white codes 
function term.rgb_to_grey_24(r, g, b)
	local _r = math.floor((r/255)*5)
	local _g = math.floor((g/255)*5)
	local _b = math.floor((b/255)*5)
	
	local avg = (_r + _g + _b) / 3
	local grey_deviation = math.abs(avg-_r) + math.abs(avg-_g) + math.abs(avg-_b)
	
	-- if the grey is pure enough, return a grey code
	if grey_deviation < 1 then
		local grey = math.floor(((_r+_g+_b)/15)*26)
		if grey == 0 then
			-- black
			return 0
		elseif grey == 26 then
			-- white
			return 15
		else
			-- greyscale
			return 231+grey
		end
	end
end


-- set the new foreground color to the specified r,g,b[0-255]
function term.rgb_to_ansi_color_fg_216(r, g, b)
	local _r = math.floor((r/255)*5)
	local _g = math.floor((g/255)*5)
	local _b = math.floor((b/255)*5)
	
	-- 216-color index
	local color_code = 16 + 36*_r + 6*_g + _b
	
	-- checl if color is grey
	if term.rgb_to_grey_24(r,g,b) then
		color_code = term.rgb_to_grey_24(r,g,b)
	end
	
	-- set foreground color ANSI escape sequence
	return "\027[38;5;"..color_code.."m"
end


-- set the new background color to the specified r,g,b values[0-255]
function term.rgb_to_ansi_color_bg_216(r, g, b)
	local _r = math.floor((r/255)*5)
	local _g = math.floor((g/255)*5)
	local _b = math.floor((b/255)*5)
	
	-- 216-color index
	local color_code = 16 + 36*_r + 6*_g + _b
	
	-- checl if color is grey
	if term.rgb_to_grey_24(r,g,b) then
		color_code = term.rgb_to_grey_24(r,g,b)
	end
	
	-- set foreground color ANSI escape sequence
	return "\027[48;5;"..color_code.."m"
end


-- set the new background color to the 24-greyscale version of the r,g,b values[0-255]
function term.rgb_to_ansi_grey_bg_24(r, g, b)
	local color_code = term.rgb_to_grey_24(r,g,b)
	
	-- set foreground color ANSI escape sequence
	return "\027[48;5;"..color_code.."m"
end



return term
