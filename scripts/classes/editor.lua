--- @class Editor: table
--- @field filename string The filename of the DMI file.
--- @field dmi Dmi The DMI object.
--- @field width integer The width of the editor.
--- @field height integer The height of the editor.
--- @field widgets Widget[] The widgets to be shown in the dialog.
--- @field hovered_widgets Widget[] The widgets that are currently hovered by the mouse.
--- @field max_rows integer The maximum amount of rows to show in the editor.
--- @field max_cols integer The maximum amount of columns to show in the editor.
--- @field mouse Mouse The mouse object.
--- @field open_sprites Editor.Sprite[] The sprites that are currently open in the Aseprite editor.
--- @field before_command number The listener for the beforecommand event.
--- @field recreate_widgets boolean Whether the widgets should be recreated.
--- @field dialog Dialog The dialog object.
Editor = {}
Editor.__index = Editor

--- @alias Editor.Sprite { state: State, sprite: Sprite }

--- The space between the edge of the editor and the canvas.
local CANVAS_PADDING = 1

--- Extra padding to fit the image inside the sunken rectangle.
local SUNKEN_PADDING = 4

--- The space between the columns of the widgets.
local COLUMN_SPACE = 1

--- The base height of the text below the widgets.
local TEXT_HEIGHT = 5

--- The padding above the text below the widgets.
local TEXT_PADDING_TOP = 5

--- The padding below the text below the widgets.
local TEXT_PADDING_BOTTOM = 7

--- The padding around the hovered text.
local HOVERED_TEXT_PADDING = 5

--- Calculates the width of the editor based on the width of the states.
--- @param width integer The width of the states.
--- @param cols integer The amount of columns.
--- @return integer width The width of the editor.
local WIDTH = function(width, cols)
	return cols * (width + SUNKEN_PADDING + COLUMN_SPACE) - COLUMN_SPACE + CANVAS_PADDING * 2
end

--- Calculates the height of the editor based on the height of the states.
--- @param height integer The height of the states.
--- @param rows integer The amount of rows.
--- @return integer height The height of the editor.
local HEIGHT = function(height, rows)
	return rows * (height + SUNKEN_PADDING + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) -
			math.floor(TEXT_PADDING_BOTTOM / 2) + CANVAS_PADDING * 2
end

--- Calculates the amount of columns that can fit in the editor based on the width of the states.
--- @param width integer The width of the editor.
--- @param dmi_width integer The width of the states.
--- @return integer cols The amount of columns that can fit in the editor.
local REVERSE_WIDTH = function(width, dmi_width)
	return math.floor((width + COLUMN_SPACE - CANVAS_PADDING * 2) / (dmi_width + SUNKEN_PADDING + COLUMN_SPACE))
end

--- Calculates the amount of rows that can fit in the editor based on the height of the states.
--- @param height integer The height of the editor.
--- @param dmi_height integer The height of the states.
--- @return integer rows The amount of rows that can fit in the editor.
local REVERSE_HEIGHT = function(height, dmi_height)
	return math.floor((height - TEXT_PADDING_BOTTOM / 2 - CANVAS_PADDING * 2) /
		(dmi_height + SUNKEN_PADDING + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM))
end

--- The default width for a 32x?? DMI file.
local DEFAULT_WIDTH = WIDTH(32, 5)

--- The default height for a ??x32 DMI file.
local DEFAULT_HEIGHT = HEIGHT(32, 4)

function Editor.__call(self, filename)
	local self = setmetatable({}, getmetatable(self)) --[[@as Editor]]

	self.filename = filename
	self.dmi = assert(libdmi.open(filename))
	self:default_size()
	self.widgets = {}
	self.hovered_widgets = {}
	self.max_rows = 0
	self.max_cols = 0
	self.mouse = Mouse()
	self.open_sprites = {}
	self.before_command = app.events:on("beforecommand", function(ev) self:on_before_command(ev --[[@as BeforeEvent]]) end)
	self.recreate_widgets = true
	self.dialog = self:create_dialog()

	return self
end

