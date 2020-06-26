local function new_tetris()
	local tiles = {
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

	local tetris = {
		gameover = true,
		board_w = 10,
		board_h = 16,
		tile_w = 4,
		tile_h = 4,
		spawn_x = 4,
		tiles = tiles,
	}

	-- return the tile_id from the board at x,y (return nil if out of range)
	function tetris:get_at(x,y)
		if (x<1) or (x>self.board_w) or (y<1) or (y>self.board_h) then
			return
		end
		return self.board[y][x]
	end

	-- set the tile_id for the board at x,y (Only sets if index is valid)
	function tetris:set_at(x,y, tile_id)
		if (x<1) or (x>self.board_w) or (y<1) or (y>self.board_h) then
			return
		end
		self.board[y][x] = tile_id
	end

	-- Rotate the tile right(transpose and mirror x axis)
	function tetris:rotate_tile_right(tile)
		local new_tile = {}
		for cy=1, self.tile_h do
			new_tile[cy] = {}
			for cx=1, self.tile_w do
				new_tile[cy][cx] = tile[cx][5-cy]
			end
		end
		return new_tile
	end

	-- Rotate to the specified rotation by rotating right multiple times
	function tetris:rotate_tile(tile, r)
		local new_tile = tile
		for _=1, r do
			new_tile = self:rotate_tile_right(new_tile)
		end
		return new_tile
	end

	-- return a new line empty
	function tetris:new_line()
		local t = {}
		for i=1, self.board_w do
			t[i] = 0
		end
		return t
	end

	-- remove the line at y from the table, insert a _new_line() at the top
	function tetris:remove_line(y)
		table.remove(self.board, y)
		table.insert(self.board, 1, self:new_line())
	end

	-- chech if the tile starting at x,y with the rotation r would collide with the walls or a block
	function tetris:check_tile_at(x,y,_r)
		local r = _r or self.r
		local tile = self:rotate_tile(tiles[self.tile_id], r)
		for cy=0, self.tile_h-1 do
			for cx=0, self.tile_w-1 do
				if tile[cy+1][cx+1] ~= 0 then
					local board_tile_id = self:get_at(x+cx, y+cy)
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
		self.cx = self.spawn_x
		self.cy = 1
		self.r = 0
		self.score = 0
		self.down_time = 0
		self.down_timeout = 2
		self.gameover = false
		self.board = {}

		-- the board needs to be prefilled, because this determines the valid indexes
		for y=1, self.board_h do
			self.board[y] = {}
			for x=1, self.board_w do
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
	-- then check if the tile fits on the board, if not calls :gameover_cb()
	function tetris:next_tile()
		self.tile_id = self.next_tile_id
		self.next_tile_id = math.random(1, #tiles)
		self.cx = self.spawn_x
		self.cy = 1
		self.r = 0
		if not self:check_tile_at(self.cx, self.cy) then
			self.gameover = true
			if self.gameover_cb then
				self:gameover_cb()
			end
		end
	end

	-- check the board for complete lines, remove old lines, calculate new score and down_timeout
	function tetris:check_complete_lines()
		local i = 0
		for y=1, self.board_h do
			local complete = true
			for x=1, self.board_w do
				if self.board[y][x] == 0 then
					complete = false
				end
			end
			if complete then
				i = i + 1
				self:remove_line(y)
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
		local tile = self:rotate_tile(tiles[self.tile_id], self.r)
		for cy=0, self.tile_h-1 do
			for cx=0, self.tile_w-1 do
				if tile[cy+1][cx+1] ~= 0 then
					self:set_at(x+cx, y+cy, self.tile_id)
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

	-- move the current tile down until it collides
	function tetris:drop()
		while self:down() do
		end
	end

	return tetris
end

return {
	new_tetris = new_tetris,
}
