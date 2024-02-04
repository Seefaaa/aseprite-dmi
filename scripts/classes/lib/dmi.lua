--- Creates a new file with the specified name, width, and height.
--- @param name string The name of the file.
--- @param width number The width of the file.
--- @param height number The height of the file.
--- @param callback fun(dmi?: Dmi, error?: string) The callback function to be called when the file is created.
function Lib:new_file(name, width, height, callback)
	self:send("newfile", '"' .. self.temp_dir .. '" "' .. name .. '" ' .. width .. ' ' .. height, function(data, error)
		callback(not error and Dmi.new(data) or nil, error)
	end)
end

--- Opens a DMI file and returns the parsed data.
--- @param path string The path to the DMI file.
--- @param callback fun(dmi?: Dmi, error?: string) The callback function to be called when the file is opened.
function Lib:open_file(path, callback)
	self:send("openfile", '"' .. path .. '" "' .. self.temp_dir .. '"')
	self:once("openfile", function(data, error)
		callback(not error and Dmi.new(data) or nil, error)
	end)
end

--- Saves the DMI data to a json file and calls lib with the path of the json.
--- @param dmi Dmi The DMI data to be saved.
--- @param path string The path where the DMI data will be saved.
--- @param callback fun(success: boolean, error?: string) The callback function to be called when the file is saved.
function Lib:save_file(dmi, path, callback)
	self:send("savefile", "'" .. path .. "' '" .. json.encode(dmi) .. "'", function(_, error)
		callback(not error, error)
	end)
end

--- Creates a new state using the provided DMI information.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param callback fun(state?: State, error?: string) The callback function to be called when the state is created.
function Lib:new_state(dmi, callback)
	self:send("newstate", '"' .. dmi.temp .. '" ' .. math.floor(dmi.width) .. ' ' .. math.floor(dmi.height),
		function(data, error)
			callback(not error and State.new(data) or nil, error)
		end)
end

--- Copies the provided state using the provided DMI information to the clipboard.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param state State The state to be copied.
--- @param callback? fun(success: boolean, error?: string) The callback function to be called when the state is copied.
function Lib:copy_state(dmi, state, callback)
	self:send("copystate", "'" .. dmi.temp .. "' '" .. json.encode(state) .. "'", callback and function(_, error)
		callback(not error, error)
	end or nil)
end

--- Pastes the state from the clipboard using the provided DMI information.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param callback fun(state?: State, error?: string) The callback function to be called when the state is pasted.
function Lib:paste_state(dmi, callback)
	self:send("pastestate", '"' .. dmi.temp .. '" ' .. math.floor(dmi.width) .. ' ' .. math.floor(dmi.height),
		function(data, error)
			callback(not error and State.new(data) or nil, error)
		end)
end
