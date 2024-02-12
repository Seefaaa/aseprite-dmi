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

--- Sends a command to the websocket server.
--- @param command string The command to send.
--- @param data? string The data to send.
--- @param callback? Websocket.Listener The callback function to be executed.
function Lib:send(command, data, callback)
	local text = command .. (data and (" " .. data) or "")

	if not self.websocket_connected then
		self.websocket:connect()
		self:once("open", function()
			self.websocket:sendText(text)
		end)
	else
		self.websocket:sendText(text)
	end

	if callback then
		self:once(command, callback)
	end
end

--- Removes a directory at the specified path.
--- @param path string The path of the directory to be removed.
--- @param callback? fun(success: boolean, error: string|nil) The callback function to be called when the directory is removed.
function Lib:remove_dir(path, callback)
	self:send("removedir", '"' .. path .. '"', callback and function(_, error)
		callback(not error, error)
	end or nil)
end

--- Checks for updates.
--- @param callback fun(up_to_date: boolean, error: string|nil) The callback function to be called when the update check is complete.
function Lib:check_update(callback)
	self:send("checkupdate", nil, function(data, error)
		callback(not error and data == true, error)
	end)
end

--- Opens the repository on browser.
--- @param path? string The path to use in url if not specified it will open the main page.
function Lib:open_repo(path)
	self:send("openrepo", path and ('"' .. path .. '"') or nil)
end
