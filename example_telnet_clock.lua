#!/usr/bin/env luajit
local ldb = require("lua-db")
local socket = require("socket")
local time = require("time")

local connections = {}
local timeout = 0.3
local max_recv_buf = 16
local max_line_len = 1024
local clock_w, clock_h = 100, 100
local clock_db = ldb.new(clock_w, clock_h)
local clock_data
local clock_index = 0

local debug_log = false



local function log_debug(...)
	if debug_log then
		local str = {}
		for i, s in ipairs({...}) do
			table.insert(str, tostring(s))
		end
		print(("[%.10s]\t[debug]\t%s"):format(os.date(), table.concat(str, "\t")))
	end
end

local function log_info(...)
	local str = {}
	for i, s in ipairs({...}) do
		table.insert(str, tostring(s))
	end
	print(("[%.10s]\t[info ]\t%s"):format(os.date(), table.concat(str, "\t")))
end


-- this function draws the clock face on a drawbuffer
local function draw_clock(db, w,h, ox, oy, hour, min, sec)
	local hw = (w/2)
	local hh = (h/2)
	
	-- draw circle
	for i=0,math.pi*2,0.01 do
		local face_x = math.sin(i)*hw+hw
		local face_y = -math.cos(i)*hw+hh
		db:set_pixel(face_x+ox, face_y+oy, 255,255,255,255)
	end
	
	-- draw hour marks
	for i=0,math.pi*2,math.pi/6 do
		local tick_x1 = math.sin(i)*hw*0.8+hw
		local tick_y1 = -math.cos(i)*hw*0.8+hh
		local tick_x2 = math.sin(i)*hw*0.9+hw
		local tick_y2 = -math.cos(i)*hw*0.9+hh
		db:set_line_anti_aliased(tick_x1+ox,tick_y1+oy,tick_x2+ox,tick_y2+oy,255,255,255,0.5)
	end
	
	-- draw hour line
	if hour then
		local a = ((hour % 12) / 12) * 2 * math.pi
		local hour_x = math.sin(a)*hw*0.95+hw
		local hour_y = -math.cos(a)*hw*0.95+hh
		db:set_line_anti_aliased(hour_x+ox,hour_y+oy,hw+ox,hh+oy,255,255,255,1.3)
	end
	
	-- draw minute line
	if min then
		local a = (min / 60) * 2 * math.pi
		local min_x = math.sin(a)*hw*0.90+hw
		local min_y = -math.cos(a)*hw*0.90+hh
		db:set_line_anti_aliased(min_x+ox,min_y+oy,hw+ox,hh+oy,255,255,255,1)
	end
	
	-- draw second line
	if sec then
		local a = (sec / 60) * 2 * math.pi
		local sec_x = math.sin(a)*hw*0.90+hw
		local sec_y = -math.cos(a)*hw*0.90+hh
		db:set_line_anti_aliased(sec_x+ox,sec_y+oy,hw+ox,hh+oy,255,255,255,0.2)
	end
	
end


