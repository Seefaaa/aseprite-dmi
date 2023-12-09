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

	lib = Lib.new(app.fs.joinPath(plugin.path, "lib"), app.fs.joinPath(app.fs.tempPath, "aseprite-dmi"))
	image_cache = ImageCache.new()

	app.events:on("aftercommand", function(ev)
		if ev.name == "OpenFile" then
			if app.sprite and string.ends_with(app.sprite.filename, ".dmi") then
				local filename = app.sprite.filename
				app.command.CloseFile { ui = false }
				Editor.new("DMI Editor", filename)
			end
		end
	end)

	plugin:newMenuSeparator {
		group = "file_import",
	}

	plugin:newMenuGroup {
		id = "dmi_editor",
		title = "DMI Editor",
		group = "file_import",
	}

	plugin:newCommand {
		id = "file_new_dmi",
		title = "New DMI File",
		group = "dmi_editor",
		onclick = new_file,
	}
end

--- Exits the plugin. Called when the plugin is removed or Aseprite is closed.
--- @param plugin Plugin The plugin object.
function exit(plugin)
	lib:remove_dir(lib.temp_dir)
end