--- Calculates and sets the default size for the editor.
function Editor:default_size()
	if not self.dmi then return end

	local max_width = app.window.width * 0.8
	local max_height = app.window.height * 0.8

	if self.dmi.width < max_width then
		local width = WIDTH(self.dmi.width, 4)
		if width < max_width then
			self.width = width > DEFAULT_WIDTH and width or DEFAULT_WIDTH
		else
			local width = self.dmi.width + SUNKEN_PADDING + CANVAS_PADDING * 2
			self.width = width > DEFAULT_WIDTH and (width < max_width and width or max_width) or DEFAULT_WIDTH
		end
	else
		self.width = max_width
	end

	if self.dmi.height < max_height then
		local height = HEIGHT(self.dmi.height, 5)
		self.height = height < max_height and (height > DEFAULT_HEIGHT and height or DEFAULT_HEIGHT) or max_height
	else
		self.height = max_height
	end
end

--- Creates the dialog for the editor.
--- @return Dialog dialog The dialog object.
function Editor:create_dialog()
	local dialog = Dialog {
		title = "Editor",
		onclose = function() self:on_close() end,
	}

	dialog:canvas {
		width = self.width,
		height = self.height,
		onpaint = function(ev) self:on_paint(ev.context) end,
		onmousemove = function(ev) self:on_mouse_move(ev) end,
		onmousedown = function(ev) self:on_mouse_down(ev) end,
		onmouseup = function(ev) self:on_mouse_up(ev) end,
	}

	dialog:button {
		text = "Save",
		onclick = function() end,
	}

	dialog:show { wait = false }

	return dialog
end

--- Checks if a widget is of a certain type.
--- @param widget Widget The widget to check.
--- @param type any The type to check against.
--- @return boolean Returns true if the widget is of the specified type, false otherwise.
local is_widget = function(widget, type)
	return widget.__index == getmetatable(type)
end

--- Handles the paint event in the editor and draws the widgets and other elements.
--- @param ctx GraphicsContext
function Editor:on_paint(ctx)
	self.width = ctx.width
	self.height = ctx.height

	local max_rows = math.max(REVERSE_HEIGHT(self.height, self.dmi.height) + 1, 2)
	local max_cols = math.max(REVERSE_WIDTH(self.width, self.dmi.width), 1)

	local needs_reposition = false

	if max_rows ~= self.max_rows or max_cols ~= self.max_cols then
		self.max_rows = max_rows
		self.max_cols = max_cols
		needs_reposition = true
		if #self.dmi.states > max_rows * max_cols then
			self.recreate_widgets = true
		end
	end

	if self.recreate_widgets then
		self:create_widgets(ctx)
		needs_reposition = true
	end

	local hovered_texts = {} --[[@type TextWidget[] ]]

	local index = 0
	local prev_x = 0
	local prev_y = 0
	local prev_width = 0
	local prev_height = 0

	for _, widget in ipairs(self.widgets) do
		if is_widget(widget, ImageWidget) then
			local widget = widget --[[@as ImageWidget]]

			if needs_reposition then
				local x = (widget.width + COLUMN_SPACE) * (index % self.max_cols) + CANVAS_PADDING
				local y = (widget.height + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) *
						math.floor(index / self.max_cols) + CANVAS_PADDING

				widget.x = x
				widget.y = y

				index = index + 1
				prev_x = x
				prev_y = y
				prev_width = widget.width
				prev_height = widget.height
			end

			local part_id = table.contains(self.hovered_widgets, widget) and "sunken_focused" or "sunken_normal"
			ctx:drawThemeRect(part_id, widget.x, widget.y, widget.image.width + SUNKEN_PADDING,
				widget.image.height + SUNKEN_PADDING)
			ctx:drawImage(widget.image, widget.x + SUNKEN_PADDING / 2, widget.y + SUNKEN_PADDING / 2)
		elseif is_widget(widget, TextWidget) then
			local widget = widget --[[@as TextWidget]]

			if needs_reposition then
				widget.x = prev_x + (prev_width - ctx:measureText(widget.text).width) / 2
				widget.y = prev_y + prev_height + TEXT_PADDING_TOP
				widget.hovered_x = prev_x
			end

			ctx.color = widget.color
			ctx:fillText(widget.text, widget.x, widget.y)
			if table.contains(self.hovered_widgets, widget) then
				table.insert(hovered_texts, widget)
			end
		end
	end

	for _, widget in ipairs(hovered_texts) do
		local text_size = ctx:measureText(widget.hovered_text)
		local rect_size = Size(text_size.width + HOVERED_TEXT_PADDING * 2, text_size.height + HOVERED_TEXT_PADDING * 2)
		local x = self.mouse.x - rect_size.width / 2
		x = x > 0 and (x + rect_size.width > self.width and self.width - rect_size.width or x) or 0
		ctx.color = app.theme.color.text
		ctx:drawThemeRect("sunken_normal", x, self.mouse.y - rect_size.height, rect_size.width, rect_size.height)
		ctx:fillText(widget.hovered_text, x + HOVERED_TEXT_PADDING, self.mouse.y - (text_size.height + rect_size.height) / 2)
	end
