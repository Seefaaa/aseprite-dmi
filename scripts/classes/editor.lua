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
--- @field dialog Dialog The dialog object.
Editor = {}
Editor.__index = Editor

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

	if max_rows ~= self.max_rows or max_cols ~= self.max_cols then
		self.max_rows = max_rows
		self.max_cols = max_cols
		self:create_widgets(ctx)
		if self.dialog then
			self.dialog:repaint()
		end
	end

	local hovered_texts = {} --[[@type TextWidget[] ]]

	for _, widget in ipairs(self.widgets) do
		if is_widget(widget, ImageWidget) then
			local widget = widget --[[@as ImageWidget]]
			local part_id = table.contains(self.hovered_widgets, widget) and "sunken_focused" or "sunken_normal"
			ctx:drawThemeRect(part_id, widget.x, widget.y, widget.image.width + SUNKEN_PADDING,
				widget.image.height + SUNKEN_PADDING)
			ctx:drawImage(widget.image, widget.x + SUNKEN_PADDING / 2, widget.y + SUNKEN_PADDING / 2)
		elseif is_widget(widget, TextWidget) then
			local widget = widget --[[@as TextWidget]]
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

		index = index - 1

		local x = (widget_width + COLUMN_SPACE) * (index % self.max_cols) + CANVAS_PADDING
		local y = (widget_height + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) * math.floor(index / self.max_cols) +
				CANVAS_PADDING

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

		local widget = ImageWidget(image, x, y, widget_width, widget_height, on_click)

		table.insert(self.widgets, widget)

		local text = fit_text(ctx, state.name, widget_width - SUNKEN_PADDING / 2)
		local size = ctx:measureText(text)
		local hovered_x = x
		local x = x + (widget_width - size.width) / 2
		local y = y + widget_height + TEXT_PADDING_TOP

		local widget = TextWidget(text, app.theme.color.text, x, y, width, size.height, state.name, hovered_x, widget_width)

		table.insert(self.widgets, widget)
	end
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
			if bounds:contains(Point(ev.x, ev.y)) then
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

--- Opens a state in the Aseprite editor by creating a new sprite and populating it with frames and layers based on the provided state.
--- @param state State The state to open.
function Editor:open_state(state)
	local sprite = Sprite(self.dmi.width, self.dmi.height, ColorMode.RGB)
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
end

Editor = setmetatable({}, Editor)
