local function new_tetris(board_w, board_h, spawn_x, tiles, tile_w, tile_h)
	local tiles = tiles or {
		{
			{ 0,0,0,0 },
			{ 0,1,1,0 },
			{ 0,1,1,0 },
			{ 0,0,0,0 },
		},
		{
			{ 0,0,1,0 },
			{ 0,0,1,0 },
			{ 0,0,1,0 },
			{ 0,0,1,0 },
		},
		{
			{ 0,0,1,0 },
			{ 0,1,1,0 },
			{ 0,1,0,0 },
			{ 0,0,0,0 },
		},
		{
			{ 0,1,0,0 },
			{ 0,1,1,0 },
			{ 0,0,1,0 },
			{ 0,0,0,0 },
		},
		{
			{ 0,0,1,0 },
			{ 0,0,1,0 },
			{ 0,1,1,0 },
			{ 0,0,0,0 },
		},
		{
			{ 0,1,0,0 },
			{ 0,1,0,0 },
			{ 0,1,1,0 },
			{ 0,0,0,0 },
		},
	}

	local board_w = board_w or 10
	local board_h = board_h or 16
	local tile_w = tile_w or 4
	local tile_h = tile_h or 4
	local spawn_x = spawn_x or 4

	local tetris = {
		board_w = board_w,
		board_h = board_h,
		tile_w = tile_w,
		tile_h = tile_h,
		spawn_x = spawn_x,
		tiles = tiles
	}

	-- return the tile_id from the board at x,y (return nil if out of range)
	local function _get_at(self,x,y)
		local tile_id = (self.board[y] or {})[x]
		return tile_id
	end

	-- set the tile_id for the board at x,y (Only sets if index is valid)
	local function _set_at(self,x,y,tile_id)
		if _get_at(self,x,y) then
			(self.board[y] or {})[x] = tile_id
		end
	end

	-- Rotate the tile right(transpose and mirror x axis)
	local function _rotate_tile_right(tile)
		local new_tile = {}
		for cy=1, tile_h do
			new_tile[cy] = {}
			for cx=1, tile_w do
				new_tile[cy][cx] = tile[cx][5-cy]
			end
		end
		return new_tile
	end

	-- Rotate to the specified rotation by rotating right multiple times
	local function _rotate_tile(tile, r)
		local new_tile = tile
		for i=1, r do
			new_tile = _rotate_tile_right(new_tile)
		end
		return new_tile
	end

	-- return a new line empty
	local function _new_line()
		local t = {}
		for i=1, board_w do
			t[i] = 0
		end
		return t
	end

	-- remove the line at y from the table, insert a _new_line() at the top
	local function _remove_line(t, y)
		table.remove(t, y)
		table.insert(t, 1, _new_line())
	end

	-- chech if the tile starting at x,y with the rotation r would collide with the walls or a block
	function tetris:check_tile_at(x,y,r)
		local r = r or self.r
		local tile = _rotate_tile(tiles[self.tile_id], r)
		for cy=0, tile_h-1 do
			for cx=0, tile_w-1 do
				if tile[cy+1][cx+1] ~= 0 then
					local board_tile_id = _get_at(self, x+cx, y+cy)
					if board_tile_id~=0 then
						return false
					end
				end
			end
		end
		return true
	end

	-- reset the game state
	function tetris:reset()
		self.tile_id = math.random(1, #tiles)
		self.next_tile_id = math.random(1, #tiles)
		self.cx = spawn_x
		self.cy = 1
		self.r = 0
		self.score = 0
		self.down_time = 0
		self.down_timeout = 2
		self.board = {}

		-- the board needs to be prefilled, because this determines the valid indexes
		for y=1, board_h do
			self.board[y] = {}
			for x=1, board_w do
				self.board[y][x] = 0
			end
		end
	end

	-- Check if the current tile needs to be dropped
	function tetris:update_timer(dt)
		self.down_time = self.down_time + dt
		if self.down_time >= self.down_timeout then
			self:down()
			self.down_time = 0
			return true
		end
	end

	-- After a tile was dropped, get the next tile, and reset the position/rotation,
	-- then check if the tile fits on the board, if not calls :gameover()
	function tetris:next_tile()
		self.tile_id = self.next_tile_id
		self.next_tile_id = math.random(1, #tiles)
		self.cx = spawn_x
		self.cy = 1
		self.r = 0
		if (not self:check_tile_at(self.cx, self.cy)) and self.gameover then
			self:gameover()
		end
	end

	-- check the board for complete lines, remove old lines, calculate new score and down_timeout
	function tetris:check_complete_lines()
		local i = 0
		for y=1, board_h do
			local complete = true
			for x=1, board_w do
				if self.board[y][x] == 0 then
					complete = false
				end
			end
			if complete then
				i = i + 1
				_remove_line(self.board, y)
			end
		end
		local add = ({[0]=0, 100, 300, 500, 800})[i]
		self.score = self.score + add
		if add > 0 then
			self.down_timeout = self.down_timeout * 0.98
		end
	end

	-- when a tile collides with a block, the tile is converted to a set of blocks on the board
	function tetris:set_tile_at(x,y)
		local tile = _rotate_tile(tiles[self.tile_id], self.r)
		for cy=0, tile_h-1 do
			for cx=0, tile_w-1 do
				if tile[cy+1][cx+1] ~= 0 then
					_set_at(self, x+cx, y+cy, self.tile_id)
				end
			end
		end
	end

	-- move the tile left
	function tetris:left()
		if self:check_tile_at(self.cx-1, self.cy) then
			self.cx = self.cx - 1
		end
	end

	-- move the tile right
	function tetris:right()
		if self:check_tile_at(self.cx+1, self.cy) then
			self.cx = self.cx + 1
		end
	end

	-- rotate the tile left
	function tetris:rotate_left()
		local nr = (self.r - 1) % 4
		if self:check_tile_at(self.cx, self.cy, nr) then
			self.r = nr
		end
	end

	-- rotate the tile right
	function tetris:rotate_right()
		local nr = (self.r + 1) % 4
		if self:check_tile_at(self.cx, self.cy, nr) then
			self.r = nr
		end
	end

	-- move the tile down by 1, convert it to blocks if it collides with blocks
	function tetris:down()
		if self:check_tile_at(self.cx, self.cy+1) then
			self.cy = self.cy + 1
			return true
		else
			self:set_tile_at(self.cx, self.cy)
			self:check_complete_lines()
			self:next_tile()
		end
	end

	-- draw the board to a drawbuffer
	function tetris:draw_board_to_db(db, s, ox, oy, colors)
		for y=0, board_h-1 do
			for x=0, board_w-1 do
				local tile_id = _get_at(self, x+1,y+1)
				if tile_id ~= 0 then
					local r,g,b,a = unpack(colors[tile_id])
					db:set_rectangle(ox+x*s, oy+y*s, s,s, r,g,b,a)
				end
			end
		end
		local tile = _rotate_tile(tiles[self.tile_id], self.r)
		for y=1, tile_h do
			for x=1, tile_w do
				local r,g,b,a = unpack(colors[self.tile_id])
				local sx = ox+(self.cx+x-2)*s
				local sy = oy+(self.cy+y-2)*s
				if tile[y][x] ~= 0 then
					db:set_rectangle(sx,sy, s,s, r,g,b,a)
				end
			end
		end

	end

	return tetris
end


local function run()
	local ldb = require("lua-db")
	local getch = require("lua-getch")
	local time = require("time")
	local s = 4
	local braile = true
	local tetris = new_tetris()
	tetris:reset()
	local db = ldb.new(tetris.board_w*s, tetris.board_h*s)
	db:clear(0,0,0,0)
	function tetris:gameover()
		print("Game Over! Final score: "..self.score)
		print("Press enter to play again!")
		io.read("*l")
		self:reset()
	end
	local down_timeout = 2
	local down_time = 0
	local redraw = true
	local last = time.realtime()

	local colors = {
		{255,0,0, 255},
		{0,255,0, 255},
		{0,0,255, 255},
		{255,255,0, 255},
		{0,255,255, 255},
		{255,0,255, 255}
	}

	local function draw()
		db:clear(0,0,0,0)
		tetris:draw_board_to_db(db, s, 0, 0, colors)
		io.write(ldb.term.set_cursor(0,0))
		if braile then
			io.write("|"..table.concat(ldb.braile.draw_db_precise(db, 0, true), "\027[0m|\n|") .. "\027[0m|\n")
		else
			io.write("|"..table.concat(ldb.blocks.draw_db(db, 0, true), "\027[0m|\n|") .. "\027[0m|\n")
		end
		print("Score: "..tetris.score.."   ")
		print("                          ")
	end

	while true do
		local dt = time.realtime() - last
		last = time.realtime()
		local key_code, key_resolved = getch.get_key_mbs(getch.non_blocking)
		if key_resolved == "left" then
			tetris:left()
			redraw = true
		elseif key_resolved == "right" then
			tetris:right()
			redraw = true
		elseif key_resolved == "down" then
			tetris:down()
			redraw = true
		elseif key_resolved == "up" then
			tetris:rotate_right()
			redraw = true
		end
		if tetris:update_timer(dt) then
			redraw = true
		end
		if redraw then
			draw()
			redraw = false
		else
			time.sleep(0.05)
		end
	end
end



return {
	new_tetris = new_tetris,
	run = run
}
