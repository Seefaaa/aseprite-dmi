--- Lib is a class that serves as a library for the DMI Editor script.
--- It provides various utility functions.
--- @class Lib
--- @field path string The path to the library.
--- @field temp_dir string The temporary directory.
--- @field websocket WebSocket The websocket connection.
--- @field websocket_connected boolean Whether the websocket is connected.
--- @field listeners { [string]: { on: Websocket.Listener[], once: Websocket.Listener[] } } The websocket listeners.
Lib = {}
Lib.__index = Lib

--- Creates a new instance of the Lib class.
--- @param lib_path string The path to the library.
--- @param temp_dir string The temporary directory.
--- @return Lib lib The new Lib instance.
function Lib.new(lib_path, temp_dir)
	local self = setmetatable({}, Lib)

	local port = nil
	local file_name = app.fs.joinPath(temp_dir, "port")

	os.execute(lib_path .. ' init "' .. file_name .. '"')

	local handle = io.open(file_name, "r")
	if handle then
		local output = handle:read("*l")
		local success = handle:close()
		if success and output then
			port = output
		end
	end

	if port == nil then
		error("Failed to start websocket server.")
	end

	self.path = lib_path
	self.temp_dir = temp_dir
	self.listeners = {}
	self.websocket = WebSocket {
		url = "ws://127.0.0.1:" .. port,
		deflate = false,
		onreceive = function(message, data)
			self:on_receive(message, data)
		end,
	}

	self.websocket:connect()

	return self
end

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

--- Creates a new file with the specified name, width, and height.
--- @param name string The name of the file.
--- @param width number The width of the file.
--- @param height number The height of the file.
--- @param callback fun(dmi?: Dmi, error?: string) The callback function to be called when the file is created.
function Lib:new_file(name, width, height, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:new_file(name, width, height, callback)
		end)
		return
	end

	self.websocket:sendText('newfile "' .. self.temp_dir .. '" "' .. name .. '" ' .. width .. ' ' .. height)
	self:once("newfile", function(data, error)
		callback(not error and Dmi.new(data) or nil, error)
	end)
end

--- Opens a DMI file and returns the parsed data.
--- @param path string The path to the DMI file.
--- @param callback fun(dmi?: Dmi, error?: string) The callback function to be called when the file is opened.
function Lib:open_file(path, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:open_file(path, callback)
		end)
		return
	end

	self.websocket:sendText('openfile "' .. path .. '" "' .. self.temp_dir .. '"')

	self:once("openfile", function(data, error)
		callback(not error and Dmi.new(data) or nil, error)
	end)
end

--- Saves the DMI data to a json file and calls lib with the path of the json.
--- @param dmi Dmi The DMI data to be saved.
--- @param path string The path where the DMI data will be saved.
--- @param callback fun(success: boolean, error?: string) The callback function to be called when the file is saved.
function Lib:save_file(dmi, path, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:save_file(dmi, path, callback)
		end)
		return
	end

	self.websocket:sendText('savefile "' .. path .. '" \'' .. json.encode(dmi) .. '\'')
	self:once("savefile", function(_, error)
		callback(not error, error)
	end)
end

--- Creates a new state using the provided DMI information.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param callback fun(state?: State, error?: string) The callback function to be called when the state is created.
function Lib:new_state(dmi, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:new_state(dmi, callback)
		end)
		return
	end

	self.websocket:sendText('newstate "' .. dmi.temp .. '" ' .. math.floor(dmi.width) .. ' ' .. math.floor(dmi.height))
	self:once("newstate", function(data, error)
		callback(not error and State.new(data) or nil, error)
	end)
end

--- Copies the provided state using the provided DMI information to the clipboard.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param state State The state to be copied.
--- @param callback? fun(success: boolean, error?: string) The callback function to be called when the state is copied.
function Lib:copy_state(dmi, state, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:copy_state(dmi, state, callback)
		end)
		return
	end

	self.websocket:sendText('copystate "' .. dmi.temp .. '" \'' .. json.encode(state) .. '\'')
	if callback then
		self:once("copystate", function(_, error)
			callback(not error, error)
		end)
	end
end

--- Pastes the state from the clipboard using the provided DMI information.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param callback fun(state?: State, error?: string) The callback function to be called when the state is pasted.
function Lib:paste_state(dmi, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:paste_state(dmi, callback)
		end)
		return
	end

	self.websocket:sendText('pastestate "' .. dmi.temp .. '" ' .. math.floor(dmi.width) .. ' ' .. math.floor(dmi.height))
	self:once("pastestate", function(data, error)
		callback(not error and State.new(data) or nil, error)
	end)
end

--- Removes a directory at the specified path.
--- @param path string The path of the directory to be removed.
--- @param callback? fun(success: boolean, error?: string) The callback function to be called when the directory is removed.
function Lib:remove_dir(path, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:remove_dir(path, callback)
		end)
		return
	end

	self.websocket:sendText('removedir "' .. path .. '"')
	if callback then
		self:once("removedir", function(_, error)
			callback(not error, error)
		end)
	end
end
