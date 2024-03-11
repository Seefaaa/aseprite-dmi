--- @class Editor: table
--- @field filename string The filename of the DMI file.
--- @field dmi Dmi The DMI object.
--- @field width integer The width of the editor.
--- @field height integer The height of the editor.
--- @field widgets Widget[] The widgets to be shown in the dialog.
--- @field hovered_widgets Widget[] The widgets that are currently hovered by the mouse.
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
--- @return integer
local WIDTH = function(width)
	return 5 * (width + SUNKEN_PADDING + COLUMN_SPACE) - COLUMN_SPACE + CANVAS_PADDING * 2
end

--- Calculates the height of the editor based on the height of the states.
--- @return integer
local HEIGHT = function(height)
	return 4 * (height + SUNKEN_PADDING + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) -
			math.floor(TEXT_PADDING_BOTTOM / 2) + CANVAS_PADDING * 2
end

--- The default width for a 32x?? DMI file.
local DEFAULT_WIDTH = WIDTH(32)

--- The default height for a ??x32 DMI file.
local DEFAULT_HEIGHT = HEIGHT(32)

function Editor.__call(self, filename)
	local self = setmetatable({}, getmetatable(self)) --[[@as Editor]]

	self.filename = filename
	self.dmi = assert(libdmi.open(filename))
	self:default_size()
	self.widgets = {}
	self.hovered_widgets = {}
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
		local width = WIDTH(self.dmi.width)
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
		local height = HEIGHT(self.dmi.height)
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

	local hovered_texts = {} --[[@type TextWidget[] ]]

	if #self.widgets == 0 then
		self:create_widgets(ctx)
	end

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

	local max_rows = math.max(math.floor(self.width / widget_width), 1)
	local max_cols = math.max(math.floor(self.height / widget_height) + 1, 2)

	local max_index = max_rows * max_cols;

	for index, state in ipairs(self.dmi.states) do
		if index > max_index then break end

		index = index - 1

		local x = (widget_width + COLUMN_SPACE) * (index % max_rows) + CANVAS_PADDING
		local y = (widget_height + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) * math.floor(index / max_rows) +
				CANVAS_PADDING

		local background_color = app.theme.color.face

		local image = Image(width, height)
		image.bytes = state:preview(background_color.red, background_color.green, background_color.blue)

		local widget = ImageWidget(image, x, y, widget_width, widget_height)

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

Editor = setmetatable({}, Editor)
