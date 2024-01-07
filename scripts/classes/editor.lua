--- Editor is a class representing a DMI editor.
--- It provides functionality for editing DMI files.
--- @class Editor
--- @field title string The title of the editor.
--- @field canvas_width number The width of the canvas.
--- @field canvas_height number The height of the canvas.
--- @field max_in_a_row number The maximum number of states in a row.
--- @field max_in_a_column number The maximum number of states in a column.
--- @field focused_widget AnyWidget Widget The currently focused widget.
--- @field hovering_widgets AnyWidget[] A table containing all widgets that are currently being hovered by the mouse.
--- @field scroll number The current scroll position.
--- @field mouse Editor.Mouse The current mouse state.
--- @field dmi Dmi The currently opened DMI file.
--- @field open_sprites (StateSprite)[] A table containing all open sprites.
--- @field widgets (AnyWidget)[] A table containing all state widgets.
--- @field beforecommand number The event object for the "beforecommand" event.
--- @field aftercommand number The event object for the "aftercommand" event.
--- @field dialog Dialog The dialog object.
--- @field save_path string|nil The path of the file to be saved.
--- @field open_path string|nil The path of the file to be opened.
Editor = {}
Editor.__index = Editor

--- @class Editor.Mouse
--- @field position Point The current mouse position.
--- @field leftClick boolean Whether the left mouse button is pressed.

--- Creates a new instance of the Editor class.
--- @param title string The title of the editor.
--- @param filename string|nil The path of the file to be processed.
--- @param dmi Dmi|nil The DMI object to be opened if not passed `filename` or `Editor.open_path` will be used.
--- @return Editor editor  The newly created Editor instance.
function Editor.new(title, filename, dmi)
	local self            = setmetatable({}, Editor)

	self.title            = title
	self.focused_widget   = nil
	self.hovering_widgets = {}
	self.scroll           = 0
	self.mouse            = { position = Point(0, 0), leftClick = false }
	self.dmi              = nil
	self.open_sprites     = {}
	self.widgets          = {}
	self.save_path        = nil
	self.open_path        = filename or nil

	self.canvas_width     = 185
	self.canvas_height    = 215
	self.max_in_a_row     = 1
	self.max_in_a_column  = 1

	self.beforecommand    = app.events:on("beforecommand", function(ev) self:onbeforecommand(ev) end)

	self.aftercommand     = app.events:on("aftercommand", function(ev) self:onaftercommand(ev) end)

	self.dialog           = Dialog {
		title = title,
		onclose = function() self:onclose() end
	}

	self.dialog:canvas {
		width = self.canvas_width,
		height = self.canvas_height,
		onpaint = function(ev) self:onpaint(ev.context) end,
		onmousedown = function(ev) self:onmousedown(ev) end,
		onmouseup = function(ev) self:onmouseup(ev) end,
		onmousemove = function(ev) self:onmousemove(ev) end,
		onwheel = function(ev) self:onwheel(ev) end
	}

	self.dialog:button {
		text = "Save",
		onclick = function() self:save() end
	}

	if filename then
		self:show()
		self:open_file()
	elseif dmi then
		self:show()
		self:open_file(dmi)
	end

	return self
end

--- Function to handle the "onclose" event of the Editor class.
--- Cleans up resources and closes sprites when the editor is closed.
function Editor:onclose()
	if self.dmi then
		lib:remove_dir(self.dmi.temp)
	end

	for _, state_sprite in ipairs(self.open_sprites) do
		if state_sprite.sprite then
			state_sprite.sprite:close()
		end
	end

	app.events:off(self.beforecommand)
	app.events:off(self.aftercommand)

	self.mouse = nil
	self.focused_widget = nil
	self.dialog = nil
	self.widgets = nil
	self.dmi = nil
	self.open_sprites = nil
	self.beforecommand = nil
	self.aftercommand = nil
end

