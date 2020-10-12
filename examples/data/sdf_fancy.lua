local ldb = require("lua-db")

return function(w,h)
	local hw,hh = w/2,h/2
	local minhd = math.min(hw,hh)

	local function circle_sdf(x,y,radius)
		return math.sqrt(x*x+y*y)-radius
	end

	local function box_sdf(x,y,bw,bh)
		local dx = math.abs(x)-bw
		local dy = math.abs(y)-bh
		local d = math.sqrt(math.max(dx,0)^2+math.max(dy,0)^2) + math.min(math.max(dx,dy),0.0)
		return d
	end

	local function sdf(x,y,t)
		t=t/10
		local wobble = 0.2*math.sin(t/100)
		local w1 = ((math.sin(3*t+x*wobble)+1)/2)*-1.10
		local w2 = ((math.cos(3*t+y*wobble+2)+1)/2)*1.12

		local rad = ((math.sin(t)+1)/2)*minhd*0.2+minhd*0.1

		--local d1 = circle_sdf(x*w1,y*w2,rad)
		local d1 = box_sdf(x*w1,y*w2,rad,rad)
		local cx = x+math.sin(t)*minhd*0.5
		local d2 = circle_sdf(cx,y,rad*0.5+10)
		--local d2 = box_sdf(cx,y, 10,10)
		--local d2 = circle_sdf(cx,y, 10,10)

		local d3 = box_sdf(x,y,math.abs(w1)*minhd*0.3+minhd*0.1,math.abs(w2)*minhd*0.3+minhd*0.1)

		return math.max(d1,-math.min(d2,d3))
	end

	local function map_outline(d, t)
		t=0
		local r,g,b = 1,1,1
		local inner_border = 2
		local outer_border = minhd*0.2
		if d < 0 then
			return 0,0,0
		elseif d < inner_border then
			local bpct = 1-(d/inner_border)
			r,g,b = r-bpct,g-bpct,b-bpct
		elseif d < outer_border then
			local bpct = 1-((d-inner_border)/outer_border)
			local freq = 8*math.pi
			local v = (math.sin(bpct*freq+t*20)/2)*bpct
			r,g,b = 1-v,1-v,1-v--r-bpct,g-bpct,b-bpct
		end
		r = math.min(math.max(math.floor(r*255),0),255)
		g = math.min(math.max(math.floor(g*255),0),255)
		b = math.min(math.max(math.floor(b*255),0),255)
		return r,g,b
	end

	local function map_shape(d,t)
		local v = 1
		if d<0 then
			v = 0
		elseif d<1 then
			v = d
		end
		local v_byte = math.min(math.max(math.floor(v*255),0),255)
		return v_byte,v_byte,v_byte
	end

	local function map_colors(d, t)
		local r,g,b
		local border = 30
		if d < 0 then
			return 0,0,0
		else
			r = ((math.sin(2.2*t+d*0.4+2.7)+1)/2)*((math.sin(1.2*t+d*0.9+1.1)+1)/2)
			g = (0.6-math.max(0.4,(math.sin(0.1+t-d*0.02+0.9)+1)*4)/2)*math.sin(t)
			b = ((math.sin(-1.3*t*3+d*0.09+0.1)+1)/2)
		end
		if d < border then
			local bpct = d/border
			bpct = math.sin(bpct*4*math.pi)
			r = math.min(r,bpct)
			g = math.min(g,bpct)
			b = math.min(b,bpct)
		end
		r = math.min(math.max(math.floor(r^2.2*255),0),255)
		g = math.min(math.max(math.floor(g^2.2*255),0),255)
		b = math.min(math.max(math.floor(b^2.2*255),0),255)
		return r,g,b
	end

	local function callback(x,y,per_frame)
		local t = per_frame.t
		--local outline = (math.floor(t/10) % 10 == 1)
		local outline = false
		local shape = true
		--local outline = per_frame.outline
		--local shape = per_frame.shape
		local d = sdf(x-hw,y-hh,t)
		local r,g,b
		if outline then
			r,g,b = map_outline(d,t)
		elseif shape then
			r,g,b = map_shape(d,t)
		else
			r,g,b = map_colors(d,t)
		end
		return r,g,b,255
	end

	return callback
end
