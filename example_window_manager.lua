#!/usr/bin/env luajit
local ldb = require("lua-db")
--local sdl2fb = require("sdl2fb")
local input_output = require("input_output")
local gui = require("gui")
local time = require("time")


local window_manager = require("window_manager")


local w = tonumber(arg[1]) or 800
local h = tonumber(arg[2]) or 600


-- optionally scale up
local scale = tonumber(arg[3]) or 1
local scale_db
if scale > 1 then
	scale_db = ldb.new(w*scale, h*scale)
end


local wm

local mouse_x = 0
local mouse_y = 0
local draw_mouse = false

-- select output
local out_mode = arg[4]
local cio
if (not out_mode) or (out_mode == "sdl") then
	cio = input_output.new_sdl({
		width = w*scale,
		height = h*scale,
		title = "Window manager Example"
	})
elseif out_mode == "fb" then
	cio = input_output.new_framebuffer({
		fbdev = "/dev/fb0",
		kbdev = "/dev/input/event0",
		mousedev = "/dev/input/event2"
	})
	draw_cursor = true
elseif out_mode == "term" then
	cio = input_output.new_terminal({
		braile = true,
		halfblocks = false,
		xskip = 1,
		yskip = 1,
		bpp24 = true,
		threshold = 1,
		bg = false
	})
	draw_cursor = true
else
	error("Unknown output method!")
end
cio:init()
w,h = cio:get_native_size()

-- load fonts
local font_sm = ldb.font.from_file("cga8.bmp", 8,8, {0,0,0}, 1)
local font_lg = ldb.font.from_file("cga8.bmp", 8,8, {0,0,0}, 2)

-- target drawbuffer for output
local db = ldb.new(w,h)


local function digital_clock_element(config)
	local clock_e = gui.new_callback(config)
	local time_str = ""
	function clock_e:callback(db, ox, oy)
		config.font:draw_string(db, time_str, ox+5, oy+5)
	end
	function clock_e:update(dt)
		time_str = os.date("%H:%M:%S")
	end
	clock_e.min_width = 140
	clock_e.min_height = 25
	clock_e.title = "Digital clock"
	clock_e.background_color = config.background_color or {128,128,128,255}
	return clock_e
end


local function analog_clock_element(config)
	local clock = require("clock")

	local clock_e = gui.new_callback(config)
	local t = {
		hour=0,
		min=0,
		sec=0
	}
	function clock_e:callback(db, ox, oy)
		clock.draw_clock(db, self.width,self.height, ox,oy, t.hour, t.min, t.sec, true)
	end
	function clock_e:update(dt)
		t = os.date("*t")
	end
	clock_e.min_width = 50
	clock_e.min_height = 50
	clock_e.title = "Analog clock"
	clock_e.background_color = {16,16,16,255}
	return clock_e
end


local function fps_element(config)

	local _dt = 0
	local dts = {}
	local dts_i = 0
	local dts_samples = 100
	local function dts_update(dt)
		dts_i = (dts_i + 1)%dts_samples
		dts[dts_i+1] = dt
		_dt = dt
	end
	local function dts_stats()
		local max = 0
		local min = math.huge
		local avg = 0
		for i=1, #dts do
			max = math.max(max, dts[i] or 0)
			min = math.min(min, dts[i] or math.huge)
			avg = avg + (dts[i] or 0)
		end
		avg = avg / #dts
		return min, avg, max
	end


	local fps_e = gui.new_callback(config)
	fps_e.min_width = 185
	fps_e.min_height = 80
	function fps_e:callback(db, ox, oy)
		config.font_lg:draw_string(db, ("FPS: %6.2f"):format(1/dt), ox+5,oy+5)
		local min,avg,max = dts_stats()
		config.font_sm:draw_string(db, ("Min:    %6.2f"):format(1/max), ox+5,oy+25)
		config.font_sm:draw_string(db, ("Avg:    %6.2f"):format(1/avg), ox+5,oy+35)
		config.font_sm:draw_string(db, ("Max:    %6.2f"):format(1/min), ox+5,oy+45)
		config.font_sm:draw_string(db, ("width:  %4d"):format(w), ox+5,oy+55)
		config.font_sm:draw_string(db, ("height: %4d"):format(h), ox+5,oy+65)
	end
	function fps_e:update(dt)
		dts_update(dt)
		--time.sleep(0.01)
	end
	fps_e.title = "FPS Stats"
	fps_e.background_color = {128,128,128,255}
	return fps_e