--- Opens a DMI file and displays it in the editor.
--- @param dmi Dmi|nil The DMI object to be opened if not passed `Editor.open_path` will be used.
function Editor:open_file(dmi)
	local success = true
	local dmi_ = dmi

	if not dmi then
		local success, _, _, _, dmi = lib:open(self.open_path)
		if success then
			dmi_ = dmi
		end
	end

	if self.dmi then
		lib:remove_dir(self.dmi.temp)
	end

	for _, state_sprite in ipairs(self.open_sprites) do
		state_sprite.sprite:close()
	end

	image_cache:clear()

	self.scroll = 0
	self.dmi = nil
	self.widgets = {}
	self.open_sprites = {}
	self.save_path = nil

	self:repaint()

	if success then
		self.dmi = dmi_ --[[@as Dmi]]
		image_cache:load_previews(self.dmi)
		self:repaint_states()
	end
end

local text_height = 0
local box_border = 4
local box_padding = 5

--- This function is called when the editor needs to repaint its contents.
--- @param ctx GraphicsContext The drawing context used to draw on the editor canvas.
function Editor:onpaint(ctx)
	local min_width = self.dmi and (self.dmi.width + box_padding) or 1
	local min_height = self.dmi and (self.dmi.height + box_border + box_padding * 2 + text_height) or 1

	self.canvas_width = ctx.width > min_width and ctx.width or min_width
	self.canvas_height = ctx.height > min_height and ctx.height or min_height

	if text_height == 0 then
		text_height = ctx:measureText("A").height
	end

	local max_row = self.dmi and math.floor(self.canvas_width / min_width) or 1
	local max_column = self.dmi and math.floor(self.canvas_height / min_height) or 1

	if max_row ~= self.max_in_a_row or max_column ~= self.max_in_a_column then
		self.max_in_a_row = max_row > 0 and max_row or 1
		self.max_in_a_column = max_column > 0 and max_column or 1
		self:repaint_states()
		return
	end

	local hovers = {} --[[ @as (string)[] ]]
	for _, widget in ipairs(self.widgets) do
		if widget and widget.state then
			local state = widget.state.normal

			if widget == self.focused_widget then
				state = widget.state.focused or state
			end

			local is_mouse_over = widget.bounds:contains(self.mouse.position)

			if is_mouse_over then
				state = widget.state.hot or state

				if self.mouse.leftClick then
					state = widget.state.selected or state
				end
			end

			if widget.type == "IconWidget" then
				local widget = widget --[[ @as IconWidget ]]

				ctx:drawThemeRect(state.part, widget.bounds)

				local center = Point(
					widget.bounds.x + widget.bounds.width / 2,
					widget.bounds.y + widget.bounds.height / 2
				)

				local size = Rectangle(0, 0, self.dmi.width, self.dmi.height)
				local icon = widget.icon:clone()

				-- https://community.aseprite.org/t/unable-to-draw-to-transparent-image-to-dlg-canvas/19406
				-- Aseprite messes up the alpha channel of the image when drawing it to the canvas

				for pixel in icon:pixels() do
					local color = Color(pixel())
					if color.alpha == 0 then
						pixel(app.pixelColor.rgba(0, 0, 0, 0))
					elseif color.alpha < 255 then
						pixel(app.pixelColor.rgba(color.red, color.green, color.blue, 255))
					end
				end

				-- ctx:drawImage(icon, center.x - size.width / 2, center.y - size.height / 2)

				ctx:drawImage(
					icon,
					icon.bounds,
					Rectangle(center.x - size.width / 2, center.y - size.height / 2, icon.bounds.width,
						icon.bounds.height)
				)
			elseif widget.type == "TextWidget" then
				local widget = widget --[[ @as TextWidget ]]
				local text = fit_text(widget.text, ctx, widget.bounds.width)
				local size = ctx:measureText(text)

				ctx.color = widget.text_color or app.theme.color[state.color]
				ctx:fillText(
					text,
					widget.bounds.x + widget.bounds.width / 2 - size.width / 2,
					widget.bounds.y + widget.bounds.height / 2 - size.height / 2
				)

				if is_mouse_over and widget.hover_text then
					table.insert(hovers, widget.hover_text)
				end
			elseif widget.type == "ThemeWidget" then
				local widget = widget --[[ @as ThemeWidget ]]
				ctx:drawThemeRect(state.part, widget.bounds)

				local center = Point(
					widget.bounds.x + widget.bounds.width / 2,
					widget.bounds.y + widget.bounds.height / 2
				)

				if widget.partId then
					ctx:drawThemeImage(widget.partId,
						Rectangle(center.x - widget.bounds.width / 2, center.y - widget.bounds.height / 2, widget.bounds.width,
							widget.bounds.height))
				end
			end
		end
	end
	for _, text in ipairs(hovers) do
		local text_size = ctx:measureText(text)
		local size = Size(text_size.width + box_padding * 2, text_size.height + box_padding * 2)
		ctx.color = app.theme.color["button_normal_text"]
		ctx:drawThemeRect("sunken_normal",
			Rectangle(self.mouse.position.x - size.width / 2, self.mouse.position.y - size.height,
				size.width, size.height))
		ctx:fillText(text, self.mouse.position.x - text_size.width / 2,
			self.mouse.position.y - text_size.height / 2 - size.height / 2)
	end
