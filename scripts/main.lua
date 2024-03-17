--- @diagnostic disable: lowercase-global

PLUGIN_PATH = nil --[[@type string]]

local after_listener --[[@type number]]

dofile("string.lua")
dofile("table.lua")
dofile("classes/mouse.lua")
dofile("classes/widget.lua")
dofile("classes/editor.lua")

--- Initializes the plugin. Called when the plugin is loaded.
--- @param plugin Plugin The plugin object.
function init(plugin)
	if app.apiVersion < 25 then
		return app.alert("This plugin requires Aseprite v1.3-rc5")
	end

	if not app.isUIAvailable then
		return
	end

	PLUGIN_PATH = plugin.path

	after_listener = app.events:on("aftercommand", function(ev)
		if ev.name == "OpenFile" then
			local filename = app.sprite.filename
			if app.sprite and string.ends_with(filename, ".dmi") then
				app.command.CloseFile { ui = false }
				loadlib()
				local editor = Editor(filename)
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
function loadlib()
	if libdmi then return end

	local win = app.fs.pathSeparator ~= "/"
	local lua_lib = win and "lua54" or nil
	local dmi_lib = win and "dmi" or "libdmi"

	if win then
		package.loadlib(app.fs.joinPath(PLUGIN_PATH, lua_lib --[[@as string]]), "")
	else
		package.cpath = package.cpath .. ";?.dylib"
	end

	package.loadlib(app.fs.joinPath(PLUGIN_PATH, dmi_lib), "luaopen_dmi_module")()
end
