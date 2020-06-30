#!/usr/bin/env luajit
local ldb = require("lua-db")

local vector_font = require("lua-db.vecfont")
--luacheck: no unused

-- create input and output handler for application
local cio = ldb.input_output.new_from_args({
	default_mode = "sdl",
	sdl_width = 800,
	sdl_height = 600,
	output_scale_x = 1,
	output_scale_y = 1,
	sdl_title = "Vector font test",
	limit_fps = 10,
}, arg)
cio:init()

local vecfont = vector_font.new_vector_font()

-- vecfont.default_radius = 0.05

-- pre-generate points for font
local p = {}
local max_x,max_y = 5,5
for y=0,max_y-1 do
	for x=0,max_x-1 do
		local px = (x/(max_x-1))*1.6-0.8
		local py = (y/(max_y-1))*1.6-0.8
		p[x+1] = p[x+1] or {}
		p[x+1][y+1] = { px, py }
	end
end

vecfont:add_glyph("H", 3,5, {
	{p[1][1], p[1][5], 1}, -- left |
	{p[5][1], p[5][5], 1}, -- right |
	{p[1][3], p[5][3], 1}, -- center -
})

vecfont:add_glyph("E", 3,5, {
	{p[1][1], p[1][5], 1}, -- left |
	{p[1][1], p[5][1], 1}, -- top -
	{p[1][3], p[5][3], 1}, -- center -
	{p[1][5], p[5][5], 1}, -- bottom -
})

vecfont:add_glyph("L", 3,5, {
	{p[1][1], p[1][5], 1}, -- left |
	{p[1][5], p[5][5], 1}, -- bottom -
})

vecfont:add_glyph("O", 3,5, {
	{p[1][1], p[1][5], 1}, -- left |
	{p[5][1], p[5][5], 1}, -- right |
	{p[1][1], p[5][1], 1}, -- top -
	{p[1][5], p[5][5], 1}, -- bottom -
})



local t = 1
function cio:on_update(dt)
	t = t + 1
end

function cio:on_draw(target_db)
	local w,h = self.target_width,self.target_height
	local scale = (math.sin(t/10)+1)*math.min(w,h)*0.05 + math.min(w,h)*0.05
	local text_hw = (scale*5)/2
	local text_start = w*0.5-text_hw
	target_db:clear(12,12,12,255)
	--vecfont:draw_glyph_in_rect(target_db, "H", 255,255,255, 0,0, target_db:width(), target_db:height())

	vecfont:draw_glyph(target_db, "H", 255,0,0, text_start,h/2, scale)
	vecfont:draw_glyph(target_db, "E", 0,255,0, text_start+scale,h/2, scale)
	vecfont:draw_glyph(target_db, "L", 0,0,255, text_start+scale*2,h/2, scale)
	vecfont:draw_glyph(target_db, "L", 255,255,0, text_start+scale*3,h/2, scale)
	vecfont:draw_glyph(target_db, "O", 0,255,255, text_start+scale*4,h/2, scale)
end

function cio:on_close()
	self.run = false
end

cio.run = true
while cio.run do
	cio:update()
end