-- (=connection.update) called each iteration to handle input, generate output
local function connection_update(self)
	log_debug("connection update for socket", self.socket, #self.receive)

	if self.first then
		if clock_index ~= self.clock_index then
			log_debug("resending clock data")
			local str = {
				ldb.term.set_cursor(self.offset_x or 0,self.offset_y or 0),
				clock_data,
				"\n"
			}
			if self.color then
				local r,g,b = unpack(self.color)
				table.insert(str, 1, ldb.term.rgb_to_ansi_color_fg_216(r,g,b))
			end
			if self.text then
				table.insert(str, " " .. os.date() .. "              ")
			end
			
			table.insert(self.send, table.concat(str))
			self.clock_index = clock_index
		end
		
		for i, line in ipairs(self.receive) do
			if line == "hello" then
				table.insert(self.send, "\nHello!\n")
			elseif line:match("^offset (%d+) (%d+)$") then
				local ox, oy = line:match("^offset (%d+)$")
				self.offset_x = tonumber(oy)
			elseif line:match("^color (%d+) (%d+) (%d+)$") then
				local r,g,b = line:match("^color (%d+) (%d+) (%d+)$")
				r = tonumber(r)
				g = tonumber(g)
				b = tonumber(b)
				if r and g and b then
					self.color = {r,g,b}
				end
			elseif line == "text" then
				if self.text then
					self.text = false
				else
					self.text = true
				end
			elseif line:match("^close$") then
				self.close = true
			end
		end
		
		-- we have handled all data
		self.receive = {}
	else
		table.insert(self.send, "Hello World!\n")
		self.first = true
	end
end


-- updates the clock data if the time representation changed
local function clock_update()
	local t = os.date("*t")
	local c_clock_index = t.hour .. "_" .. t.min .. "_" .. t.sec
	if c_clock_index ~= clock_index then
		clock_db:clear(0,0,0,0)
		draw_clock(clock_db, clock_db:width(), clock_db:height(), 0,0, t.hour, t.min, t.sec)
		clock_data = table.concat(ldb.braile.draw_db(clock_db, 0), "\n")
		clock_index = c_clock_index
	end
end


-- called when the server socket accepted a new client with the client socket
local function add_client_socket(client_socket)
	log_debug("add client socket", client_socket)

	local connection = {}
	
	client_socket:settimeout(timeout)
	
	connection.socket = client_socket
	connection.send = {}
	connection.receive = {}
	connection.update = connection_update
	connection.close = false
	connection.closed = false
	
	table.insert(connections, connection)
	connections[client_socket] = connection
end


local server = socket.bind("127.0.0.1", 1234)
server:settimeout(timeout)

log_info("Entering main loop")
local run = true
while run do
	
	-- which sockets should be checked for reading/writing
	local recv_t = {}
	local send_t = {}
	
	-- check connections if they are ready to receive or send
	for k,connection in ipairs(connections) do
		if #connection.receive < max_recv_buf then
			-- receive buffer empty, ready to read more
			table.insert(recv_t, connection.socket)
		end
		if #connection.send > 0 then
			-- send buffer not empty, socket should be check for sending
			table.insert(send_t, connection.socket)
		end
	end
	
	-- Always insert the server to check for new connections
	table.insert(recv_t, server)
	
	log_debug("select...", #recv_t, #send_t)
	local recv_ok, send_ok = socket.select(recv_t, send_t, timeout)
	log_debug("\tok", #recv_ok, #send_ok)
	
	-- fill the receive buffers
	for k,socket in ipairs(recv_ok) do
		if socket == server then
			local client_socket = socket:accept()
			log_info("Server socket recv_ok. got new client from ip:", client_socket:getpeername(), "as", client_socket)
			add_client_socket(client_socket)
		else
			log_debug("Client socket recv_ok")
			local data,err = socket:receive("*l")
			local connection = connections[socket]
			if (data == nil) and (err == "closed") then
				connection.closed = true
			elseif data and #data > max_line_len then
				data = data:sub(1, max_line_len)
			end
			table.insert(connection.receive, 1, data)
		end
	end
	
	-- update clock face if needed
	clock_update()
	
	-- call update functions for each connection. (Consumes con.receive, adds to con.send)
	for k,connection in ipairs(connections) do
		connection:update()
	end
	
	-- send outstanding data
	for k,socket in ipairs(send_ok) do
		if socket ~= server then
			local connection = connections[socket]
			if #connection.send > 0 then
				log_debug("sending data on socket", socket)
				local data = table.remove(connection.send, 1)
				socket:send(data)
			end
		end
	end
	
	-- remove closed/closing sockets
	for k,connection in ipairs(connections) do
		if connection.close then
			log_debug("connection wants to close socket", connection.socket)
			if connection.on_close then
				connection:on_close()
			end
			connection.socket:close()
		end
		if connection.closed then
			log_debug("connection was closed:", connection.socket)
			if connection.on_closed then
				connection:on_closed()
			end
			table.remove(connections, k)
		end
	end
	
end
