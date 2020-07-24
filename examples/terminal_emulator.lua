#!/usr/bin/env luajit
local ldb = require("lua-db")

local char_w = 8
local char_h = 8
local term_w = 20
local term_h = 20

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = char_w*term_w,
	sdl_height = char_h*term_h,
	limit_fps = 30
}, arg)
cio:init()

-- create drawbuffer of native display size
local w,h = cio:get_native_size()
local db = ldb.new_drawbuffer(w,h)
db:clear(0,0,0,255)
cio.target_db = db

-- create a terminal buffer
local term = ldb.terminal_buffer.new()
term:init(term_w, term_h)

-- load bitmap to drawbuffer
-- TODO: Better path handling for examples
local img_db = ldb.bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")

-- load the mapping of characters to tile-ids
local char_to_tile = dofile("./examples/data/8x8_font_max1220.lua")

local terminal_colors = {
	fg = {
		default = {255,255,255},
		{255,  0,  0}, -- red
		{  0,255,  0}, -- green
		{255,255,  0}, -- yellow
		{  0,  0,255}, -- blue
		{255,  0,255}, -- pink
		{  0,255,255}, -- cyan<
		{255,255,255}, -- white
		{  0,  0,  0}, -- black
	},
	bg = {
		default = {0,0,0},
		{192,  0,  0}, -- red
		{  0,192,  0}, -- green
		{192,192,  0}, -- yellow
		{  0,  0,192}, -- blue
		{192,  0,192}, -- pink
		{  0,192,192}, -- cyan<
		{192,192,192}, -- white
		{  0,  0,  0}, -- black
	},
}

-- create the fonts
local fonts = {}
for i, fg_color in pairs(terminal_colors.fg) do
	local r,g,b = unpack(fg_color)
	fonts[i] = ldb.bmpfont.new_bmpfont({
		db = img_db,
		char_w = char_w,
		char_h = char_h,
		scale_x = 1,
		scale_y = 1,
		char_to_tile = char_to_tile,
		color = {r,g,b}
	})
end

-- TODO: Input from PTY/keyboard
-- TODO: if line lenght fits perfectly, and last char is \n don't generate double newlines
local data = table.concat({
	"Hello World!\n",
	"This is a simple\n",
	"terminal emulator in\n",
	"pure Lua. It behaves\n",
	"ANSI-like. WIP.\n",
	"<------------------>\n",
	"\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n",
	"<------------------>\n",
	"Foo!\n",
	"\027[31mBar!\027[0m\n",
	"\027[41mBuzz!\027[0m\n",
	"Clearing..........\n\027c"
})


-- loop over the input data
local byte_per_second = 10 -- simulate typing speed. actual value is min(fps, bps)
local elapsed = 0
local last_i = 0
function cio:on_update(dt)
	db:clear(0,0,0,255)

	elapsed = elapsed + dt*byte_per_second
	local i = math.floor(elapsed%#data)+1
	if (i~=last_i) then
		last_i = i
		local b = data:sub(i,i)
		term:write(b)
	end

	for y=1, term.h do
		for x=1, term.w do
			local char = term.buffer[y][x]
			local xpos = (x-1)*char_w
			local ypos = (y-1)*char_h
			local bg = terminal_colors.bg[char.bg or "default"]
			db:rectangle(xpos, ypos, 8, 8, bg[1],bg[2],bg[3],255)
			if char.char ~= " " then
				local font = fonts[char.fg or "default"]
				font:draw_character(db, char.char, xpos,ypos)
			end
		end
	end
	local cur_x = (term.cursor_x-1)*char_w
	local cur_y = (term.cursor_y-1)*char_h
	local fg = terminal_colors.fg[term.fg] or terminal_colors.fg.default
	db:rectangle(cur_x, cur_y+6, 8, 2, fg[1],fg[2],fg[3],255)
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
