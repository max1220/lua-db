local vector_font = {}


function vector_font.new_vector_font()
	local vec_font = {}
	vec_font.default_radius = 1
	vec_font.glyphs = {}

	-- utillity function to add a character to the character mapping
	function vec_font:add_glyph(char, width,height, lines)
		local glyph = {
			char = char,
			lines = lines,
			width = width,
			height = height
		}
		self.glyphs[char] = glyph
	end

	-- draw the SDF on the drawbuffer.
	-- x0,y0 must be the upper-left corner of a rectangle(-1,-1 in the SDF)
	-- x1,y1 must be the lower-right corner of a rectangle(1,1 in the SDF)
	local function draw_sdf_in_rect(db, sdf, map, x0, y0, x1, y1)
		for dy=y0, y1 do
			for dx=x0, x1 do
				local px = (((dx-x0)/(x1-x0))*2)-1
				local py = (((dy-y0)/(y1-y0))*2)-1
				local d = sdf(px,py)
				local map_r,map_g,map_b,map_a = map(d)
				db:set_px_alphablend(math.floor(dx),math.floor(dy), map_r,map_g,map_b,map_a)
			end
		end
	end

	-- signed distance function for a capsuled line segment.
	-- x,y is the sampled position
	-- ax,ay is the first point of the line segment
	-- bx,by is the second point of the line segment
	-- radius is the radius of the line
	local function line_sdf(x,y, ax, ay, bx, by, radius)
		local pax,pay = x-ax, y-ay
		local bax,bay = bx-ax, by-ay
		local h = math.max(math.min((pax*bax+pay*bay) / (bax*bax+bay*bay), 1), 0)
		local dx,dy = pax-bax*h, pay-bay*h
		return math.sqrt(dx * dx + dy * dy) - radius
	end

	-- signed distance function for a circle.
	-- x,y is the sampled position
	-- radius is the radius of the circle
	--luacheck: no unused
	local function circle_sdf(x,y, radius)
		return math.sqrt(x,y)-radius
	end
	--luacheck: unused

	-- Signed distance function for a list of lines.
	-- x,y is the sampled position
	-- lines is a list of tables containing two points and a radius
	local function lines_sdf(x,y,lines)
		local min_d = math.huge
		for i=1, #lines do
			local cline = lines[i]
			local pa,pb,radius = cline[1],cline[2],cline[3]
			local d = line_sdf(x,y, pa[1],pa[2], pb[1],pb[2], radius)
			min_d = math.min(min_d, d)
		end
		return min_d
	end

	-- mix the two colors according to p(p=0 means col_a, p=1 means col_b)
	local function color_interpolate(col_a, col_b, p)
		local r = (1-p)*col_a[1] + p*col_b[1]
		local g = (1-p)*col_a[2] + p*col_b[2]
		local b = (1-p)*col_a[3] + p*col_b[3]
		local a = (1-p)*col_a[4] + p*col_b[4]
		return r,g,b
	end

	-- get a color of a linear gradient.
	local function linear_gradient_map(d, colors)
		local i = 1+((math.min(math.max(d, -1), 1)+1)/2)*(#colors-1)
		local lo = math.floor(i)
		local hi = math.ceil(i)
		local p = i%1
		local r,g,b = color_interpolate(colors[lo], colors[hi], p)
		return r,g,b,255
	end


	local function fill_map(d,r,g,b)
		local v = math.max(math.min(d*20+17, 1), -1)
		v = math.max(math.floor(v * 255), 0)
		return r,g,b,255-v
	end

	local function outline_map(d,r,g,b)
		local v = math.max(math.min(math.abs(d*20+17), 1), -1)
		v = math.max(math.floor(v * 255), 0)
		return r,g,b,255-v
	end

	function vec_font:draw_glyph_in_rect(db, char, r,g,b, x0, y0, x1, y1)
		local glyph = self.glyphs[char]
		if not glyph then
			return
		end

		local lines = glyph.lines
		local sdf = function(x,y) return lines_sdf(x,y,lines) end
		local map = function(d) return fill_map(d,r,g,b) end
		draw_sdf_in_rect(db, sdf, map, x0, y0, x1, y1)

		return true
	end

	function vec_font:draw_glyph(db, char, r,g,b, x,y,scale)
		local x0 = x-scale*0.5
		local y0 = y-scale*0.5
		local x1 = x+scale*0.5
		local y1 = y+scale*0.5
		self:draw_glyph_in_rect(db, char, r,g,b, x0, y0, x1, y1)
		return x0, y0, x1, y1
	end

	return vec_font
end


return vector_font