end


local function video_element(config)
	local video
	if config.type == "v4l2" then
		video = ldb.ffmpeg.open_v4l2(config.device, config.width, config.height, true)
	elseif config.type == "file" then
		video = ldb.ffmpeg.open_file(config.file, config.width, config.height, config.seek, config.audio, true)
	elseif config.type == "command" then
		video = ldb.ffmpeg.open_command(config.command, config.width, config.height, true)
	end
	local video_db = ldb.new(config.width, config.height)
	video_db:clear(0,0,0,0)
	config.db = video_db
	local webcam_e = gui.new_surface(config)
	webcam_e.title = "ffmpeg: " .. config.type
	local first = true
	function webcam_e:update(dt)
		if first then
			video:start()
			first = false
		end
		local frame = video:read_frame()
		if frame then
			video:draw_frame_to_db(video_db, frame)
		end
	end
	function webcam_e:on_close()
		video:close()
	end
	webcam_e.min_width = config.width
	webcam_e.min_height = config.height
	return webcam_e
end


local function tetris_element(config)
	local tetris = require("tetris")

	local board_w = config.board_w or 10
	local board_h = config.board_h or 16
	local board_scale = config.board_scale or 16
	local colors = config.colors or {
		{255,0,0,255},
		{0,255,0,255},
		{0,0,255,255},
		{255,255,0,255},
		{0,255,255,255},
		{255,0,255,255}
	}
	local font_sm = config.font_sm
	local font_lg = config.font_lg

	local tetris_game = tetris.new_tetris(board_w, board_h)
	tetris_game:reset()
	local run = true
	function tetris_game:gameover()
		run = false
	end

	tetris_board_e = gui.new_callback({
		x = 0,
		y = 0,
		width = board_w*board_scale,
		height = board_h*board_scale
	})
	function tetris_board_e:callback(db, ox, oy)
		db:set_rectangle(ox,oy,self.width,self.height, 12,12,12,255)
		tetris_game:draw_board_to_db(db, board_scale, ox, oy, colors)
	end

	tetris_ui_e = gui.new_callback({
		x = board_w*board_scale,
		y = 0,
		width = 100,
		height = board_h*board_scale
	})
	function tetris_ui_e:callback(db, ox, oy)
		db:set_rectangle(ox,oy,self.width,6*board_scale, 12,12,64,255)
		local tile = tetris_game.tiles[tetris_game.next_tile_id or 1]
		local tile_color = colors[tetris_game.next_tile_id]

		if run then
			font_lg:draw_string(db, "Score:", ox+5,oy+6*board_scale+10)
			font_lg:draw_string(db, ("%6d"):format(tetris_game.score or 0), ox+5,oy+6*board_scale+30)
		else
			font_lg:draw_string(db, "Game", ox+5,oy+6*board_scale+10)
			font_lg:draw_string(db, "  Over", ox+5,oy+6*board_scale+30)
			tile = {
				{1,0,0,1},
				{0,0,0,0},
				{0,1,1,0},
				{1,0,0,1},
			}
			tile_color = colors[3]
		end

		if tile then
			for y=1, 4 do
				for x=1, 4 do
					if tile[y][x] ~= 0 then
						local r,g,b,a = tile_color[1], tile_color[2], tile_color[3], tile_color[4]
						db:set_rectangle(ox+x*board_scale,oy+y*board_scale,board_scale,board_scale, r,g,b,a)
					end
				end
			end
		end
	end



	config.elements = {tetris_board_e, tetris_ui_e}
	config.width = board_w*board_scale + 100
	config.height = board_h*board_scale

	local tetris_e = gui.new_group(config)
	function tetris_e:handle_key_event(key,event)
		if run then
			if event.type == "keydown" then
				if key == "Up" then
					tetris_game:rotate_right()
				elseif key == "Down" then
					tetris_game:down()
				elseif key == "Left" then
					tetris_game:left()
				elseif key == "Right" then
					tetris_game:right()
				end
			end
		end
	end
	function tetris_e:update(dt)
		if run then
			tetris_game:update_timer(dt)
		end
	end
	tetris_e.background_color = {32,32,64,255}
	tetris_e.title = "Tetris"
	tetris_e.min_width = board_w*board_scale + 100
	tetris_e.min_height = board_h*board_scale
	return tetris_e
