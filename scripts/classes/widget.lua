--- @class WidgetState
--- @field normal WidgetState.State The normal state of the widget.
--- @field hot? WidgetState.State The hover state of the widget.
--- @field focused? WidgetState.State The focused state of the widget.
--- @field selected? WidgetState.State The selected state of the widget.

--- @alias WidgetState.State { part: string, color: string }

--- @alias AnyWidget IconWidget|TextWidget|ThemeWidget

--- Widget class represents a graphical user interface element.
--- It provides a base for creating custom widgets.
--- @class IconWidget
--- @field editor Editor The editor object.
--- @field bounds Rectangle The bounds of the widget.
--- @field state WidgetState The state of the widget (optional).
--- @field icon Image The icon of the widget.
--- @field onmouseup function|nil The onmouseup function of the widget.
IconWidget = { type = "IconWidget" }
IconWidget.__index = IconWidget

--- Creates a new widget.
--- @param editor Editor The editor object.
--- @param bounds Rectangle The bounds of the widget.
--- @param state WidgetState The state of the widget (optional).
--- @param icon Image The icon of the widget.
--- @param onmouseup function|nil The function to be called when the widget is clicked (optional).
--- @return IconWidget widget The newly created widget.
function IconWidget.new(editor, bounds, state, icon, onmouseup)
	local self = setmetatable({}, IconWidget)

	self.editor = editor
	self.bounds = bounds
	self.state = state or { normal = { part = "sunken_normal", color = "button_normal_text" } }
	self.icon = icon
	self.onmouseup = onmouseup or function() end

	return self
end

--- TextWidget subtype of Widget
--- @class TextWidget
--- @field editor Editor The editor object.
--- @field bounds Rectangle The bounds of the widget.
--- @field state WidgetState The state of the widget (optional).
--- @field text string The text of the widget.
--- @field text_color Color|nil The color of the text of the widget.
--- @field hover_text string|nil The hover text of the widget.
--- @field onmouseup function|nil The onmouseup function of the widget.
TextWidget = { type = "TextWidget" }
TextWidget.__index = TextWidget

--- Creates a new TextWidget.
--- @param editor Editor The editor object.
--- @param bounds Rectangle The bounds of the widget.
--- @param state WidgetState The state of the widget (optional).
--- @param text string|nil The text of the widget (optional).
--- @param text_color Color|nil The color of the text of the widget (optional).
--- @param hover_text string|nil The hover text of the widget (optional).
--- @param onmouseup function|nil The function to be called when the widget is clicked (optional).
--- @return TextWidget widget The newly created TextWidget.
function TextWidget.new(editor, bounds, state, text, text_color, hover_text, onmouseup)
	local self = setmetatable({}, TextWidget)

	self.editor = editor
	self.bounds = bounds
	self.state = state or { normal = { part = "sunken_normal", color = "button_normal_text" } }
	self.text = text or ""
	self.text_color = text_color
	self.hover_text = hover_text
	self.onmouseup = onmouseup or function() end

	return self
end

--- @class ThemeWidget
--- @field editor Editor The editor object.
--- @field bounds Rectangle The bounds of the widget.
--- @field state WidgetState The state of the widget (optional).
--- @field partId string|nil The partId of the image.
--- @field onmouseup function|nil The onmouseup function of the widget.
ThemeWidget = { type = "ThemeWidget" }
ThemeWidget.__index = ThemeWidget

--- Creates a new ThemeWidget.
--- @param editor Editor The editor object.
--- @param bounds Rectangle The bounds of the widget.
--- @param state WidgetState The state of the widget (optional).
--- @param partId string|nil The partId of the image.
--- @param onmouseup function|nil The function to be called when the widget is clicked (optional).
--- @return ThemeWidget widget The newly created ThemeWidget.
function ThemeWidget.new(editor, bounds, state, partId, onmouseup)
	local self = setmetatable({}, ThemeWidget)

	self.editor = editor
	self.bounds = bounds
	self.state = state or { normal = { part = "sunken_normal", color = "button_normal_text" } }
	self.partId = partId
	self.onmouseup = onmouseup or function() end

	return self
end
