--- @alias MouseFunction fun(ev: MouseEvent)

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
--- @field onleftclick MouseFunction|nil The onleftclick function of the widget.
--- @field onrightclick MouseFunction|nil The onrightclick function of the widget.
IconWidget = { type = "IconWidget" }
IconWidget.__index = IconWidget

--- Creates a new widget.
--- @param editor Editor The editor object.
--- @param bounds Rectangle The bounds of the widget.
--- @param state WidgetState The state of the widget (optional).
--- @param icon Image The icon of the widget.
--- @param onleftclick MouseFunction|nil The function to be called when the widget is clicked (optional).
--- @param onrightclick MouseFunction|nil The function to be called when the widget is right clicked (optional).
--- @return IconWidget widget The newly created widget.
function IconWidget.new(editor, bounds, state, icon, onleftclick, onrightclick)
	local self = setmetatable({}, IconWidget)

	self.editor = editor
	self.bounds = bounds
	self.state = state or { normal = { part = "sunken_normal", color = "button_normal_text" } }
	self.icon = icon
	self.onleftclick = onleftclick or function() end
	self.onrightclick = onrightclick or function() end

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
--- @field onleftclick MouseFunction|nil The onleftclick function of the widget.
--- @field onrightclick MouseFunction|nil The onrightclick function of the widget.
TextWidget = { type = "TextWidget" }
TextWidget.__index = TextWidget

--- Creates a new TextWidget.
--- @param editor Editor The editor object.
--- @param bounds Rectangle The bounds of the widget.
--- @param state WidgetState The state of the widget (optional).
--- @param text string|nil The text of the widget (optional).
--- @param text_color Color|nil The color of the text of the widget (optional).
--- @param hover_text string|nil The hover text of the widget (optional).
--- @param onleftclick MouseFunction|nil The function to be called when the widget is clicked (optional).
--- @param onrightclick MouseFunction|nil The function to be called when the widget is right clicked (optional).
--- @return TextWidget widget The newly created TextWidget.
function TextWidget.new(editor, bounds, state, text, text_color, hover_text, onleftclick, onrightclick)
	local self = setmetatable({}, TextWidget)

	self.editor = editor
	self.bounds = bounds
	self.state = state or { normal = { part = "sunken_normal", color = "button_normal_text" } }
	self.text = text or ""
	self.text_color = text_color
	self.hover_text = hover_text
	self.onleftclick = onleftclick or function() end
	self.onrightclick = onrightclick or function() end

	return self
end

--- @class ThemeWidget
--- @field editor Editor The editor object.
--- @field bounds Rectangle The bounds of the widget.
--- @field state WidgetState The state of the widget (optional).
--- @field partId string|nil The partId of the image.
--- @field onleftclick MouseFunction|nil The onleftclick function of the widget.
--- @field onrightclick MouseFunction|nil The onrightclick function of the widget.
ThemeWidget = { type = "ThemeWidget" }
ThemeWidget.__index = ThemeWidget

--- Creates a new ThemeWidget.
--- @param editor Editor The editor object.
--- @param bounds Rectangle The bounds of the widget.
--- @param state WidgetState The state of the widget (optional).
--- @param partId string|nil The partId of the image.
--- @param onleftclick MouseFunction|nil The function to be called when the widget is clicked (optional).
--- @param onrightclick MouseFunction|nil The function to be called when the widget is right clicked (optional).
--- @return ThemeWidget widget The newly created ThemeWidget.
function ThemeWidget.new(editor, bounds, state, partId, onleftclick, onrightclick)
	local self = setmetatable({}, ThemeWidget)

	self.editor = editor
	self.bounds = bounds
	self.state = state or { normal = { part = "sunken_normal", color = "button_normal_text" } }
	self.partId = partId
	self.onleftclick = onleftclick or function() end
	self.onrightclick = onrightclick or function() end

	return self
end

--- @class ContextButton
--- @field text string The text of the button.
--- @field onclick fun() The function to be called when the button is clicked.

--- @class ContextWidget
--- @field bounds Rectangle The bounds of the widget.
--- @field state State The state currently being right clicked.
--- @field buttons ContextButton[] The buttons of the widget.
--- @field drawn boolean Whether the widget has been drawn.
--- @field focus number Focused button index.
ContextWidget = { type = "ContextWidget" }
ContextWidget.__index = ContextWidget

--- Creates a new ContextWidget.
--- @param bounds Rectangle The bounds of the widget.
--- @param state State The state currently being right clicked.
--- @param buttons ContextButton[] The buttons of the widget.
--- @return ContextWidget widget The newly created ContextWidget.
function ContextWidget.new(bounds, state, buttons)
	local self = setmetatable({}, ContextWidget)

	self.bounds = bounds
	self.state = state
	self.buttons = buttons
	self.drawn = false
	self.focus = 0

	return self
end
