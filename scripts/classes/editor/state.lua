
--- Opens a state in the Aseprite editor by creating a new sprite and populating it with frames and layers based on the provided state.
---@param state State The state to be opened.
function Editor:open_state(state)
	for _, sprite in ipairs(app.sprites) do
		if sprite.filename == app.fs.joinPath(self.dmi.temp, state.frame_key .. ".ase") then
			return
		end
	end

	local preview_image = self.image_cache:get(state.frame_key)
	local transparentColor = transparent_color(preview_image)

	local sprite = Sprite(ImageSpec {
		width = self.dmi.width,
		height = self.dmi.height,
		colorMode = ColorMode.RGB,
		transparentColor = app.pixelColor.rgba(transparentColor.red, transparentColor.green, transparentColor.blue, transparentColor.alpha)
	})

	app.transaction("Load State", function()
		while #sprite.layers < state.dirs do
			local layer = sprite:newLayer()
			layer.isVisible = false
		end

		if state.frame_count > 1 then
			sprite:newFrame(state.frame_count - 1)
		end

		if #state.delays > 1 then
			for index, frame in ipairs(sprite.frames) do
				frame.duration = (state.delays[index] or 1) / 10
			end
		end

		sprite.layers[1].isVisible = false
		sprite.layers[#sprite.layers].isVisible = true

		local index = 1
		for frame = 1, #sprite.frames, 1 do
			for layer = #sprite.layers, 1, -1 do
				sprite.layers[layer].name = DIRECTION_NAMES[#sprite.layers - layer + 1]
				sprite:newCel(
					sprite.layers[layer],
					sprite.frames[frame],
					index == 1 and self.image_cache:get(state.frame_key) or
					load_image_bytes(app.fs.joinPath(self.dmi.temp, state.frame_key .. "." .. math.floor(index - 1) .. ".bytes")),
					Point(0, 0)
				)
				index = index + 1
			end
		end

		app.frame = 1
		app.command.ColorQuantization { ui = false }
	end)

	sprite:saveAs(app.fs.joinPath(self.dmi.temp, state.frame_key .. ".ase"))
	app.command.FitScreen()

	-- app.command.SaveFile { ui = false, filename = app.fs.joinPath(self.dmi.temp, state.frame_key .. ".ase") }

	table.insert(self.open_sprites, StateSprite.new(self, self.dmi, state, sprite, transparentColor))
	self:remove_nil_statesprites()
end

--- Opens a context menu for a state.
--- @param state State The state to be opened.
--- @param ev MouseEvent The mouse event object.
function Editor:state_context(state, ev)
	self.context_widget = ContextWidget.new(
		Rectangle(ev.x, ev.y, 0, 0),
		{
			{ text = "Properties", onclick = function() self:state_properties(state) end },
			{ text = "Open",       onclick = function() self:open_state(state) end },
			{ text = "Copy",       onclick = function() self:copy_state(state) end },
			{ text = "Remove",     onclick = function() self:remove_state(state) end },
		}
	)
	self:repaint()
end

--- Displays a dialog for editing the properties of a state.
--- @param state State The state object to edit.
function Editor:state_properties(state)
	local dialog = Dialog {
		title = "State Properties",
		parent = self.dialog
	}

	dialog:entry {
		id = "state_name",
		label = "State name:",
		text = state.name,
		focus = true,
	}

	local open = false
	for _, state_sprite_ in ipairs(self.open_sprites) do
		if state_sprite_.state == state then
			open = true
			break
		end
	end

	if open then
		dialog:combobox {
			id = "state_directions",
			label = "Directions:",
			option = tostring(math.floor(state.dirs)),
			options = { "1", "4", "8", },
		}
	else
		local direction = tostring(math.floor(state.dirs))
		dialog:combobox {
			id = "state_directions",
			label = "Directions:",
			option = direction,
			options = { direction, "--OPEN-STATE--" },
		}
	end

	dialog:number {
		id = "state_loop",
		label = "Loop:",
		text = tostring(math.floor(state.loop_)),
		decimals = 0,
	}

	dialog:check {
		id = "state_movement",
		label = "Movement state:",
		selected = state.movement,
	}

	dialog:check {
		id = "state_rewind",
		label = "Rewind:",
		selected = state.rewind,
	}

	dialog:separator()

	dialog:button {
		text = "OK",
		focus = true,
		onclick = function()
			local state_name = dialog.data["state_name"]
			if #state_name > 0 and state.name ~= state_name then
				state.name = dialog.data["state_name"]
				self:repaint_states()
			end
			local direction = tonumber(dialog.data["state_directions"])
			if (direction == 1 or direction == 4 or direction == 8) and state.dirs ~= direction then
				self:set_state_dirs(state, direction)
			end
			local loop = tonumber(dialog.data["state_loop"])
			if loop then
				loop = math.floor(loop)
				if loop >= 0 then
					state.loop_ = loop
				end
			end
			state.movement = dialog.data["state_movement"] or false
			state.rewind = dialog.data["state_rewind"] or false
			dialog:close()
		end
	}

	dialog:button {
		text = "Cancel",
		onclick = function()
			dialog:close()
		end
	}

	dialog:show()
end

--- Sets the number of directions for a state.
--- @param state State
--- @param directions 1|4|8
function Editor:set_state_dirs(state, directions)
	--- @type StateSprite|nil
	local state_sprite = nil
	for _, state_sprite_ in ipairs(self.open_sprites) do
		if state_sprite_.state == state then
			state_sprite = state_sprite_
			break
		end
	end

	if state_sprite then
		app.transaction("Change State Directions", function()
			local sprite = state_sprite.sprite
			if state.dirs > directions then
				for _, layer in ipairs(sprite.layers) do
					local index = table.index_of(DIRECTION_NAMES, layer.name)
					if index ~= 0 and index > directions then
						sprite:deleteLayer(layer)
					end
				end
				if #sprite.layers > 0 then
					local layer = sprite.layers[1]
					layer.isVisible = not layer.isVisible
					layer.isVisible = not layer.isVisible
				end
			else
				--- @type Layer|nil
				local primary_layer = nil
				for _, layer in ipairs(sprite.layers) do
					if layer.name == DIRECTION_NAMES[1] then
						primary_layer = layer
						break
					end
				end

				for i = state.dirs + 1, directions, 1 do
					local layer_name = DIRECTION_NAMES[i]

					local exists = false
					for _, layer in ipairs(sprite.layers) do
						if layer.name == layer_name then
							exists = true
							break
						end
					end

					if not exists then
						local layer = sprite:newLayer()
						layer.stackIndex = 1
						layer.name = layer_name
						layer.isVisible = false

						if primary_layer then
							for _, frame in ipairs(sprite.frames) do
								local cel = primary_layer:cel(frame.frameNumber)
								local image = Image(ImageSpec {
									width = sprite.width,
									height = sprite.height,
									colorMode = ColorMode.RGB,
									transparentColor = app.pixelColor.rgba(state_sprite.transparentColor.red, state_sprite.transparentColor.green, state_sprite.transparentColor.blue, state_sprite.transparentColor.alpha)
								})

								if cel and cel.image then
									image:drawImage(cel.image, cel.position)
								else
									image:drawImage(self.image_cache:get(state.frame_key), Point(0, 0))
								end

								sprite:newCel(layer, frame, image, Point(0, 0))
							end
						end
					end
				end
				sprite:deleteLayer(sprite:newLayer())
			end
			state.dirs = directions
			state_sprite:save()
		end)
	end
end

-- Creates a new state for the editor.
function Editor:new_state()
	if not self.dmi then return end

	lib:new_state(self.dmi, function(state, error)
		if not error then
			table.insert(self.dmi.states, state)
			self.image_cache:load_state(self.dmi, state --[[@as State]])
			self:repaint_states()
		else
			app.alert { title = self.title, text = { "Failed to create new state", error } }
		end
	end)
end

--- Removes a state from the DMI file.
--- @param state State The state to be removed.
function Editor:remove_state(state)
	for i, state_sprite in ipairs(self.open_sprites) do
		if state_sprite.state == state then
			state_sprite.sprite:close()
			table.remove(self.open_sprites, i)
			break
		end
	end

	table.remove(self.dmi.states, table.index_of(self.dmi.states, state))
	self.image_cache:remove(state.frame_key)
	self:repaint_states()
end

--- Copies a state to the clipboard.
--- @param state State The state to be copied.
function Editor:copy_state(state)
	for _, state_sprite in ipairs(self.open_sprites) do
		if state_sprite.state == state then
			if state_sprite.sprite.isModified then
				app.alert { title = self.title, text = "Save the open sprite first" }
				return
			end
			break
		end
	end

	lib:copy_state(self.dmi, state)
end

--- Creates a new state in the DMI file copied from the clipboard.
function Editor:paste_state()
	if not self.dmi then return end

	lib:paste_state(self.dmi, function(state, error)
		if not error then
			table.insert(self.dmi.states, state)
			self.image_cache:load_state(self.dmi, state --[[@as State]])
			self:repaint_states()
		end
	end)
end
