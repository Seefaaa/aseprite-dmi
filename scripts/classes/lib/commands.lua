------------------- DMI -------------------

--- Creates a new file with the specified name, width, and height.
--- @param name string The name of the file.
--- @param width number The width of the file.
--- @param height number The height of the file.
--- @param callback fun(dmi: Dmi|nil, error: string|nil) The callback function to be called when the file is created.
function Lib:new_file(name, width, height, callback)
	self:send("newfile",
		'"' .. app.fs.joinPath(self.temp_dir, "editors") .. '" "' .. name .. '" ' .. width .. ' ' .. height,
		function(data, error)
			callback(not error and Dmi.new(data) or nil, error)
		end)
end

--- Opens a DMI file and returns the parsed data.
--- @param path string The path to the DMI file.
--- @param callback fun(dmi: Dmi|nil, error: string|nil) The callback function to be called when the file is opened.
function Lib:open_file(path, callback)
	self:send("openfile", '"' .. path .. '" "' .. app.fs.joinPath(self.temp_dir, "editors") .. '"', function(data, error)
		callback(not error and Dmi.new(data) or nil, error)
	end)
end

--- Saves the DMI data to a json file and calls lib with the path of the json.
--- @param dmi Dmi The DMI data to be saved.
--- @param path string The path where the DMI data will be saved.
--- @param callback fun(success: boolean, error: string|nil) The callback function to be called when the file is saved.
function Lib:save_file(dmi, path, callback)
	self:send("savefile", "'" .. path .. "' '" .. json.encode(dmi) .. "'", function(_, error)
		callback(not error, error)
	end)
end

--- Creates a new state using the provided DMI information.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param callback fun(state: State|nil, error: string|nil) The callback function to be called when the state is created.
function Lib:new_state(dmi, callback)
	self:send("newstate", '"' .. dmi.temp .. '" ' .. math.floor(dmi.width) .. ' ' .. math.floor(dmi.height),
		function(data, error)
			callback(not error and State.new(data) or nil, error)
		end)
end

--- Copies the provided state using the provided DMI information to the clipboard.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param state State The state to be copied.
--- @param callback? fun(success: boolean, error: string|nil) The callback function to be called when the state is copied.
function Lib:copy_state(dmi, state, callback)
	self:send("copystate", "'" .. dmi.temp .. "' '" .. json.encode(state) .. "'", callback and function(_, error)
		callback(not error, error)
	end or nil)
end

--- Pastes the state from the clipboard using the provided DMI information.
--- @param dmi Dmi The DMI object containing the necessary information.
--- @param callback fun(state: State|nil, error: string|nil) The callback function to be called when the state is pasted.
function Lib:paste_state(dmi, callback)
	self:send("pastestate", '"' .. dmi.temp .. '" ' .. math.floor(dmi.width) .. ' ' .. math.floor(dmi.height),
		function(data, error)
			callback(not error and State.new(data) or nil, error)
		end)
end

--- Resizes the provided DMI to the specified width and height using the provided method.
--- @param dmi Dmi The DMI object to be resized.
--- @param width number The new width of the DMI.
--- @param height number The new height of the DMI.
--- @param method string The method to be used for resizing.
--- @param callback fun(success: boolean, error: string|nil) The callback function to be called when the DMI is resized.
function Lib:resize(dmi, width, height, method, callback)
	self:send("resize", "'" .. json.encode(dmi) .. "' " .. width .. " " .. height .. " " .. method, function(_, error)
		callback(not error, error)
	end)
end

------------------- OTHER -------------------

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
