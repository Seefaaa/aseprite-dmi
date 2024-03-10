--- @class Editor: table
--- @field filename string
--- @field width integer
--- @field height integer
--- @field dmi Dmi
--- @field widgets (Widget)[]
--- @field dialog Dialog
--- @field mouse Mouse
Editor = {}
Editor.__index = Editor

local CANVAS_PADDING = 1
local SUNKEN_PADDING = 4
local COLUMN_SPACE = 1
local TEXT_HEIGHT = 5
local TEXT_PADDING_TOP = 5
local TEXT_PADDING_BOTTOM = 7

local DEFAULT_WIDTH = 5 * (32 + SUNKEN_PADDING + COLUMN_SPACE) - COLUMN_SPACE + CANVAS_PADDING * 2
local DEFAULT_HEIGHT = 4 * (32 + SUNKEN_PADDING + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) -
		math.floor(TEXT_PADDING_BOTTOM / 2) + CANVAS_PADDING * 2

function Editor.__call(self, filename)
	local self = setmetatable({}, getmetatable(self)) --[[@as Editor]]

	self.filename = filename
	self.width = DEFAULT_WIDTH
	self.height = DEFAULT_HEIGHT
	self.dmi = assert(libdmi.open(filename))
	self.widgets = {}
	self.dialog = self:create_dialog()
	self.mouse = Mouse()

	return self
end

function Editor:create_dialog()
	local dialog = Dialog {
		title = "Editor",
	}

	dialog:canvas {
		width = self.width >= self.dmi.width and self.width or self.dmi.width + SUNKEN_PADDING + CANVAS_PADDING * 2,
		height = self.height,
		onpaint = function(ev) self:on_paint(ev.context) end,
	}

	dialog:button {
		text = "Save",
		onclick = function() end,
	}

	dialog:show { wait = false }

	return dialog
end

--- @param ctx GraphicsContext
function Editor:on_paint(ctx)
	self.width = ctx.width
	self.height = ctx.height

	if #self.widgets == 0 then
		self:create_widgets(ctx)
	end

	for _, widget in ipairs(self.widgets) do
		if widget.__index == getmetatable(ImageWidget) then
			local widget = widget --[[@as ImageWidget]]
			ctx:drawThemeRect("sunken_normal", widget.x, widget.y, widget.image.width + SUNKEN_PADDING,
				widget.image.height + SUNKEN_PADDING)
			ctx:drawImage(widget.image, widget.x + SUNKEN_PADDING / 2, widget.y + SUNKEN_PADDING / 2)
		elseif widget.__index == getmetatable(TextWidget) then
			local widget = widget --[[@as TextWidget]]
			ctx.color = widget.color
			ctx:fillText(widget.text, widget.x, widget.y)
		end
	end
end

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

--- @param ctx GraphicsContext
function Editor:create_widgets(ctx)
	self.widgets = {}

	local width = self.dmi.width
	local height = self.dmi.height

	local widget_width = width + SUNKEN_PADDING
	local widget_height = height + SUNKEN_PADDING

	local max_rows = math.max(math.floor(self.width / widget_width), 1)
	local max_cols = math.max(math.floor(self.height / widget_height), 1)

	local max_index = max_rows * (max_cols + 1);

	for index, state in ipairs(self.dmi.states) do
		if index > max_index then
			break
		end

		index = index - 1

		local x = (widget_width + COLUMN_SPACE) * (index % max_rows) + CANVAS_PADDING
		local y = (widget_height + TEXT_PADDING_TOP + TEXT_HEIGHT + TEXT_PADDING_BOTTOM) * math.floor(index / max_cols) +
				CANVAS_PADDING

		local background_color = app.theme.color.face

		local image = Image(width, height)
		image.bytes = state:preview(background_color.red, background_color.green, background_color.blue)

		local widget = ImageWidget(image, x, y)

		table.insert(self.widgets, widget)

		local text = fit_text(ctx, state.name, widget_width - SUNKEN_PADDING / 2)
		local x = x + (widget_width - ctx:measureText(text).width) / 2
		local y = y + widget_height + TEXT_PADDING_TOP

		local widget = TextWidget(text, app.theme.color.text, x, y)

		table.insert(self.widgets, widget)
	end
end

Editor = setmetatable({}, Editor)
