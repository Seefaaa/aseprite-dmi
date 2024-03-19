--- @class Widget: table
--- @field x integer Position of the widget on the x-axis.
--- @field y integer Position of the widget on the y-axis.
--- @field width integer Width of the widget.
--- @field height integer Height of the widget.
--- @field on_click? fun(self: Widget, ev: MouseEvent) Function to call when the widget is clicked.
Widget = {}
Widget.__index = Widget

function Widget.__call(self)
	error("Widget is an abstract class")
end

Widget = setmetatable({}, Widget)

--- @class ImageWidget: Widget
--- @field image Image The image to draw.
ImageWidget = {}
ImageWidget.__index = ImageWidget

--- @param image Image
--- @param width integer
--- @param height integer
--- @param on_click? fun(self: Widget, ev: MouseEvent)
function ImageWidget.__call(self, image, width, height, on_click)
	local self = setmetatable({}, getmetatable(self)) --[[@as ImageWidget]]

	self.image = image
	self.width = width
	self.height = height
	self.on_click = on_click

	return self
end

ImageWidget = setmetatable({}, ImageWidget)

--- @class TextWidget: Widget
--- @field text string The text to draw.
--- @field color Color The color of the text.
--- @field hovered_text string? The text to draw when the mouse is hovering over the widget.
--- @field hovered_x? integer The x position of the hovered text.
--- @field hovered_width? integer The width of the hovered text.
TextWidget = {}
TextWidget.__index = TextWidget

--- @param text string
--- @param color Color
--- @param width integer
--- @param height integer
--- @param hovered_text? string
--- @param hovered_width? integer
function TextWidget.__call(self, text, color, width, height, hovered_text, hovered_width)
	local self = setmetatable({}, getmetatable(self)) --[[@as TextWidget]]

	self.text = text
	self.color = color
	self.width = width
	self.height = height
	self.hovered_text = hovered_text
	self.hovered_width = hovered_width

	return self
end

TextWidget = setmetatable({}, TextWidget)

--- @class ThemeWidget: Widget
--- @field part_id? string The part id of the widget.
--- @field width integer The width of the widget.
--- @field height integer The height of the widget.
--- @field on_click? fun(self: Widget, ev: MouseEvent) Function to call when the widget is clicked.
ThemeWidget = {}
ThemeWidget.__index = ThemeWidget

--- @param part_id? string
--- @param width integer
--- @param height integer
--- @param on_click? fun(self: Widget, ev: MouseEvent)
function ThemeWidget.__call(self, part_id, width, height, on_click)
	local self = setmetatable({}, getmetatable(self)) --[[@as ThemeWidget]]

	self.part_id = part_id
	self.width = width
	self.height = height
	self.on_click = on_click

	return self
end

ThemeWidget = setmetatable({}, ThemeWidget)
