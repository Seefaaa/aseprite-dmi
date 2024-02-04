--- Handles the received message and data.
--- @param message string - The type of the received message.
--- @param data string|nil - The received data, if any.
function Lib:on_receive(message, data)
	if message == WebSocketMessageType.OPEN then
		self.websocket_connected = true
		self:handle_event("open")
	elseif message == WebSocketMessageType.CLOSE then
		self.websocket_connected = false
		self:handle_event("close")
	elseif message == WebSocketMessageType.TEXT then
		if data and data:starts_with("{") and data:ends_with("}") then
			local data = json.decode(data) --[[@as {event: string, data?: any, error?: string}]]
			if data.error then
				if data.event ~= "pastestate" then
					print("Error: " .. data.error)
				end
			end
			self:handle_event(data.event, data.data, data.error)
		end
	end
end

--- Handles the specified event with the provided data.
--- @param event string The event to handle.
--- @param data string|nil The data associated with the event, if any.
--- @param error string|nil The error message, if any.
function Lib:handle_event(event, data, error)
	local listeners = self.listeners[event]

	if listeners then
		for _, listener in ipairs(listeners.on) do
			listener(data, error)
		end

		for _, listener in ipairs(listeners.once) do
			listener(data, error)
		end

		self.listeners[event].once = {}
	end
end

--- Adds a listener for the specified event.
--- @param event string The event name.
--- @param callback Websocket.Listener The callback function to be executed when the event is triggered.
function Lib:on(event, callback)
	if not self.listeners[event] then
		self.listeners[event] = {
			on = {},
			once = {},
		}
	end

	table.insert(self.listeners[event].on, callback)
end

--- Adds a callback function to be executed only once for a specific event.
--- @param event string The event name.
--- @param callback Websocket.Listener The callback function to be executed.
function Lib:once(event, callback)
	if not self.listeners[event] then
		self.listeners[event] = {
			on = {},
			once = {},
		}
	end
	table.insert(self.listeners[event].once, callback)
end

--- Waits for a specified event to occur.
--- DO NOT EVER USE
--- @param event string The event to wait for.
function Lib:wait_for(event)
	if not self.websocket_connected then
		return
	end

	local startTime = os.clock()
	local break_ = false
	self:once(event, function()
		break_ = true
	end)
	while true do
		if break_ or os.clock() - startTime >= WS_TIMEOUT then
			break
		end
	end
end
