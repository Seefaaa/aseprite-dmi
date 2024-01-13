--- @diagnostic disable: lowercase-global

--- Initializes the plugin. Called when the plugin is loaded.
--- @param plugin Plugin The plugin object.
function init(plugin)
	if app.apiVersion < 25 then
		return app.alert("This script requires Aseprite v1.3-rc5")
	end

	if not app.isUIAvailable then
		return
	end

	app.events:on("aftercommand", function(ev)
		if ev.name == "OpenFile" then
			if app.sprite and app.sprite.filename:ends_with(".dmi") then
				local filename = app.sprite.filename
				app.command.CloseFile { ui = false }

				if not lib then
					lib = Lib.new(app.fs.joinPath(plugin.path, LIB_BIN), app.fs.joinPath(app.fs.tempPath, TEMP_NAME))
					lib:once("open", function()
						Editor.new(DIALOG_NAME, filename)
					end)
				else
					Editor.new(DIALOG_NAME, filename)
				end
			end
		end
	end)

	plugin:newMenuSeparator {
		group = "file_import",
	}

	plugin:newMenuGroup {
		id = "dmi_editor",
		title = DIALOG_NAME,
		group = "file_import",
	}

	plugin:newCommand {
		id = "dmi_new_file",
		title = "New DMI File",
		group = "dmi_editor",
		onclick = new_file,
	}

	plugin:newCommand {
		id = "dmi_ws_test",
		title = "WS Test",
		group = "dmi_editor",
		onclick = function()
			if not lib then
				lib = Lib.new(app.fs.joinPath(plugin.path, LIB_BIN), app.fs.joinPath(app.fs.tempPath, TEMP_NAME))
			end

			lib:on("open", function()
				lib.websocket:sendText("Hello, world!")
			end)
		end,
	}
end

--- Exits the plugin. Called when the plugin is removed or Aseprite is closed.
--- @param plugin Plugin The plugin object.
function exit(plugin)
	if lib then
		lib:remove_dir(lib.temp_dir)
		if lib.websocket_connected then
			lib.websocket:sendText("exit")
			lib.websocket:close()
		end
	end
end