end

--- Handles the mouse down event in the editor and triggers a repaint.
--- @param ev table The mouse event object.
function Editor:onmousedown(ev)
	if ev.button == MouseButton.LEFT then
		self.mouse.leftClick = true
		self.focused_widget = nil
	end
	self:repaint()
end

--- Handles the mouse up event in the editor and triggers a repaint.
--- @param ev table The mouse event object.
function Editor:onmouseup(ev)
	if ev.button == MouseButton.LEFT then
		if self.mouse.leftClick then
			for _, widget in ipairs(self.widgets) do
				local is_mouse_over = widget.bounds:contains(self.mouse.position)
				if is_mouse_over then
					if widget.onmouseup then
						widget.onmouseup()
					end
					self.focused_widget = widget
				end
			end
			self.mouse.leftClick = false
		end
	end
	self:repaint()
end

--- Updates the mouse position and triggers a repaint.
--- @param ev table The mouse event containing the x and y coordinates.
function Editor:onmousemove(ev)
	local mouse_position = Point(ev.x, ev.y)
	local should_repaint = false
	--- @type AnyWidget[]
	local hovering_widgets = {}

	for _, widget in ipairs(self.widgets) do
		if widget.bounds:contains(mouse_position) then
			table.insert(hovering_widgets, widget)
		end
	end

	for _, widget in ipairs(self.hovering_widgets) do
		if table.index_of(hovering_widgets, widget) == 0 or widget.hover_text then
			should_repaint = true
			break
		end
	end

	if not should_repaint then
		for _, widget in ipairs(hovering_widgets) do
			if table.index_of(self.hovering_widgets, widget) == 0 or widget.hover_text then
				should_repaint = true
				break
			end
		end
	end

	self.mouse.position = mouse_position
	self.hovering_widgets = hovering_widgets

	if should_repaint then
		self:repaint()
	end
end

