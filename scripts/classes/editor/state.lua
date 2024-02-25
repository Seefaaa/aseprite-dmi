--- Creates a new DMI file with the specified width and height.
--- Uses native new file dialog to get the dimensions.
--- If the file creation is successful, opens the DMI Editor with the newly created file.
--- @param plugin_path string Path where the extension is installed.
function Editor.new_file(plugin_path)
	local previous_sprite = app.sprite
	if app.command.NewFile { width = 32, height = 32 } then
		if previous_sprite ~= app.sprite then
			local width = app.sprite.width
			local height = app.sprite.height

			app.command.CloseFile { ui = false }

			if width < 3 or height < 3 then
				app.alert { title = "Warning", text = "Width and height must be at least 3 pixels", buttons = { "&OK" } }
				return
			end

			loadlib(plugin_path)

			local dmi, error = libdmi.new_file("untitled", width, height, TEMP_DIR)
			if not error then
				Editor.new(DIALOG_NAME, dmi --[[@as Dmi]])
			else
				app.alert { title = "Error", text = { "Failed to create new file", error } }
			end
		end
	end
end

--- Opens a state in the Aseprite editor by creating a new sprite and populating it with frames and layers based on the provided state.
---@param state State The state to be opened.
function Editor:open_state(state)
	for _, sprite in ipairs(app.sprites) do
		if sprite.filename == app.fs.joinPath(self.dmi.temp, state.frame_key .. ".ase") then
			self.switch_tab(sprite)
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

		local is_empty = true
		for _, cel in ipairs(sprite.cels) do
			if not cel.image:isEmpty() then
				is_empty = false
				app.command.ColorQuantization { ui = false, withAlpha = false }

				local palette = sprite.palettes[1]
				if palette:getColor(0).alpha == 0 then
					if #palette > 1 then
						local colors = {}
						for i = 1, #palette - 1, 1 do
							local color = palette:getColor(i)
							table.insert(colors, color)
						end
						local new_palette = Palette(#colors)
						for i, color in ipairs(colors) do
							new_palette:setColor(i - 1, color)
						end
						sprite:setPalette(new_palette)
					else
						app.command.LoadPalette { ui = false, preset = "default" }
					end
				end
				break
			end
		end

		if is_empty then
			app.command.LoadPalette { ui = false, preset = "default" }
		end
	end)

	sprite:saveAs(app.fs.joinPath(self.dmi.temp, state.frame_key .. ".ase"))
	app.command.FitScreen()

	self:gc_open_sprites()
	table.insert(self.open_sprites, StateSprite.new(self, self.dmi, state, sprite, transparentColor))
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
		title = "State Properties"
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
		text = tostring(math.floor(state.loop)),
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

	dialog:button {
		text = "&OK",
		focus = true,
		onclick = function()
			local state_name = dialog.data.state_name
			if #state_name > 0 and state.name ~= state_name then
				state.name = dialog.data.state_name
				self:repaint_states()
			end
			local direction = tonumber(dialog.data.state_directions)
			if (direction == 1 or direction == 4 or direction == 8) and state.dirs ~= direction then
				self:set_state_dirs(state, direction)
			end
			local loop = tonumber(dialog.data.state_loop)
			if loop then
				loop = math.floor(loop)
				if loop >= 0 then
					state.loop = loop
				end
			end
			state.movement = dialog.data.state_movement or false
			state.rewind = dialog.data.state_rewind or false
			dialog:close()
		end
	}

	dialog:button {
		text = "&Cancel",
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
	local state_sprite = nil --[[@type StateSprite|nil]]
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
				local primary_layer = nil --[[@type Layer|nil]]
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

	local state, error = libdmi.new_state(self.dmi.width, self.dmi.height, self.dmi.temp)
	if not error then
		self.modified = true
		table.insert(self.dmi.states, state)
		self.image_cache:load_state(self.dmi, state --[[@as State]])
		self:repaint_states()
		self:gc_open_sprites()
	else
		app.alert { title = "Error", text = { "Failed to create new state", error } }
	end
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
	self:gc_open_sprites()
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

	libdmi.copy_state(state, self.dmi.temp)
end

--- Creates a new state in the DMI file copied from the clipboard.
function Editor:paste_state()
	if not self.dmi then return end

	local state = libdmi.paste_state(self.dmi.width, self.dmi.height, self.dmi.temp)
	if state then
		self.modified = true
		table.insert(self.dmi.states, state)
		self.image_cache:load_state(self.dmi, state)
		self:repaint_states()
		self:gc_open_sprites()
	end
end

--- Shows a dialog to resize the DMI file.
function Editor:resize()
	if not self.dmi then return end

	local original_width = self.dmi.width
	local original_height = self.dmi.height
	local ratio = original_width / original_height

	local dialog = Dialog {
		title = "Resize"
	}

	dialog:separator { text = "Pixels:" }

	dialog:number {
		id = "width",
		focus = true,
		label = "Width:",
		text = tostring(original_width),
		decimals = 0,
		onchange = function()
			local width = dialog.data.width

			dialog:modify {
				id = "width_percentage",
				text = width / original_width * 100
			}

			if dialog.data.ratio_lock then
				local height = math.floor(width / ratio)

				dialog:modify {
					id = "height",
					text = height
				}
				dialog:modify {
					id = "height_percentage",
					text = height / original_height * 100
				}
			end
		end
	}

	dialog:number {
		id = "height",
		label = "Height:",
		text = tostring(original_height),
		decimals = 0,
		onchange = function()
			local height = dialog.data.height

			dialog:modify {
				id = "height_percentage",
				text = height / original_height * 100
			}

			if dialog.data.ratio_lock then
				local width = math.floor(height * ratio)

				dialog:modify {
					id = "width",
					text = width
				}
				dialog:modify {
					id = "width_percentage",
					text = width / original_width * 100
				}
			end
		end
	}

	dialog:check {
		id = "ratio_lock",
		label = "Lock Ratio",
		selected = true,
		onclick = function()
			if dialog.data.ratio_lock then
				local width = dialog.data.width
				local height = math.floor(width / ratio)

				dialog:modify {
					id = "height",
					text = height
				}
				dialog:modify {
					id = "height_percentage",
					text = height / original_height * 100
				}
			end
		end
	}

	dialog:separator { text = "Percentage:" }

	dialog:number {
		id = "width_percentage",
		label = "Width:",
		text = "100",
		onchange = function()
			local width = dialog.data.width_percentage
			width = math.floor(width * original_width / 100)

			dialog:modify {
				id = "width",
				text = width
			}

			if dialog.data.ratio_lock then
				local height = math.floor(width / ratio)

				dialog:modify {
					id = "height",
					text = height
				}
				dialog:modify {
					id = "height_percentage",
					text = height / original_height * 100
				}
			end
		end
	}

	dialog:number {
		id = "height_percentage",
		label = "Height:",
		text = "100",
		onchange = function()
			local height = dialog.data.height_percentage
			height = math.floor(height * original_height / 100)

			dialog:modify {
				id = "height",
				text = height
			}

			if dialog.data.ratio_lock then
				local width = math.floor(height * ratio)

				dialog:modify {
					id = "width",
					text = width
				}
				dialog:modify {
					id = "width_percentage",
					text = width / original_width * 100
				}
			end
		end
	}

	dialog:separator { text = "Interpolation:" }

	dialog:combobox {
		id = "method",
		label = "Method:",
		option = "Nearest-neighbor",
		options = { "Nearest-neighbor", "Triangle", "CatmullRom", "Gaussian", "Lanczos3" },
	}

	dialog:button {
		focus = true,
		text = "&OK",
		onclick = function()
			local width = dialog.data.width
			local height = dialog.data.height
			local method = dialog.data.method

			if width < 3 or height < 3 then
				app.alert { title = "Warning", text = "Width and height must be at least 3 pixels" }
				return
			end

			if width == original_width and height == original_height then
				app.alert { title = "Warning", text = "Width and height must be different from the original size" }
				return
			end

			local alert = app.alert {
				title = "Warning",
				text = {
					"Resizing the DMI will re-open all open states",
					"without saving and this is irreversible. Continue?"
				},
				buttons = { "&OK", "&Cancel" }
			}

			if alert == 2 then
				return
			end

			dialog:close()

			if method == "Nearest-neighbor" then
				method = "nearest"
			elseif method == "Triangle" then
				method = "triangle"
			elseif method == "CatmullRom" then
				method = "catmullrom"
			elseif method == "Gaussian" then
				method = "gaussian"
			elseif method == "Lanczos3" then
				method = "lanczos3"
			end

			local _, error = libdmi.resize(self.dmi, width, height, method)

			if not error then
				self.dmi.width = width
				self.dmi.height = height
				self:reload_open_states()
			else
				app.alert { title = "Error", text = { "Failed to resize", error } }
			end
		end
	}

	dialog:button {
		text = "&Cancel",
		onclick = function()
			dialog:close()
		end
	}

	dialog:show()
end

--- Shows a dialog to crop the DMI file.
function Editor:crop()
	if not self.dmi then return end

	local original_width = self.dmi.width
	local original_height = self.dmi.height

	local dialog = Dialog {
		title = "Crop"
	}

	dialog:separator { text = "Size:" }

	dialog:number {
		id = "width",
		focus = true,
		label = "Width:",
		text = tostring(original_width),
		decimals = 0,
		onchange = function()
			local width = dialog.data.width
			local left = dialog.data.left

			if width > original_width then
				return
			end

			if dialog.data.center then
				left = math.floor((original_width - width) / 2)

				dialog:modify {
					id = "left",
					value = left
				}
			elseif left > original_width - width then
				dialog:modify {
					id = "left",
					value = original_width - width
				}
			end

			dialog:modify {
				id = "left",
				max = original_width - width
			}
		end
	}

	dialog:number {
		id = "height",
		label = "Height:",
		text = tostring(original_height),
		decimals = 0,
		onchange = function()
			local height = dialog.data.height
			local top = dialog.data.top

			if height > original_height then
				return
			end

			if dialog.data.center then
				top = math.floor((original_height - height) / 2)

				dialog:modify {
					id = "top",
					value = top
				}
			elseif top > original_height - height then
				dialog:modify {
					id = "top",
					value = original_height - height
				}
			end

			dialog:modify {
				id = "top",
				max = original_height - height
			}
		end
	}

	dialog:separator { text = "Offset:" }

	dialog:slider {
		id = "top",
		label = "Top:",
		value = 0,
		min = 0,
		max = 0,
		onchange = function()
			dialog:modify {
				id = "center",
				selected = false
			}
		end
	}

	dialog:slider {
		id = "left",
		label = "Left:",
		value = 0,
		min = 0,
		max = 0,
		onchange = function()
			dialog:modify {
				id = "center",
				selected = false
			}
		end
	}

	dialog:check {
		id = "center",
		label = "Center:",
		selected = true,
		onclick = function()
			local width = dialog.data.width
			local height = dialog.data.height
			local left = dialog.data.left
			local top = dialog.data.top

			if dialog.data.center then
				left = math.floor((original_width - width) / 2)
				top = math.floor((original_height - height) / 2)
			end

			dialog:modify {
				id = "left",
				value = left
			}
			dialog:modify {
				id = "top",
				value = top
			}
		end
	}

	dialog:button {
		focus = true,
		text = "&OK",
		onclick = function()
			local width = dialog.data.width
			local height = dialog.data.height
			local left = dialog.data.left
			local top = dialog.data.top

			if width < 3 or height < 3 then
				app.alert { title = "Warning", text = "Width and height must be at least 3 pixels" }
				return
			end

			if width > original_width or height > original_height or (width == original_width and height == original_height) then
				app.alert { title = "Warning", text = "Width and height must be less than the original size" }
				return
			end

			if left > original_width - width or top > original_height - height then
				app.alert { title = "Warning", text = "Offset must fit within the size" }
				return
			end

			local alert = app.alert {
				title = "Warning",
				text = {
					"Cropping the DMI will re-open all open states",
					"without saving and this is irreversible. Continue?"
				},
				buttons = { "&OK", "&Cancel" }
			}

			if alert == 2 then
				return
			end

			dialog:close()

			local _, error = libdmi.crop(self.dmi, left, top, width, height)

			if not error then
				self.dmi.width = width
				self.dmi.height = height
				self:reload_open_states()
			else
				app.alert { title = "Error", text = { "Failed to crop", error } }
			end
		end
	}

	dialog:button {
		text = "&Cancel",
		onclick = function()
			dialog:close()
		end
	}

	dialog:show()
end

function Editor:expand()
	if not self.dmi then return end

	local original_width = self.dmi.width
	local original_height = self.dmi.height

	local dialog = Dialog {
		title = "Expand"
	}

	dialog:separator { text = "Size:" }

	dialog:number {
		id = "width",
		focus = true,
		label = "Width:",
		text = tostring(original_width),
		decimals = 0,
		onchange = function()
			local width = dialog.data.width
			if width >= original_width then
				local left = dialog.data.left

				if dialog.data.anchor ~= "Custom" then
					if string.find(dialog.data.anchor, "middle") or dialog.data.anchor == "Center" then
						left = math.floor((width - original_width) / 2)
					elseif string.find(dialog.data.anchor, "left") then
						left = 0
					elseif string.find(dialog.data.anchor, "right") then
						left = width - original_width
					end
				end

				dialog:modify {
					id = "left",
					max = width - original_width,
					value = left
				}
			end
		end
	}

	dialog:number {
		id = "height",
		label = "Height:",
		text = tostring(original_height),
		decimals = 0,
		onchange = function()
			local height = dialog.data.height
			if height >= original_height then
				local top = dialog.data.top

				if dialog.data.anchor ~= "Custom" then
					if string.find(dialog.data.anchor, "Middle") or dialog.data.anchor == "Center" then
						top = math.floor((height - original_height) / 2)
					elseif string.find(dialog.data.anchor, "Top") then
						top = 0
					elseif string.find(dialog.data.anchor, "Bottom") then
						top = height - original_height
					end
				end

				dialog:modify {
					id = "top",
					max = height - original_height,
					value = top
				}
			end
		end
	}

	dialog:separator { text = "Anchor:" }

	dialog:slider {
		id = "top",
		label = "Top:",
		value = 0,
		min = 0,
		max = 0,
		onchange = function()
			dialog:modify {
				id = "anchor",
				option = "Custom"
			}
		end
	}

	dialog:slider {
		id = "left",
		label = "Left:",
		value = 0,
		min = 0,
		max = 0,
		onchange = function()
			dialog:modify {
				id = "anchor",
				option = "Custom"
			}
		end
	}

	dialog:combobox {
		id = "anchor",
		label = "Align:",
		option = "Center",
		options = { "Top-left", "Top-middle", "Top-right", "Middle-left", "Center", "Middle-right", "Bottom-left", "Bottom-middle", "Bottom-right", "Custom" },
		onchange = function()
			if dialog.data.anchor ~= "Custom" then
				local width = dialog.data.width
				local height = dialog.data.height
				local left = dialog.data.left
				local top = dialog.data.top

				if string.find(dialog.data.anchor, "middle") or dialog.data.anchor == "Center" then
					left = math.floor((width - original_width) / 2)
				elseif string.find(dialog.data.anchor, "left") then
					left = 0
				elseif string.find(dialog.data.anchor, "right") then
					left = width - original_width
				end

				if string.find(dialog.data.anchor, "Middle") or dialog.data.anchor == "Center" then
					top = math.floor((height - original_height) / 2)
				elseif string.find(dialog.data.anchor, "Top") then
					top = 0
				elseif string.find(dialog.data.anchor, "Bottom") then
					top = height - original_height
				end

				dialog:modify {
					id = "left",
					value = left
				}
				dialog:modify {
					id = "top",
					value = top
				}
			end
		end
	}

	dialog:button {
		focus = true,
		text = "&OK",
		onclick = function()
			local width = dialog.data.width
			local height = dialog.data.height
			local left = dialog.data.left
			local top = dialog.data.top

			if width < 3 or height < 3 then
				app.alert { title = "Warning", text = "Width and height must be at least 3 pixels" }
				return
			end

			if width < original_width or height < original_height or (width == original_width and height == original_height) then
				app.alert { title = "Warning", text = "Width and height must be greater than the original size" }
				return
			end

			local alert = app.alert {
				title = "Warning",
				text = {
					"Expanding the DMI will re-open all open states",
					"without saving and this is irreversible. Continue?"
				},
				buttons = { "&OK", "&Cancel" }
			}

			if alert == 2 then
				return
			end

			dialog:close()

			local _, error = libdmi.expand(self.dmi, left, top, width, height)

			if not error then
				self.dmi.width = width
				self.dmi.height = height
				self:reload_open_states()
			else
				app.alert { title = "Error", text = { "Failed to expand", error } }
			end
		end
	}

	dialog:button {
		text = "&Cancel",
		onclick = function()
			dialog:close()
		end
	}

	dialog:show()
end

--- Reloads all open states in the editor.
function Editor:reload_open_states()
	local open_states = {} --[[@type State[] ]]
	for _, state_sprite in ipairs(self.open_sprites) do
		if state_sprite.sprite then
			state_sprite.sprite:close()
			table.insert(open_states, state_sprite.state)
		end
	end

	self.open_sprites = {}
	self.image_cache:load_previews(self.dmi)
	self:repaint_states()

	for _, state in ipairs(open_states) do
		self:open_state(state)
	end
end
