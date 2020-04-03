#!/usr/bin/env luajit
local ldb = require("lua-db")
local time = require("time")

math.randomseed(time.realtime()*1000)
local max_particle_id = 7
local particle_count = 1000

local function generate_particle_types()
	local particle_types = {}
	for i=1, max_particle_id do
		particle_types[i] = {
			color = {math.random(32,255),math.random(32,255),math.random(32,255)},
			--max_radius = math.random()*0.2,
			--min_radius = 0.05 + math.random()*0.15,
			max_radius = math.random()*0.3,
			min_radius = 0.1 + math.random()*0.18,
		}
	end
	return particle_types
end

local function generate_particle(particle_types)
	local particle = {}

	particle.x = math.random()*2-1
	particle.y = math.random()*2-1
	particle.vx = math.random()*2-1
	particle.vy = math.random()*2-1
	local id = math.random(1,max_particle_id)
	particle.id = id
	particle.max_radius = particle_types[id].max_radius
	particle.min_radius = particle_types[id].min_radius
	particle.color = particle_types[id].color

	local factors = {}
	for i=1, max_particle_id do
		factors[i] = math.random()*2-1
	end
	particle.factors = factors

	return particle
end

local function generate_particles(particle_types, count)
	local particles = {}

	for i=1, count do
		particles[i] = generate_particle(particle_types)
	end

	return particles
end

local function particles_interact(dt, particle_a, particle_b, rec)
	local dx = particle_b.x - particle_a.x
	local dy = particle_b.y - particle_a.y
	local d = math.sqrt(dx*dx+dy*dy)
	local rd = (d - particle_a.min_radius) / particle_a.max_radius
	local f = particle_a.factors[particle_b.id]

	if d > particle_a.max_radius then

	elseif d < particle_a.min_radius then
		--particle_a.vx = particle_a.vx + -dx*(-rd)*dt
		--particle_a.vy = particle_a.vy + -dy*(-rd)*dt
		particle_a.vx = particle_a.vx + -dx*f*dt
		particle_a.vy = particle_a.vy + -dy*f*dt
	else
		--particle_a.vx = particle_a.vx + dx*(1-rd)*dt
		--particle_a.vy = particle_a.vy + dy*(1-rd)*dt
		particle_a.vx = particle_a.vx + dx*f*rd*dt
		particle_a.vy = particle_a.vy + dy*f*rd*dt
	end
end

local function step(dt, particles, bound)
	local len = #particles

	for i=1,len do
		local particle_a = particles[i]
		for j=1, len do
			local particle_b = particles[j]
			if particle_a ~= particle_b then
				particles_interact(dt, particle_a, particle_b)
			end
		end

		local friction = 1
		particle_a.vx = particle_a.vx * (1-friction*dt)
		particle_a.vy = particle_a.vy * (1-friction*dt)
		particle_a.x = particle_a.x + particle_a.vx*dt
		particle_a.y = particle_a.y + particle_a.vy*dt

		if bound then
			if particle_a.x > 1 then
				particle_a.x = -1
			elseif particle_a.x < -1 then
				particle_a.x = 1
			end
			if particle_a.y > 1 then
				particle_a.y = -1
			elseif particle_a.y < -1 then
				particle_a.y = 1
			end
		end
	end
end


local hw,hh
local function draw(db, particles, ox, oy, scale)
	local len = #particles
	for i=1, len do
		local particle = particles[i]
		local sx = math.floor(particle.x * scale * hw + ox)+hw
		local sy = math.floor(particle.y * scale * hh + oy)+hh
		if not ((sx < 0) or (sy < 0) or (sx > hw*2) or (sy > hh*2)) then
			local color = particle.color
			db:set_pixel(sx, sy, color[1], color[2], color[3], 255)
			db:set_pixel(sx+1, sy, color[1], color[2], color[3], 255)
			db:set_pixel(sx, sy+1, color[1], color[2], color[3], 255)
			db:set_pixel(sx-1, sy, color[1], color[2], color[3], 255)
			db:set_pixel(sx, sy-1, color[1], color[2], color[3], 255)
		end
	end
end



local particle_types = generate_particle_types()
local particles = generate_particles(particle_types, particle_count)

local cio = ldb.input_output.new_sdl({
	width = 1000,
	height = 800,
	title = "Particle Example"
})
cio:init()
local db = ldb.new(cio:get_native_size())
hw,hh = db:width()/2, db:height()/2
local mx, my
local sim_speed = 1
local ox, oy = 0,0
local nox,noy = 0,0
local scale = 1
local fps_limit = 30
local dt_avg = 1/fps_limit
local clear = true
local pause = false
local bound = true
function cio:handle_event(ev)
	if ev.type == "mousebuttondown" then
		if ev.button == 1 then
			mx,my = ev.x,ev.y
		elseif ev.button == 3 then
			db:clear(0,0,0,0)
			particle_types = generate_particle_types()
			particles = generate_particles(particle_types, particle_count)
		end
	elseif ev.type == "mousewheel" then
		--sim_speed = sim_speed * (1+(ev.y*0.1))
		--print("sim_speed", sim_speed)
		local d = (1+(ev.y*0.1))
		scale = scale * d
		ox = ox * d
		oy = oy * d
		print("scale", scale)
	elseif ev.type == "mousebuttonup" then
		if ev.button == 1 then
			mx,my = nil,nil
			ox = ox + nox
			oy = oy + noy
			nox = 0
			noy = 0
		end
	elseif ev.type == "mousemotion" then
		if mx then
			nox = -(mx-ev.x)
			noy = -(my-ev.y)
		end
	elseif ev.type == "keyup" then
		if ev.key == "Left" then
			sim_speed = sim_speed * 0.9
			print("sim_speed", sim_speed)
		elseif ev.key == "Right" then
			sim_speed = sim_speed * 1.1
			print("sim_speed", sim_speed)
		elseif ev.key == "P" then
			pause = not pause
			print("pause", pause)
		elseif ev.key == "B" then
			bound = not bound
			print("bound", bound)
		elseif ev.key == "C" then
			db:clear(0,0,0,0)
			print("clear")
		elseif ev.key == "V" then
			if clear then
				clear = false
			else
				clear = true
			end
		end
	end

end
local last = time.realtime()
while true do
	local now = time.realtime()
	local dt = now - last
	last = now
	
	dt_avg = dt*0.1 + dt_avg*0.9
	
	if fps_limit then
		if (1/(fps_limit)) > dt_avg then
			time.sleep((1/fps_limit)-dt_avg)
		end
	end
	
	--print(("fps:  %6.2f (avg: %6.2f)"):format(1/dt, 1/dt_avg))

	if clear then
		db:clear(12,12,12,255)
	end
	draw(db, particles, ox+nox,oy+noy, scale)
	cio:update_input()
	cio:update_output(db)
	if not pause then
		local dt = 0.03
		step(dt*sim_speed, particles, bound)
	end
end