--- Handles the mouse wheel event for scrolling through DMI states.
--- @param ev table The mouse wheel event object.
function Editor:onwheel(ev)
	if not self.dmi or not self.dmi.states then return end

	local overflow = (#self.dmi.states + 1) - self.max_in_a_row * self.max_in_a_column

	if not (overflow > 0) then return end

	local last_digit = overflow % self.max_in_a_row
	local rounded = overflow - last_digit

	if last_digit > 0 then
		rounded = rounded + self.max_in_a_row
	end

	local max_scroll = math.floor(rounded / self.max_in_a_row)
	local new_scroll = math.min(math.max(self.scroll + (ev.deltaY > 0 and 1 or -1), 0), max_scroll)

	if new_scroll ~= self.scroll then
		self.scroll = new_scroll
		self:repaint_states()
	end
end

--- This function is called before executing a command in the Aseprite editor. It checks the event name and performs specific actions based on the event type.
--- @param ev table The event object containing information about the event.
function Editor:onbeforecommand(ev)
	if ev.name == "SaveFile" then
		for _, state_sprite in ipairs(self.open_sprites) do
			if app.sprite == state_sprite.sprite then
				if not state_sprite:save() then
					ev.stopPropagation()
				end
				break
			end
		end
	elseif ev.name == "SpriteSize" then
		for _, state_sprite in ipairs(self.open_sprites) do
			if app.sprite == state_sprite.sprite then
				ev.stopPropagation()
				app.alert { title = self.title, text = "Changing sprite size is not supported yet" }
				break
			end
		end
	elseif ev.name == "CanvasSize" then
		for _, state_sprite in ipairs(self.open_sprites) do
			if app.sprite == state_sprite.sprite then
				ev.stopPropagation()
				app.alert { title = self.title, text = "Changing canvas size is not supported yet" }
				break
			end
		end
	else
		-- print(json.encode(ev))
	end
end

--- Callback function called after a Aseprite command is executed.
--- @param ev table The event object containing information about the command.
function Editor:onaftercommand(ev)

end

--- Repaints the editor.
function Editor:repaint()
	self.dialog:repaint()
end

--- Repaints the states in the editor.
--- Creates state widgets for each state in the DMI file and positions them accordingly.
--- Only creates state widgets for states that are currently visible based on the scroll position.
--- Calls the repaint function to update the editor display.
function Editor:repaint_states()
	self.widgets = {}
	local duplicates = {}
	for index, state in ipairs(self.dmi.states) do
		if index > (self.max_in_a_row * self.scroll) then
			local bounds = self:box_bounds(index)
			local text_color = nil

			if not (#state.name > 0) then
				text_color = Color { red = 230, green = 223, blue = 69, alpha = 255 }
			end

			if duplicates[state.name] then
				text_color = Color { red = 230, green = 69, blue = 69, alpha = 255 }
			else
				for _, state_ in ipairs(self.dmi.states) do
					if state.name == state_.name then
						duplicates[state.name] = true
						break
					end
				end
			end

			local name = #state.name > 0 and state.name or "no name"

			table.insert(self.widgets, IconWidget.new(
				self,
				bounds,
				{
					normal = { part = "sunken_normal", color = "button_normal_text" },
					hot = { part = "sunken_focused", color = "button_hot_text" },
				},
				image_cache:get(state.frame_key),
				function() self:open_state(state) end
			))

			table.insert(self.widgets, TextWidget.new(
				self,
				Rectangle(
					bounds.x,
					bounds.y + bounds.height + box_padding,
					bounds.width,
					text_height
				),
				{
					normal = { part = "sunken_normal", color = "button_normal_text" },
					hot = { part = "sunken_focused", color = "button_hot_text" },
				},
				name,
				text_color,
				name,
				function() self:state_properties(state) end
			))
		end
	end

	local index = #self.dmi.states + 1
	local bounds = self:box_bounds(index)

	table.insert(self.widgets, ThemeWidget.new(
		self,
		bounds,
		{
			normal = { part = "sunken_normal", color = "button_normal_text" },
			hot = { part = "sunken_focused", color = "button_hot_text" },
		},
		nil,
		function() self:new_state() end
	))

	table.insert(self.widgets, TextWidget.new(
		self,
		Rectangle(
			bounds.x,
			bounds.y + bounds.height / 2 - 3,
			bounds.width,
			text_height
		),
		{
			normal = { part = "sunken_normal", color = "button_normal_text" },
			hot = { part = "sunken_focused", color = "button_hot_text" },
		},
		"+"
	))

	self:repaint()
end

function Editor:box_bounds(index)
	local row_index = index - self.max_in_a_row * self.scroll

	return Rectangle(
		(self.dmi.width + box_padding) * ((row_index - 1) % self.max_in_a_row),
		(self.dmi.height + box_border + box_padding * 2 + text_height) * math.floor((row_index - 1) / self.max_in_a_row) +
		box_padding,
		self.dmi.width + box_border,
		self.dmi.height + box_border
	)
end

--- Opens a state in the Aseprite editor by creating a new sprite and populating it with frames and layers based on the provided state.
---@param state State The state to be opened.
function Editor:open_state(state)
	for _, sprite in ipairs(app.sprites) do
		if sprite.filename == app.fs.joinPath(self.dmi.temp, state.frame_key .. ".ase") then
			return
		end
	end

	local preview_image = image_cache:get(state.frame_key)
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
					index == 1 and image_cache:get(state.frame_key) or
					Image { fromFile = app.fs.joinPath(self.dmi.temp, state.frame_key .. "." .. math.floor(index - 1) .. ".png") },
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

function Editor:remove_nil_statesprites()
	for index, state_sprite in ipairs(self.open_sprites) do
		if not state_sprite.sprite or not state_sprite.state then
			table.remove(self.open_sprites, index)
		end
	end
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
		text = "Remove",
		onclick = function()
			for i, state_sprite in ipairs(self.open_sprites) do
				if state_sprite.state == state then
					state_sprite.sprite:close()
					table.remove(self.open_sprites, i)
					break
				end
			end

			table.remove(self.dmi.states, table.index_of(self.dmi.states, state))
			image_cache:remove(state.frame_key)
			self:repaint_states()
			dialog:close()
		end,
	}

	dialog:button {
		text = "Cancel",
		onclick = function()
			dialog:close()
		end
	}

	dialog:show()
end

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
									image:drawImage(image_cache:get(state.frame_key), Point(0, 0))
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

function Editor:new_state()
	local success, _, _, _, state = lib:new_state(self.dmi)
	if success then
		table.insert(self.dmi.states, state)
		image_cache:load_state(self.dmi, state --[[@as State]])
		self:repaint_states()
	end
end

--- Reorders the layers in the state_sprite based on their names.
--- Layers with names found in DIRECTION_NAMES are placed in reverse order,
--- while other layers are placed after the direction layers.
--- @param state_sprite StateSprite The sprite containing the layers to be reordered.
function Editor:reorder_layers(state_sprite)
	local dir_layers = {}
	local other_layers = {}
	for _, layer in ipairs(state_sprite.sprite.layers) do
		local index = table.index_of(DIRECTION_NAMES, layer.name)
		if index ~= 0 then
			dir_layers[index] = layer
		else
			table.insert(other_layers, layer)
		end
	end
	for i = 1, #dir_layers, 1 do
		dir_layers[i].stackIndex = #dir_layers - i + 1
	end
	for i = 1, #other_layers, 1 do
		other_layers[i].stackIndex = #dir_layers + i
	end
	state_sprite.sprite:deleteLayer(state_sprite.sprite:newLayer())
end

--- Saves the current DMI file.
--- If the DMI file is not set, the function returns without doing anything.
--- Displays a success or failure message using the Aseprite app.alert function.
function Editor:save()
	if not self.dmi then return end

	local save_dialog = Dialog {
		title = "Save File",
		parent = self.dialog
	}

	save_dialog:file {
		id = "save_dmi_file",
		save = true,
		filetypes = { "dmi" },
		filename = self.save_path or self.open_path or app.fs.joinPath(app.fs.userDocsPath, "untitled.dmi"),
		onchange = function()
			self.save_path = save_dialog.data["save_dmi_file"]
			save_dialog:close()
			self:save()
		end,
	}

	save_dialog:label {
		text = save_dialog.data["save_dmi_file"],
	}

	save_dialog:button {
		text = "Save",
		onclick = function()
			local success = lib:save(self.dmi, save_dialog.data["save_dmi_file"])

			if not success then
				app.alert { title = "Save File", text = "Failed to save" }
			end

			save_dialog:close()
		end
	}

	save_dialog:button {
		text = "Cancel",
		onclick = function()
			save_dialog:close()
		end
	}

	save_dialog:show()
end

--- Shows the editor dialog.
function Editor:show()
	self.dialog:show { wait = false }
end