end

--- Fits the text to the maximum width by ellipsizing it.
--- @param ctx GraphicsContext
--- @param text string
--- @param max_width integer
local fit_text = function(ctx, text, max_width)
	local width = ctx:measureText(text).width
	while width > max_width do
		if text:ends_with("...") then
			text = text:sub(1, text:len() - 4) .. "..."
		else
			text = text:sub(1, text:len() - 1) .. "..."
		end
		width = ctx:measureText(text).width
	end
	return text
end

--- Creates the widgets to be shown in the dialog.
--- @param ctx GraphicsContext The graphics context object.
function Editor:create_widgets(ctx)
	for _ = 1, #self.widgets, 1 do
		table.remove(self.widgets, 1)
	end

	local width = self.dmi.width
	local height = self.dmi.height

	local widget_width = width + SUNKEN_PADDING
	local widget_height = height + SUNKEN_PADDING

	local max_index = self.max_rows * self.max_cols;

	for index, state in ipairs(self.dmi.states) do
		if index > max_index then break end

		local background_color = app.theme.color.face

		local image = Image(width, height)
		image.bytes = state:preview(background_color.red, background_color.green, background_color.blue)

		--- @param widget ImageWidget
		--- @param ev MouseEvent
		local on_click = function(widget, ev)
			if ev.button == MouseButton.LEFT then
				self:open_state(state)
			end
		end

		local widget = ImageWidget(image, widget_width, widget_height, on_click)

		table.insert(self.widgets, widget)

		local text = fit_text(ctx, state.name, widget_width - SUNKEN_PADDING / 2)
		local size = ctx:measureText(text)

		local widget = TextWidget(text, app.theme.color.text, width, size.height, state.name, widget_width)

		table.insert(self.widgets, widget)
	end

	self.recreate_widgets = false
end

--- Handles the mouse down event in the editor and triggers a repaint.
--- @param ev MouseEvent The mouse event object.
function Editor:on_mouse_move(ev)
	local needs_repaint = false
	local hovered_widgets = {} --[[@type Widget[] ]]

	for _, widget in ipairs(self.widgets) do
		local bounds = Rectangle(widget.x, widget.y, widget.width, widget.height)

		if is_widget(widget, ImageWidget) then
			bounds.x = bounds.x + SUNKEN_PADDING / 2
			bounds.y = bounds.y + SUNKEN_PADDING / 2
			bounds.width = bounds.width - SUNKEN_PADDING / 2
			bounds.height = bounds.height - SUNKEN_PADDING / 2
		elseif is_widget(widget, TextWidget) then
			local widget = widget --[[@as TextWidget]]
			bounds.x = widget.hovered_x
			bounds.width = widget.hovered_width
		end

		if bounds:contains(Point(ev.x, ev.y)) then
			table.insert(hovered_widgets, widget)
		end
	end

	for _, widget in ipairs(self.hovered_widgets) do
		if not table.contains(hovered_widgets, widget) or is_widget(widget, TextWidget) then
			needs_repaint = true
			break
		end
	end

	if not needs_repaint then
		for _, widget in ipairs(hovered_widgets) do
			if not table.contains(self.hovered_widgets, widget) or is_widget(widget, TextWidget) then
				needs_repaint = true
				break
			end
		end
	end

	self.mouse.x = ev.x
	self.mouse.y = ev.y
	self.hovered_widgets = hovered_widgets

	if needs_repaint then self.dialog:repaint() end
end

--- Handles the mouse down event in the editor.
--- @param ev MouseEvent The mouse event object.
function Editor:on_mouse_down(ev)
	if ev.button == MouseButton.Left then
		self.mouse.left = true
	elseif ev.button == MouseButton.Right then
		self.mouse.right = true
	end
