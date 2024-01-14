--- Lib is a class that serves as a library for the DMI Editor script.
--- It provides various utility functions.
--- @class Lib
--- @field path string The path to the library.
--- @field temp_dir string The temporary directory.
--- @field websocket WebSocket The websocket connection.
--- @field websocket_connected boolean Whether the websocket is connected.
--- @field websocket_pid string The websocket process ID.
--- @field listeners { [string]: { on: Websocket.Listener[], once: Websocket.Listener[] } } The websocket listeners.
Lib = {}
Lib.__index = Lib

--- Creates a new instance of the Lib class.
--- @param lib_path string The path to the library.
--- @param temp_dir string The temporary directory.
--- @return Lib lib The new Lib instance.
function Lib.new(lib_path, temp_dir)
	local self = setmetatable({}, Lib)
	self.path = lib_path
	self.temp_dir = temp_dir
	self.listeners = {}
	self.websocket = WebSocket {
		url = "ws://127.0.0.1:" .. PORT,
		deflate = false,
		onreceive = function(message, data)
			--- @param event string
			--- @param data string|nil
			--- @param error string|nil
			local handle = function(event, data, error)
				local listeners = self.listeners[event]

				if listeners then
					for _, listener in ipairs(listeners.on) do
						listener(message, data, error)
					end

					for _, listener in ipairs(listeners.once) do
						listener(message, data, error)
					end

					self.listeners[event].once = {}
				end
			end

			if message == WebSocketMessageType.OPEN then
				self.websocket_connected = true
				handle("open")
			elseif message == WebSocketMessageType.CLOSE then
				self.websocket_connected = false
				handle("close")
			elseif message == WebSocketMessageType.TEXT then
				if data then
					local data = data --[[@as string]]
					if data:starts_with("pid:") then
						self.websocket_pid = data:sub(5)
					elseif data:starts_with("{") and data:ends_with("}") then
						local json_data = json.decode(data) --[[@as {event: string, data?: any, error?: string}]]
						if json_data.error then
							print("Error: " .. json_data.error)
						end
						handle(json_data.event, json_data.data, json_data.error)
					end
				end
			end
		end,
	}

	os.execute(self.path .. " NEWWS " .. PORT)
	self.websocket:connect()

	return self
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

--- Executes a command with arguments and returns the result.
--- @param command string The command to execute.
--- @param args string The arguments for the command.
--- @param silent? boolean Whether to print the output of the command.
--- @return boolean|nil success True if the command executed successfully, false otherwise.
--- @return string reason The reason for the success or failure of the command.
--- @return number code The exit code of the command.
--- @return string output The output generated by the command.
function Lib:call(command, args, silent)
	local handle = io.popen(self.path .. " " .. command .. " " .. args, "r")

	assert(type(handle) == "userdata", "Lib:call: handle must be a userdata")

	---@diagnostic disable-next-line: undefined-field
	local output = handle:read("*a")
	---@diagnostic disable-next-line: undefined-field
	local success, reason, code = handle:close()

	if not success and not silent then
		self:print_error(code, reason, output)
	end

	return success, reason, code, output
end

--- Prints an error message with the provided code, reason, and output.
--- @param code number The error code.
--- @param reason string The reason for the error.
--- @param output string The output related to the error.
function Lib:print_error(code, reason, output)
	print("Error code: " .. code .. "\nReason: " .. reason .. "\nOutput: " .. output)
end

--- Opens a DMI file and returns the parsed data.
--- @param path string The path to the DMI file.
--- @param callback fun(dmi?: Dmi, error?: string) The callback function to be called when the file is opened.
function Lib:open(path, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:open(path, callback)
		end)
		return
	end

	self.websocket:sendText('openstate "' .. path .. '" "' .. self.temp_dir .. '"')

	self:once("openstate", function(_, data, error)
		callback(not error and Dmi.new(data) or nil, error)
	end)
end

--- Saves the DMI data to a json file and calls lib with the path of the json.
--- @param dmi Dmi The DMI data to be saved.
--- @param path string The path where the DMI data will be saved.
--- @param callback fun(success: boolean, error?: string) The callback function to be called when the file is saved.
function Lib:save(dmi, path, callback)
	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self:save(dmi, path, callback)
		end)
		return
	end

	self.websocket:sendText('savestate "' .. path .. '" \'' .. json.encode(dmi) .. '\'')
	self:once("savestate", function(_, _, error)
		callback(not error, error)
	end)
end

--- Waits for a specified event to occur.
--- @param event string The event to wait for.
function Lib:wait_for(event)
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
--- @return boolean|nil success Whether the file creation was successful.
--- @return string reason The reason for any failure in creating the file.
--- @return number code The code returned by the file creation process.
--- @return string output The output of the file creation process.
--- @return Dmi|nil dmi The newly created Dmi object, or nil if creation failed.
function Lib:new_file(name, width, height)
	local success, reason, code, output = self:call("NEW",
		'"' .. self.temp_dir .. '" "' .. name .. '" ' .. width .. ' ' .. height)
	return success, reason, code, output, success and Dmi.new(json.decode(output)) or nil
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
	self:once("newstate", function(_, data, error)
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
		self:once("copystate", function(_, _, error)
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
	self:once("pastestate", function(_, data, error)
		callback(not error and State.new(data) or nil, error)
	end)
end

--- Removes a directory at the specified path.
--- @param path string The path of the directory to be removed.
--- @return boolean|nil success True if the directory is successfully removed, false otherwise.
--- @return string reason The reason for the failure, if any.
--- @return number code The error code, if any.
--- @return string output The output message, if any.
function Lib:remove_dir(path)
	return self:call("RM", '"' .. path .. '"')
end
