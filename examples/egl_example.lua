#!/usr/bin/env luajit
-- no external dependencies
local ldb_core = require("ldb_core")
local ldb_gfx = require("ldb_gfx")
local ldb_bitmap = require("lua-db.bitmap")
local ldb_bmpfont = require("lua-db.bmpfont")
local ldb_egl = require("ldb_egl")
local time = require("time")

local function gettime()
	return time.monotonic()
end

local card = ldb_egl.new_card("/dev/dri/card0")

local font_db = ldb_bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp")
local font = ldb_bmpfont.new_bmpfont({
	db = font_db,
	char_w = 8,
	char_h = 8,
	char_to_tile = dofile("./examples/data/8x8_font_max1220.lua"),
})


local width,height = card:get_info()
print("Got width,height:", width,height)


local vertices = {
--  positions      colors       texture coords
     1,  1, 0,     1, 0, 0,     1, 0, -- top right
     1, -1, 0,     0, 1, 0,     1, 1, -- bottom right
    -1, -1, 0,     0, 0, 1,     0, 1, -- bottom left
    -1,  1, 0,     1, 1, 0,     0, 0, -- top left
};
local indices = {
    0, 1, 3, -- first triangle
    1, 2, 3,  -- second triangle
};

local vshader = [[
#version 300 es

precision highp float;
precision highp int;
precision lowp sampler2D;
precision lowp samplerCube;

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;

out vec3 ourColor;
out vec2 TexCoord;

void main() {
    gl_Position = vec4(aPos, 1.0);
    ourColor = aColor;
    TexCoord = aTexCoord;
}
]]
local fshader = [[
#version 300 es

precision highp float;
precision highp int;
precision lowp sampler2D;
precision lowp samplerCube;

out vec4 FragColor;

in vec3 ourColor;
in vec2 TexCoord;

uniform sampler2D ourTexture;

void main() {
    //FragColor = texture(ourTexture, TexCoord) * vec4(ourColor, 1.0);
	FragColor = texture(ourTexture, TexCoord);
}
]]


local start = gettime()
local iter = 0
local now = start
local last = now
local db = ldb_core.new_drawbuffer(256, 256, "rgb888")
db:clear(255,255,255,255)
ldb_gfx.rectangle(db, 0,0, 128, 128, 255,0,255,255)
ldb_gfx.rectangle(db, 128,128, 128, 128, 127,0,127,255)
font:draw_text(db, "Hello World!", 16, 16)

local program,_err,_err2 = card:create_program(vshader, fshader)
assert(program, tostring(_err).." - "..tostring(_err2))
local texture = assert(card:create_texture2d_from_db(db))
local VBO, VAO, EBO = assert(card:create_vao(vertices, indices))

print("program:", program)
print("texture:", texture)
print("VBO, VAO, EBO", VBO, VAO, EBO)

local function draw()
	card:clear(0,0,0,1)

	assert(card:bind_texture2d(texture))
	assert(card:use_program(program))
	assert(card:bind_VAO(VAO))

	card:draw_triangles(6)
end

print("Entering main loop...")
while now-start < 30 do
	local dt = now-last

	print("fps:", 1/dt)
	assert(card:update(draw))

	iter = iter + 1
	last = now
	now = gettime()
end

local elapsed = gettime()-start
print(("%d iterations in %d seconds. (avg. FPS: %d)"):format(iter, elapsed, iter/elapsed))
print("Bye!")
card:close()