end

--- Handles the mouse up event in the editor.
--- @param ev MouseEvent The mouse event object.
function Editor:on_mouse_up(ev)
	if ev.button == MouseButton.LEFT or ev.button == MouseButton.RIGHT then
		for _, widget in ipairs(self.widgets) do
			local bounds = Rectangle(widget.x, widget.y, widget.width, widget.height)
			if bounds:contains(Point(ev.x, ev.y)) and widget.on_click then
				widget:on_click(ev)
			end
		end
	end

	if ev.button == MouseButton.Left then
		self.mouse.left = false
	elseif ev.button == MouseButton.Right then
		self.mouse.right = false
	end
end

--- Handles the close event in the editor.
function Editor:on_close()
	for _, sprite in ipairs(self.open_sprites) do
		sprite.sprite:close()
	end
end

local DIRECTION_NAMES = { "South", "North", "East", "West", "Southeast", "Southwest", "Northeast", "Northwest" }

--- Loads the palette of the sprite while filtering out the transparent color. If the palette is empty, the default palette is loaded.
--- @param sprite Sprite
local load_palette = function(sprite)
	for _, cel in ipairs(sprite.cels) do
		if not cel.image:isEmpty() then
			app.command.ColorQuantization { ui = false, withAlpha = false }
			local palette = sprite.palettes[1]

			if palette:getColor(0).alpha == 0 then
				if #palette > 1 then
					local colors = {} --[[ @type Color[] ]]
					for i = 1, #palette - 1, 1 do
						table.insert(colors, palette:getColor(i))
					end
					local palette = Palette(#colors)
					for i, color in ipairs(colors) do
						palette:setColor(i - 1, color)
					end
					sprite:setPalette(palette)
				else
					app.command.LoadPalette { ui = false, preset = "default" }
				end
			end

			return
		end
	end

	app.command.LoadPalette { ui = false, preset = "default" }
end

--- Switches the tab to the sprite containing the state.
--- @param sprite Sprite The sprite to be opened.
local switch_tab = function(sprite)
	for _ = 0, #app.sprites + 1, 1 do
		if app.sprite ~= sprite then
			app.command.GotoNextTab()
		else
			break
		end
	end
end

--- Checks if a state is open in the Aseprite editor.
--- @param state State The state to check.
--- @return Sprite? sprite The sprite containing the state, or nil if the state is not open.
function Editor:is_state_open(state)
	self:cleanup_sprites()
	for _, sprite in ipairs(self.open_sprites) do
		if sprite.state == state then
			return sprite.sprite
		end
	end
end

--- Saves the sprite to a file and removes the temporary file.
--- @param sprite Sprite The sprite to save.
local fake_save = function(sprite)
	local filename = sprite.filename
	sprite:saveAs(app.fs.joinPath(PLUGIN_PATH, filename .. ".ase"))
	libdmi.remove_file(sprite.filename)
	sprite.filename = filename
end

--- Opens a state in the Aseprite editor by creating a new sprite and populating it with frames and layers based on the provided state.
--- @param state State The state to open.
function Editor:open_state(state)
	local sprite = self:is_state_open(state)
	if sprite then
		switch_tab(sprite)
		return
	end

	local sprite = Sprite(self.dmi.width, self.dmi.height)
	sprite.filename = state.name

	app.transaction("Load State", function()
		while #sprite.layers < state.dirs do
			sprite:newLayer().isVisible = false
		end

		local frame_count = state.frame_count
		if frame_count > 1 then
			sprite:newFrame(frame_count - 1)
		end

		local delays = state.delays
		if #delays > 1 then
			for i, frame in ipairs(sprite.frames) do
				frame.duration = (delays[i] or 1) / 10
			end
		end

		sprite.layers[1].isVisible = false
		sprite.layers[#sprite.layers].isVisible = true

		local index = 1
		for frame = 1, #sprite.frames, 1 do
			for layer = #sprite.layers, 1, -1 do
				local name = DIRECTION_NAMES[#sprite.layers - layer + 1]
				local layer = sprite.layers[layer]
				local frame = sprite.frames[frame]

				local image = Image(self.dmi.width, self.dmi.height)
				image.bytes = state:frame(index - 1)

				layer.name = name
				sprite:newCel(layer, frame, image, Point(0, 0))

				index = index + 1
			end
		end

		app.frame = 1
		load_palette(sprite)
		app.command.FitScreen()
	end)

	fake_save(sprite)

	self:cleanup_sprites()
	table.insert(self.open_sprites, { state = state, sprite = sprite })
end

--- Checks if a sprite is open in the Aseprite editor.
--- @param sprite Sprite The sprite to check.
--- @return boolean boolean Returns true if the sprite is open, false otherwise.
local is_sprite_open = function(sprite)
	for _, open in ipairs(app.sprites) do
		if open == sprite then
			return true
		end
	end
	return false
end

--- Removes the open sprites that are no longer open in the Aseprite editor.
function Editor:cleanup_sprites()
	for i, sprite in ipairs(self.open_sprites) do
		if not is_sprite_open(sprite.sprite) then
			table.remove(self.open_sprites, i)
		end
	end
end

--- Checks if a sprite is bound to this editor.
--- @param sprite Sprite The sprite to check.
--- @return Editor.Sprite? open_sprite The open sprite, or nil if the sprite is not open.
function Editor:is_our_sprite(sprite)
	for _, open_sprite in ipairs(self.open_sprites) do
		if open_sprite.sprite == sprite then
			return open_sprite
		end
	end
end

--- Handles the before command event in the editor.
--- @param ev BeforeEvent The event object.
function Editor:on_before_command(ev)
	if ev.name == "SaveFile" then
		local sprite = self:is_our_sprite(app.sprite)
		if sprite then
			self:save_sprite(sprite)
			ev.stopPropagation()
		end
	end
end

--- Returns the correct verb for the amount.
--- @param count integer The amount to check.
--- @return string verb The correct verb for the amount.
local is_are = function(count)
	return count == 1 and "is" or "are"
end

--- Saves the sprite to the state.
--- @param sprite Editor.Sprite The sprite to save.
--- @return boolean Returns true if the sprite was saved, false otherwise.
function Editor:save_sprite(sprite)
	local matches = {} --[[ @type table<string, boolean> ]]
	local duplicates = {} --[[ @type string[] ]]

	for _, layer in ipairs(sprite.sprite.layers) do
		local dir = table.index_of(DIRECTION_NAMES, layer.name)
		if dir ~= 0 and dir <= sprite.state.dirs then
			if matches[layer.name] then
				table.insert(duplicates, layer.name)
			else
				matches[layer.name] = true
			end
		end
	end

	if table.length(matches) ~= sprite.state.dirs then
		local missing = {} --[[ @type string[] ]]
		for i = 1, sprite.state.dirs, 1 do
			local name = DIRECTION_NAMES[i]
			if not matches[name] then
				table.insert(missing, name)
			end
		end
		app.alert {
			title = "Warning",
			text = {
				"There must be at least " .. sprite.state.dirs .. " layers matching direction names",
				table.concat_and(missing) .. " " .. is_are(#missing) .. " missing",
			}
		}
		return false
	end

	if #duplicates > 0 then
		app.alert {
			title = "Warning",
			text = {
				"There must be only one layer for each direction",
				table.concat_and(duplicates) .. " " .. is_are(#duplicates) .. " duplicated",
			}
		}
		return false
	end

	local delays = {} --[[ @type integer[] ]]

	for index, frame in ipairs(sprite.sprite.frames) do
		if #sprite.sprite.frames > 1 then
			table.insert(delays, frame.duration * 10)
		end
		for _, layer in ipairs(sprite.sprite.layers) do
			local dir = table.index_of(DIRECTION_NAMES, layer.name)
			if dir ~= 0 and dir <= sprite.state.dirs then
				local cel = layer:cel(frame.frameNumber)
				local image = Image(self.dmi.width, self.dmi.height)

				if cel and cel.image then
					image:drawImage(cel.image, cel.position)
				end

				local index = (index - 1) * sprite.state.dirs + dir - 1

				local bytes = image.bytes
				sprite.state:set_frame(index, self.dmi.width, self.dmi.height, string.byte(bytes, 1, #bytes))
			end
		end
	end

	sprite.state.delays = delays
	sprite.state.frame_count = #sprite.sprite.frames

	fake_save(sprite.sprite)

	self.recreate_widgets = true
	self.dialog:repaint()

	return true
end

Editor = setmetatable({}, Editor)