end


local function tmt_terminal_element(config)

	local tmt = require("tmt")
	local lpty = require("lpty")

	local term_w = config.term_w or 80
	local term_h = config.term_h or 25
	local font = config.font
	local char_w = font.char_w
	local char_h = font.char_h
	local width =  term_w * char_w
	local height = term_h * char_h
	config.width = config.width or width
	config.height = config.height or height
	local bg = config.background_color or {0,0,0,255}
	local cursor_color = config.cursor_color or {255,255,255,255}
	local colors = config.colors or {
		{0,0,0,255},
		{255,0,0,255},
		{0,255,0,255},
		{0,255,255,255},
		{0,0,255,255},
		{255,0,255,255},
		{0,255,255,255},
		{255,255,255,255},
	}


	local db = ldb.new(width, height)
	db:clear(bg[1], bg[2], bg[3], bg[4])
	config.db = db
	local term = tmt.new(term_w, term_h)
	local pty = lpty.new()

	local function redraw_cell(x,y,cell, is_cursor)
		local dx = (x-1)*char_w
		local dy = (y-1)*char_h
		if cell.bg > 0 then
			local color = colors[cell.bg]
			db:set_rectangle(dx,dy, char_w, char_h, color[1], color[2], color[3], color[4])
		end
		if is_cursor then
			db:set_line(dx,dy+char_h,dx+char_w,dy+char_h, cursor_color[1], cursor_color[2], cursor_color[3], cursor_color[4])
		end
		if cell.fg > 0 then
			config.font:draw_character(db, cell.char, dx, dy, colors[cell.fg])
		else
			config.font:draw_character(db, cell.char, dx, dy)
		end
	end

	local function redraw_full(term)
		local screen = term:get_screen()
		local cursor_x, cursor_y = term:get_cursor()
		db:clear(bg[1], bg[2], bg[3], bg[4])
		for y,line in ipairs(screen.lines) do
			if line.dirty then
				for x,cell in ipairs(line) do
					redraw_cell(x,y,cell, (cursor_x==x) and (cursor_y==y))
				end
			end
		end
	end

	assert(pty:startproc(config.proc or "bash"))
	local write_buf = ""
	local function write(...)
		for _, v in ipairs({...}) do
			write_buf = write_buf .. v
		end
	end


	local terminal_e = gui.new_surface(config)


	function terminal_e:update(dt)

		local new_term_w = math.floor(self.width / char_w)
		local new_term_h = math.floor(self.height / char_h)
		if (new_term_w ~= term_w) or (new_term_h ~= term_h) then
			db = ldb.new(new_term_w*char_w, new_term_h*char_h)
			db:clear(bg[1], bg[2], bg[3], bg[4])
			self.db = db
			term:set_size(new_term_w, new_term_h)
			term_w = new_term_w
			term_h = new_term_h
			redraw_full(term)
		end


		-- consume from write_buf
		if (#write_buf > 0) and pty:sendok() then
			local sent = pty:send(write_buf, 0)
			if sent then
				write_buf = write_buf:sub(sent+1)
			end
		end

		-- check if the pty has data, and forward to the terminal emulator
		if pty:readok() then
			local str = pty:read(0)
			local events = term:write(str)
			for k,ev in ipairs(events) do
				if ev.type == "screen" then
					redraw_full(term)
				elseif ev.type == "cursor" then
					redraw_full(term)
				end
			end
		end

	end
	local shift_down
	local ctrl_down
	function terminal_e:handle_key_event(key, event)
		if event.type == "keyup" then
			if key == "Left Shift" then
				shift_down = false
			elseif key == "Left Ctrl" then
				ctrl_down = false
			elseif key == "Up" then
				write(tmt.special_keys.KEY_UP)
			elseif key == "Down" then
				write(tmt.special_keys.KEY_DOWN)
			elseif key == "Left" then
				write(tmt.special_keys.KEY_LEFT)
			elseif key == "Right" then
				write(tmt.special_keys.KEY_RIGHT)
			elseif key == "Backspace" then
				write(tmt.special_keys.KEY_BACKSPACE)
			elseif key and (#key == 1) then
				if ctrl_down then
					local c = key:byte() - 64
					if (c > 0) and (c < 27) then
						write(string.char(27, c))
					end
				elseif shift_down and tonumber(key) then
					local t = {[0]="=", "!", "\"", "", "$", "%", "&", "/", "(", ")"}
					write(t[tonumber(key)])
				elseif shift_down then
					write(key)
				else
					write(key:lower())
				end
			elseif key == "Return" then
				write("\n")
			elseif key == "Space" then
				write(" ")
			elseif key == "Tab" then
				write("\t")
			else
				print("unknown term key:", key)
			end
		elseif event.type == "keydown" then
			if key == "Left Shift" then
				shift_down = true
			elseif key == "Left Ctrl" then
				ctrl_down = true
			end
		end
	end
	terminal_e.background_color = {0,0,0,255}
	terminal_e.min_width = width
	terminal_e.min_height = height

	return terminal_e
end


local function rote_terminal_element(config)
	local rote = require("rote")

	local term_w = config.term_w or 80
	local term_h = config.term_h or 25
	local font = assert(config.font)
	local char_w = font.char_w
	local char_h = font.char_h
	config.width = config.width or (term_w * char_w)
	config.height = config.height or (term_h * char_h)
	local bg = config.background_color or {0,0,0,255}
	local draw_color = config.draw_color or true

	local default_colors = {
		{0,0,0,255},
		{255,0,0,255},
		{0,255,0,255},
		{0,255,255,255},
		{0,0,255,255},
		{255,0,255,255},
		{0,255,255,255},
		{255,255,255,255},
	}

	local fg_colors = config.fg_colors or config.colors or default_colors
	local bg_colors = config.bg_colors or config.colors or default_colors

	local term = rote.RoteTerm(term_h, term_w)
	local pid = term:forkPty(config.proc or "bash")
	if pid == -1 then
		print("Can't run command!")
		return
	end

	local db = ldb.new(config.width, config.height)
	config.db = db
	db:clear(bg[1],bg[2],bg[3],bg[4])

	local terminal_e = gui.new_surface(config)

	local function redraw_cell(x,y)
		local char = term:cellChar(y,x)
		if char ~= " " then
			local dx = x*char_w
			local dy = y*char_h
			if draw_color then
				local foreground, background, bold, blink = rote.fromAttr(term:cellAttr(y,x))
				local fg_color = fg_colors[foreground+1]
				local bg_color = bg_colors[background+1]
				if bg_color then
					db:set_rectangle(dx,dy, char_w, char_h, bg_color[1], bg_color[2], bg_color[3], bg_color[4])
				end
				config.font:draw_character(db, char:byte(), dx, dy, fg_color)
			else
				config.font:draw_character(db, char:byte(), dx, dy)
			end
		end
	end

	local function redraw_cursor()
		local cursor_x, cursor_y = term:col(), term:row()
		local foreground, background, bold, blink = rote.fromAttr(term:attr(cursor_y,cursor_x))
		local cursor_color = fg_colors[foreground] or {255,0,255,255}
		local dx = cursor_x*char_w
		local dy = cursor_y*char_h
		db:set_line(dx,dy+char_h, dx+char_w, dy+char_w, cursor_color[1], cursor_color[2], cursor_color[3], cursor_color[4])
	end

	local function redraw_full()
		db:clear(bg[1],bg[2],bg[3],bg[4])
		for y=0, term:rows()-1 do
			for x=0, term:cols()-1 do
				redraw_cell(x,y)
			end
		end
		redraw_cursor()
	end

	function terminal_e:update(dt)
		term:update()
		redraw_full()
	end

	local function write(str)
		term:write(str)
	end

	local shift_down
	local ctrl_down
	function terminal_e:handle_key_event(key, event)
		if event.type == "keyup" then
			if key == "Left Shift" then
				shift_down = false
			elseif key == "Left Ctrl" then
				ctrl_down = false
			elseif key == "Up" then
				write("\027[A")
			elseif key == "Down" then
				write("\027[B")
			elseif key == "Left" then
				write("\027[D")
			elseif key == "Right" then
				write("\027[C")
			elseif key == "Backspace" then
				write("\008")
			elseif key and (#key == 1) then
				if ctrl_down then
					local c = key:byte() - 64
					if (c > 0) and (c < 27) then
						write(string.char(27, c))
					end
				elseif shift_down and tonumber(key) then
					local t = {[0]="=", "!", "\"", "", "$", "%", "&", "/", "(", ")"}
					write(t[tonumber(key)])
				elseif shift_down then
					write(key)
				else
					write(key:lower())
				end
			elseif key == "Return" then
				write("\n")
			elseif key == "Space" then
				write(" ")
			elseif key == "Tab" then
				write("\t")
			else
				print("unknown term key:", key)
			end
		elseif event.type == "keydown" then
			if key == "Left Shift" then
				shift_down = true
			elseif key == "Left Ctrl" then
				ctrl_down = true
			end
		end
	end

	terminal_e.title = "ROTE terminal"

	return terminal_e
end


local function fire_element(config)

	local perlin = require("perlin")

	local function get_color(val,y_pct)
		local r,g,b,a = 0,0,0,255

		--y_pct = 0.5

		r = math.sin(val+1.4*y_pct)*(y_pct+0.1)*val*255
		g = math.sin(val)*y_pct*val*val*192

		r = math.max(math.min(r,255),0)
		g = math.max(math.min(g,255),0)

		-- val = math.max(math.min(val*255,255),0)

		--return r,g,b,a
		return r,g,b,255
	end

	local function draw_noise(db,width,height,ox,oy,cy)
		local freq = config.freq or 0.02
		local depth = config.depth or 4
		local seed = 1234
		local x_mod = 0.6
		local y_mod = 0.2 -- perlin.noise2d(x, y, freq, depth, seed)
		--local x_mod = 1
		--local y_mod = 1
		for y=0, height-1 do
			for x=0, width-1 do
				local val = perlin.noise2d(x*x_mod, (y*y_mod)+cy, freq, depth, seed)
				local r,g,b,a = get_color(val, y/height)
				db:set_pixel(x+ox,y+oy,r,g,b,a)
			end
		end
	end

	local fire_e = gui.new_callback(config)
	fire_e.time = 0
	function fire_e:callback(db,ox,oy)
		draw_noise(db, self.width, self.height, ox,oy,self.time*(config.speed or 60))
	end
	function fire_e:update(dt)
		self.time = self.time + dt
	end
	fire_e.title = "Fire"

	return fire_e

end


local function menu_element(config)

	local elements = {}
	local cy = 0
	local px,py = 50,50
	local function make_launcher(text, callback, _config)
		local button = gui.new_button({
			x = 0,
			y = cy,
			margin = 6,
			width = 150,
			text = text,
			font = config.font,
			on_click = function()
				_config.x = _config.x or px
				_config.y = _config.y or py
				wm:add_window(callback(_config))
				px = px + 20
				py = py + 20
			end
		})
		table.insert(elements, button)
		cy = cy + button.height - 1
		config.height = cy + 1
	end




	make_launcher("Digital Clock", digital_clock_element,	{ width = 140, height = 25, font = font_lg })
	make_launcher("Analog Clock", analog_clock_element,		{ width = 100, height = 100 })
	make_launcher("FPS Display", fps_element,				{ width = 185, height = 80, font_sm = font_sm, font_lg = font_lg })
	make_launcher("ffmpeg webcam", video_element,			{ width = 320, height = 240, title = "Webcam", type="v4l2", device = "/dev/video0" })
	make_launcher("ffmpeg video", video_element,			{ width = 320, height = 240, title = "Video", type="file", file = "/home/max/Downloads/BigBuckBunny_640x360.m4v", seek = 66})
	make_launcher("Tetris", tetris_element,					{ font_lg = font_lg})
	make_launcher("TMT Terminal", tmt_terminal_element,		{ proc = "bash", font = font_sm })
	make_launcher("ROTE Terminal", rote_terminal_element,	{ proc = "bash", font = font_sm })
	make_launcher("Fire", fire_element,						{ width = 75, height = 200})


	config.elements =elements
	local button_group = gui.new_group(config)
	button_group.title = "Buttons test!"
	button_group.min_width = 100

	return button_group
end

-- create window manager
local windows = {
	menu_element({ x = 10, y = 10, width = 150, height = 155, font = font_sm }),
}




wm = window_manager.new_window_group({
	elements = windows,
	x = 0,
	y = 0,
	width = w,
	height = h,
	style = {
		titlebar_font = font_sm
	}
})
windows[1]:focus_self()



function cio:handle_event(ev)
	if ev.type == "quit" then
		self:close()
	elseif (ev.type == "mousemotion") or (ev.type == "mousebuttondown") or (ev.type == "mousebuttonup") then
		gui.handle_mouse_event({wm}, ev.x/scale, ev.y/scale, ev)
		mouse_x = ev.x
		mouse_y = ev.y
	elseif (ev.type == "keydown") or (ev.type == "keyup") then
		gui.handle_key_event({wm}, ev.key, ev)
	end
end

local last = time.realtime()
while true do
	local now = time.realtime()
	dt = now - last
	last = now

	db:clear(0,0,0,255)

	cio:update_input()

	wm:update(dt)

	gui.draw_elements(db, {wm})

	if draw_cursor then
		db:set_line(mouse_x+1, mouse_y+1, mouse_x+1, mouse_y + 19, 255,255,255,255)
		db:set_line(mouse_x+1, mouse_y+3, mouse_x+8, mouse_y + 14, 255,255,255,255)
		db:set_line(mouse_x+1, mouse_y + 19, mouse_x+9, mouse_y + 15, 255,255,255,255)

		db:set_line(mouse_x, mouse_y, mouse_x, mouse_y + 20, 0,0,0,255)
		db:set_line(mouse_x, mouse_y, mouse_x+10, mouse_y + 15, 0,0,0,255)
		db:set_line(mouse_x, mouse_y + 20, mouse_x+10, mouse_y + 15, 0,0,0,255)
	end

	if scale > 1 then
		db:draw_to_drawbuffer(scale_db, 0,0, 0,0, w,h, scale)
		cio:update_output(scale_db)
	else
		cio:update_output(db)
	end
end
