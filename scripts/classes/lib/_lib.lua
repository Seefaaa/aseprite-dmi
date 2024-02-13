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

	os.execute(lib_path .. ' start "' .. temp_dir .. '"')

	local handle = io.open(app.fs.joinPath(temp_dir, "port"), "r")
	if handle then
		local output = handle:read("*l")
		local success = handle:close()
		if success and output then
			port = output
		end
	end

	assert(port, "Failed to start websocket server. Check your antivirus and firewall settings.")

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
