--- @diagnostic disable: lowercase-global

--- After command listener.
--- @type number|nil
local after_listener = nil

--- Before command listener.
--- @type number|nil
local before_listener = nil

--- Open editors.
--- @type Editor[]
open_editors = {}

--- Lib instance.
--- @type Lib|nil
lib = nil

--- Initializes the plugin. Called when the plugin is loaded.
--- @param plugin Plugin The plugin object.
function init(plugin)
	if app.apiVersion < 25 then
		return app.alert("This script requires Aseprite v1.3-rc5")
	end

	if not app.isUIAvailable then
		return
	end

	after_listener = app.events:on("aftercommand", function(ev)
		if ev.name == "OpenFile" then
			if app.sprite and app.sprite.filename:ends_with(".dmi") then
				local filename = app.sprite.filename
				app.command.CloseFile { ui = false }

				if not lib then
					init_lib(plugin.path, function()
						Editor.new(DIALOG_NAME, filename, nil, function()
							lib --[[@as Lib]]:check_update(update_popup)
						end)
					end)
				else
					Editor.new(DIALOG_NAME, filename)
				end
			end
		end
	end)

	before_listener = app.events:on("beforecommand", function(ev)
		if ev.name == "Exit" then
			local stopped = false
			if #open_editors > 0 then
				local editors = table.clone(open_editors) --[[@as Editor[] ]]
				for _, editor in ipairs(editors) do
					if not editor:close(false) and not stopped then
						stopped = true
						ev.stopPropagation()
					end
				end
			end
		end
	end)

	local is_state_sprite = function ()
		for _, editor in ipairs(open_editors) do
			for _, sprite in ipairs(editor.open_sprites) do
				if app.sprite == sprite.sprite then
					return sprite
				end
			end
		end
		return nil
	end

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
		onclick = function()
			Editor.new_file(plugin.path)
		end,
	}

	plugin:newMenuSeparator {
		group = "dmi_editor",
	}

	plugin:newCommand {
		id = "dmi_resize",
		title = "Resize",
		group = "dmi_editor",
		onclick = function()
			local state_sprite = is_state_sprite()
			if state_sprite then
				state_sprite.editor:resize()
			end
		end,
		onenabled = function()
			return is_state_sprite() and true or false
		end,
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
	if after_listener then
		app.events:off(after_listener)
		after_listener = nil
	end
	if before_listener then
		app.events:off(before_listener)
		before_listener = nil
	end
	if #open_editors > 0 then
		local editors = table.clone(open_editors) --[[@as Editor[] ]]
		for _, editor in ipairs(editors) do
			editor:close(false, true)
		end
	end
	if lib then
		lib.websocket:close()
		lib = nil
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
		local dialog = Dialog {
			title = "Update Available",
		}

		dialog:label {
			focus = true,
			text = "An update is available for DMI Editor.",
		}

		dialog:newrow()

		dialog:label {
			text = "Would you like to download it now?",
		}

		dialog:newrow()

		dialog:label {
			text = "Pressing \"OK\" will open the releases page in your browser.",
		}

		dialog:button {
			focus = true,
			text = "&OK",
			onclick = function()
				lib:open_repo("releases")
				dialog:close()
			end,
		}

		dialog:button {
			text = "&Later",
			onclick = function()
				dialog:close()
			end,
		}

		dialog:show()
	end
end
