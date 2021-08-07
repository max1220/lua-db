#!/usr/bin/env luajit
-- no external dependencies
local ldb_core = require("ldb_core")
local ldb_gfx = require("ldb_gfx")
local ldb_egl = require("ldb_egl_debug")
local gettime = require("time").monotonic



local function create_gui_renderer()
	local gui_renderer = {}

	gui_renderer.vshader = [[
		#version 300 es

		precision highp float;
		precision highp int;
		precision lowp sampler2D;
		precision lowp samplerCube;

		layout (location = 0) in vec3 aPos;
		layout (location = 1) in vec4 aColor;
		layout (location = 2) in vec2 aTexCoord;

		uniform float view_width;
		uniform float view_height;
		uniform float time;

		out vec4 ourColor;
		out vec2 TexCoord;

		void main() {
			// aPos is in screen coordinates, normalize to [-1,1], flip y-axis
			vec4 nPos = vec4(aPos, 1.0);
			nPos.x = (nPos.x/view_width);
			nPos.y = (nPos.y/view_height);
			nPos.x = nPos.x*2.0-1.0;
			nPos.y = nPos.y*2.0-1.0;
			nPos.y *= -1.0;


		    gl_Position = nPos;

		    ourColor = aColor;
		    TexCoord = aTexCoord;
		}
	]]
	gui_renderer.fshader = [[
		#version 300 es

		precision highp float;
		precision highp int;
		precision lowp sampler2D;
		precision lowp samplerCube;

		uniform float view_width;
		uniform float view_height;
		uniform float time;

		out vec4 FragColor;

		in vec4 ourColor;
		in vec2 TexCoord;

		uniform sampler2D ourTexture;

		void main() {
		    //FragColor = texture(ourTexture, TexCoord) * ourColor;
			//FragColor = texture(ourTexture, TexCoord);
			vec4 col = ourColor;
			col *= clamp(abs(sin(time))+0.2, 0.0, 1.0);
			FragColor = col;
		}
	]]

	gui_renderer.vertice_data = {}
	gui_renderer.index_data = {}

	gui_renderer.elements = {
		{
			type = "rect",
			x = 100,
			y = 100,
			w = 100,
			h = 100,
			color = {1,0,0,1}
		},
		{
			type = "rect",
			x = 300,
			y = 100,
			w = 100,
			h = 100,
			color = {0,1,0,1}
		},
		{
			type = "rect",
			x = 100,
			y = 300,
			w = 100,
			h = 100,
			color = {0,0,1,1}
		}
	}

	-- vertex/index data for a circle(creating a "fan" manually)
	local function add_circle(vertice_data, vertice_offset, index_data, index_offset, center_x,center_y, radius, steps, r,g,b,a)
		r,g,b,a = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1

		-- add vertex data for center position
		local center_vert_i = vertice_offset
		vertice_data[vertice_offset+1] = center_x -- position
		vertice_data[vertice_offset+2] = center_y
		vertice_data[vertice_offset+3] = 0
		vertice_data[vertice_offset+4] = r -- center color
		vertice_data[vertice_offset+5] = g
		vertice_data[vertice_offset+6] = b
		vertice_data[vertice_offset+7] = a
		vertice_data[vertice_offset+8] = 0 -- texture coords
		vertice_data[vertice_offset+9] = 0

		vertice_offset = vertice_offset + 9

		-- add vertex data for initial/end position
		local initial_vert_i = vertice_offset
		vertice_data[vertice_offset+1] = center_x -- position
		vertice_data[vertice_offset+2] = center_y-radius
		vertice_data[vertice_offset+3] = 0
		vertice_data[vertice_offset+4] = r -- "ring" color
		vertice_data[vertice_offset+5] = g
		vertice_data[vertice_offset+6] = b
		vertice_data[vertice_offset+7] = a
		vertice_data[vertice_offset+8] = 0 -- texture coords
		vertice_data[vertice_offset+9] = 0

		vertice_offset = vertice_offset + 9

		for i=1, #steps-2 do
			local angle = i/(steps-1)
			local x = center_x+math.cos(angle)*radius
			local y = center_y+math.sin(angle)*radius
			vertice_data[vertice_offset+i+1] = x -- position
			vertice_data[vertice_offset+i+2] = y
			vertice_data[vertice_offset+i+3] = 0
			vertice_data[vertice_offset+i+4] = r -- "ring" color
			vertice_data[vertice_offset+i+5] = g
			vertice_data[vertice_offset+i+6] = b
			vertice_data[vertice_offset+i+7] = a
			vertice_data[vertice_offset+i+8] = 0 -- texture coords
			vertice_data[vertice_offset+i+9] = 0
		end

		local last = initial_vert_i
		for i=1, #steps-2 do
			index_data[index_offset+i] = center_vert_i
			index_data[index_offset+i] = last
			index_data[index_offset+i] = initial_vert_i+i+1
			last = initial_vert_i+i+1
		end

		return vertice_offset+steps
	end

	local function add_rect(vertice_data, vertice_offset, index_data, index_offset, x,y, w,h, r,g,b,a)
		r,g,b,a = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, tonumber(a) or 1
		local rect_vertices = {
		--  positions        colors          texture coords
		    x+w,   y, 0,     r, g, b, a,     1, 0, -- top right
		    x+w, y+h, 0,     r, g, b, a,     1, 1, -- bottom right
		      x, y+h, 0,     r, g, b, a,     0, 1, -- bottom left
		      x,   y, 0,     r, g, b, a,     0, 0, -- top left
		}
		for i=0, #rect_vertices-1 do
			vertice_data[vertice_offset+i+1] = rect_vertices[i+1]
		end

		local rect_indices = {
		    0, 1, 3, -- first triangle
		    1, 2, 3, -- second triangle
		}
		for i=0, #rect_indices-1 do
			index_data[index_offset+i+1] = (vertice_offset/9)+rect_indices[i+1]
		end

		return vertice_offset+#rect_vertices, index_offset+#rect_indices
	end

	local function elements_to_data(elements)
		local vertice_data = {}
		local vertice_offset = 0
		local index_data = {}
		local index_offset = 0
		local default_color = {1,0,1,1}
		for i=1, #elements do
			local element = elements[i]
			if element.type == "rect" then
				local color = element.color or default_color
				vertice_offset,index_offset = add_rect(
					vertice_data, vertice_offset,
					index_data, index_offset,
					element.x, element.y,
					element.w, element.h,
					color[1],
					color[2],
					color[3],
					color[4]
				)
			end
		end
		return vertice_data, index_data
	end



	function gui_renderer:update_data()
		local vertice_data, index_data = elements_to_data(self.elements)
		self.vertice_data = vertice_data
		self.index_data = index_data
	end

	function gui_renderer:update_buffers()
		assert(ldb_egl.bind_VBO(self.VBO))
		assert(ldb_egl.buffer_sub_data(0, false, assert(self.vertice_data)))

		assert(ldb_egl.bind_VBO(self.EBO))
		assert(ldb_egl.buffer_sub_data(0, true, assert(self.index_data)))
	end

	function gui_renderer:update()
		self:update_data()
		self:update_buffers()

	end

	function gui_renderer:draw()
		-- assert(card:bind_texture2d(self.texture))
		local ok,err,err2 = ldb_egl.use_program(assert(self.program))
		local width,height = assert(ldb_egl.get_info())
		assert(ldb_egl.set_uniform_f("view_width", self.program, width))
		assert(ldb_egl.set_uniform_f("view_height", self.program, height))
		assert(ldb_egl.set_uniform_f("time", self.program, gettime()))
		assert(ok, tostring(err)..tostring(err2))
		assert(ldb_egl.bind_VAO(assert(self.VAO)))

		ldb_egl.draw_triangles(#assert(self.index_data))
	end

	function gui_renderer:init()
		local program,_err,_err2 = ldb_egl.create_program(self.vshader, self.fshader)
		self.program = assert(program, tostring(_err).." - "..tostring(_err2))
		-- self.texture = assert(card:create_texture2d_from_db(db))

		self:update_data()

		local VBO, VAO, EBO = ldb_egl.create_vao(1024,1024)
		assert(VBO and VAO and EBO)
		self.VBO = VBO
		self.VAO = VAO
		self.EBO = EBO

		self:update_buffers()
	end


	return gui_renderer
end



assert(ldb_egl.init("/dev/dri/card0"))

local width,height = ldb_egl:get_info()
print("Got width,height:", width,height)

local gr = create_gui_renderer()
gr:init()


local start = gettime()
local iter, now, last = 0, start, start
local function draw()
	-- draw background
	ldb_egl:clear(0,0,0,1)

	-- draw gui elements
	gr:draw()
end

print("Entering main loop...")
local run = true
print()
while run do
	local dt = now-last

	if iter%10==0 then
		io.write(("\rfps: %7.2f  "):format(1/dt))
		io.flush()
	end
	assert(ldb_egl.update(draw))

	iter = iter + 1
	last = now
	now = gettime()
end

local elapsed = gettime()-start
print(("%d iterations in %d seconds. (avg. FPS: %d)"):format(iter, elapsed, iter/elapsed))

ldb_egl.close()
