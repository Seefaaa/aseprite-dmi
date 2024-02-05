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
					init_lib(plugin.path, function()
						Editor.new(DIALOG_NAME, filename, nil, function()
							lib:check_update(update_popup)
						end)
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
		onclick = Editor.new_file,
	}

	plugin:newMenuSeparator {
		group = "dmi_editor",
	}

	plugin:newCommand {
		id = "dmi_report_issue",
		title = "Report Issue",
		group = "dmi_editor",
		onclick = function()
			init_lib(plugin.path, function()
				lib:open_repo("issues")
			end)
		end,
	}

	plugin:newCommand {
		id = "dmi_releases",
		title = "Releases",
		group = "dmi_editor",
		onclick = function()
			init_lib(plugin.path, function()
				lib:open_repo("releases")
			end)
		end,
	}
end

--- Exits the plugin. Called when the plugin is removed or Aseprite is closed.
--- @param plugin Plugin The plugin object.
function exit(plugin)
	if lib then
		lib:remove_dir(lib.temp_dir, function()
			lib.websocket:close()
		end)
	end
end

--- Initializes the lib for first time and calls the callback when it's done.
--- If the lib is already initialized, it will call the callback immediately.
--- @param path string lib path
--- @param callback fun() callback
function init_lib(path, callback)
	if not lib then
		lib = Lib.new(app.fs.joinPath(path, LIB_BIN), app.fs.joinPath(app.fs.tempPath, TEMP_NAME))
		lib:once("open", function()
			callback()
		end)
	else
		callback()
	end
end

--- Shows the update alert popup.
--- @param up_to_date boolean
function update_popup(up_to_date)
	if not up_to_date then
		local button = app.alert {
			title = "Update Available",
			text = {
				"An update is available for the DMI Editor plugin.",
				"Would you like to download it now?",
				"Pressing \"OK\" will open the releases page in your browser."
			},
			buttons = { "OK", "Later" },
		}
		if button == 1 then
			lib:open_repo("releases")
		end
	end
end
