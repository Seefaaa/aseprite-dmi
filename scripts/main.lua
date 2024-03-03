--- @diagnostic disable: lowercase-global

local after_listener --[[@type number]]

dofile("string.lua")

--- Initializes the plugin. Called when the plugin is loaded.
--- @param plugin Plugin The plugin object.
function init(plugin)
	if app.apiVersion < 25 then
		return app.alert("This plugin requires Aseprite v1.3-rc5")
	end

	if not app.isUIAvailable then
		return
	end

	after_listener = app.events:on("aftercommand", function(ev)
		if ev.name == "OpenFile" then
			local filename = app.sprite.filename
			if app.sprite and string.ends_with(filename, ".dmi") then
				app.command.CloseFile { ui = false }
				loadlib(plugin.path)
				Editor.open(filename)
			end
		end
	end)

	plugin:newCommand {
		id = "lua_mem_usage",
		title = "Lua Memory Usage",
		group = "file_open",
		onclick = function()
			app.alert("Memory usage: " .. collectgarbage("count") .. " KB")
		end
	}
end

--- Exits the plugin. Called when the plugin is removed or Aseprite is closed.
--- @param plugin Plugin The plugin object.
function exit(plugin)
	if app.apiVersion < 25 or not app.isUIAvailable then return end

	app.events:off(after_listener)
end

--- Loads the DMI library.
--- @param path string Path where the extension is installed.
function loadlib(path)
	if libdmi then return end

	local win = app.fs.pathSeparator ~= "/"
	local lua_lib = win and "lua54" or nil
	local dmi_lib = win and "dmi" or "libdmi"

	if win then
		package.loadlib(app.fs.joinPath(path, lua_lib --[[@as string]]), "")
	else
		package.cpath = package.cpath .. ";?.dylib"
	end

	package.loadlib(app.fs.joinPath(path, dmi_lib), "luaopen_dmi_module")()
end
