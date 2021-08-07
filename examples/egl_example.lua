#!/usr/bin/env luajit
-- no external dependencies
local ldb_core = require("ldb_core")
local ldb_gfx = require("ldb_gfx")
local ldb_bitmap = require("lua-db.bitmap")
local ldb_bmpfont = require("lua-db.bmpfont")
local ldb_egl = require("ldb_egl_debug")
local gettime = require("time").monotonic

local font = ldb_bmpfont.new_bmpfont({
	db = ldb_bitmap.decode_from_file_drawbuffer("./examples/data/8x8_font_max1220_white.bmp"),
	char_w = 8, char_h = 8, char_to_tile = dofile("./examples/data/8x8_font_max1220.lua"),
})

local vertices = {
--  positions      colors          texture coords
     1,  1, 0,     1, 0, 0, 1,     1, 0, -- top right
     1, -1, 0,     0, 1, 0, 1,     1, 1, -- bottom right
    -1, -1, 0,     0, 0, 1, 1,     0, 1, -- bottom left
    -1,  1, 0,     1, 1, 0, 1,     0, 0, -- top left
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
layout (location = 1) in vec4 aColor;
layout (location = 2) in vec2 aTexCoord;

out vec4 ourColor;
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

in vec4 ourColor;
in vec2 TexCoord;

uniform sampler2D ourTexture;

void main() {
    FragColor = texture(ourTexture, TexCoord) * ourColor;
	//FragColor = texture(ourTexture, TexCoord);
}
]]

assert(ldb_egl.init("/dev/dri/card0"))

local width,height = ldb_egl.get_info()
assert(width and height)
print("Got width,height:", width,height)


-- prepare a drawbuffer to be used as a texture
local db = ldb_core.new_drawbuffer(320, 240, "rgb888")
local function update_db()
	db:clear(255,255,255,255)
	local w,h = db:width(), db:height()
	local hw,hh = w/2, h/2
	ldb_gfx.rectangle(db, 0,0, hw, hh, 255,0,255,255)
	ldb_gfx.rectangle(db, hw, hh, hw, hh, 127,0,127,255)
	font:draw_text(db, "Hello World!", 16, 16)
	font:draw_text(db, tostring(os.time()), hw+16, hh+16)
end
update_db()




local program,_err,_err2 = ldb_egl.create_program(vshader, fshader)
assert(program, tostring(_err).." - "..tostring(_err2))
local texture = assert(ldb_egl.create_texture2d_from_db(db))
local VBO, VAO, EBO = assert(ldb_egl.create_vao(vertices, indices))

print("program:", program)
print("texture:", texture)
print("VBO, VAO, EBO", VBO, VAO, EBO)

local function draw()
	ldb_egl.clear(0,0,0,1)

	assert(ldb_egl.bind_texture2d(texture))

	update_db() -- update drawbuffer
	ldb_egl.update_texture2d_from_db(db) -- update texture

	assert(ldb_egl.use_program(program))
	assert(ldb_egl.bind_VAO(VAO))

	ldb_egl.draw_triangles(#indices)
end


local start = gettime()
local iter = 0
local now = start
local last = now

print("Entering main loop...")
while now-start < 5 do
	local dt = now-last

	print(("fps: %7.2f"):format(1/dt))
	assert(ldb_egl.update(draw))

	iter = iter + 1
	last = now
	now = gettime()
end

local elapsed = gettime()-start
print(("%d iterations in %d seconds. (avg. FPS: %d)"):format(iter, elapsed, iter/elapsed))


local new_vertices = {
--  positions      colors          texture coords
	 1,  1, 0,     1, 0, 0, 1,     1, 0, -- top right
	 1, -1, 0,     0, 1, 0, 1,     1, 1, -- bottom right
	-1, -1, 0,     0, 0, 1, 1,     0, 1, -- bottom left
	-1,  1, 0,     1, 1, 0, 1,     0, 0, -- top left
};

start = gettime()
now = start
while now-start < 5 do
	local pct = (now-start)/5

	-- scale down textures slowly
	for i=1, #new_vertices, 9 do
		new_vertices[i] = vertices[i]*(1-pct)
		new_vertices[i+1] = vertices[i+1]*(1-pct)
		new_vertices[i+2] = vertices[i+2]*(1-pct)
	end

	assert(ldb_egl.bind_VBO(VBO))
	assert(ldb_egl.buffer_sub_data(0, false, new_vertices))

	local ok,err = ldb_egl.update(draw)
	assert(ok,err)

	now = gettime()
end

elapsed = gettime()-start
print(("%d iterations in %d seconds. (avg. FPS: %d)"):format(iter, elapsed, iter/elapsed))

ldb_egl.close()
