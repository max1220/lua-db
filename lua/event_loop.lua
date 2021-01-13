local time = require("time")

-- this library implements a basic, but extendable event loop.
-- It's main use is in input_output.lua.
local event_loop = {}

-- create a new event loop. To use the event loop, call :update() on it
-- periodically. This will also  client:update(dt) for all event_clients, until
-- a client returns truethy for :update(dt).
-- You can trigger an event using loop:push_event(type, data). This will call
-- client:on_event(type, data) for all clients, until a client returns truethy.
function event_loop.new()
	local loop = {}
	loop.running = true

	-- list of connected clients that interact with events
	loop.event_clients = {}

	-- get a timer value(for dt in client:update())
	function loop:gettime()
		return time.monotonic()
	end

	-- push an event to all event_clients
	-- it is prefered to push events from a connected client.
	function loop:push_event(...)
		for _,event_client in ipairs(self.event_clients) do
			local do_break = event_client:on_event(...)
			if do_break then
				return do_break
			end
		end
	end

	-- call the client:update(dt) function for event_clients
	function loop:update()
		-- get time since last loop:update() call.
		local now = self:gettime()
		local dt = now - (self.last or now)
		self.last = now

		self.is_update = true
		for _,event_client in ipairs(self.event_clients) do
			local do_break = event_client:on_update(dt)
			if do_break then
				break
			end
		end
		self.is_update = false
	end

	-- add a client to the event_clients list
	function loop:add_client(client, i)
		if self.event_clients[client] then
			return nil
		end
		if i then
			table.insert(self.event_clients, i, client)
		else
			table.insert(self.event_clients, client)
		end
		self.event_clients[client] = client
		client.event_loop = self
		client:on_add()
		return true
	end

	-- remove a client fromm the event_clients list
	function loop:remove_client(client)
		if not self.clients[client] then
			return nil
		end
		for i,event_client in ipairs(self.event_clients) do
			if event_client == client then
				client:on_remove()
				client.event_loop = nil
				self.clients[client] = nil
				table.remove(self.event_clients, i)
				return true
			end
		end
	end

	return loop
end

-- return a new basic client for an event loop.
-- The client needs to be added to an event_loop
-- TODO: Add strict client that only allows pushing events in the :update() function
function event_loop.new_client()
	local client = {}

	-- set by the event_loop to itself when added
	client.event_loop = nil

	-- push an event to a connected event loop
	function client:push_event(...)
		if self.event_loop then
			self.event_loop:push_event(...)
		end
	end

	-- user callback for an event called in the event_loop:update() function
	function client:on_event(...) end

	-- user callback called when the event_loop:update is called
	function client:on_update(dt) end

	-- user callback called when the client is removed from an event loop.
	function client:on_remove() end

	-- user callback called when the client is removed from an event loop.
	function client:on_add() end

	return client
end

-- Utillity function to add an automatic function dispatch system to a client.
-- Trys to call a client["on_"..event.type](self) function for every event.
-- It ignores events without a type field and missing functions in the client.
-- It also ignores events with the type field set to event, update, remove, add.
function event_loop.client_sugar_event_callbacks(client)
	local orig_on_event = client.on_event
	function client:on_event(type, ...)
		-- call previous definition of client:on_event() (for chaining)
		local do_break = orig_on_event(self, type, ...)

		if (not type) or (not self["on_"..tostring(type)]) then
			return do_break -- Can't look up client callback, ignore...
		end
		if (type == "event") or (type == "update") or (type == "remove") or (type == "add") then
			return do_break -- These would call the regular client:on_event etc functions(name conflict)
		end

		-- break event_loop:update() if either the specialized on_* function,
		-- or the previous definition of client:on_event() returned truethy.
		do_break = do_break or self["on_"..tostring(type)](self, ...)
		return do_break
	end
end

-- Utillity function to add a check that makes sure that a client can only
-- push an event to the event_loop during a call to event_loop:update()
function event_loop.client_sugar_strict(client)
	function client:push_event(...)
		if self.event_loop and self.event_loop.is_update then
			self.event_loop:push_event(...)
		end
	end
end


return event_loop
