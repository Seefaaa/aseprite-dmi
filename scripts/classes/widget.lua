--- @class Widget: table
--- @field x integer Position of the widget on the x-axis.
--- @field y integer Position of the widget on the y-axis.
--- @field width integer Width of the widget.
--- @field height integer Height of the widget.
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
--- @param x integer
--- @param y integer
--- @param width integer
--- @param height integer
function ImageWidget.__call(self, image, x, y, width, height)
	local self = setmetatable({}, getmetatable(self)) --[[@as ImageWidget]]

	self.image = image
	self.x = x
	self.y = y
	self.width = width
	self.height = height

	return self
end

ImageWidget = setmetatable({}, ImageWidget)

--- @class TextWidget: Widget
--- @field text string The text to draw.
--- @field color Color The color of the text.
--- @field hovered_text string The text to draw when the mouse is hovering over the widget.
--- @field hovered_x integer The x position of the hovered text.
--- @field hovered_width integer The width of the hovered text.
TextWidget = {}
TextWidget.__index = TextWidget

--- @param text string
--- @param color Color
--- @param x integer
--- @param y integer
--- @param width integer
--- @param height integer
--- @param hovered_text string
--- @param hovered_x integer
--- @param hovered_width integer
function TextWidget.__call(self, text, color, x, y, width, height, hovered_text, hovered_x, hovered_width)
	local self = setmetatable({}, getmetatable(self)) --[[@as TextWidget]]

	self.text = text
	self.color = color
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	self.hovered_text = hovered_text
	self.hovered_x = hovered_x
	self.hovered_width = hovered_width

	return self
end

TextWidget = setmetatable({}, TextWidget)
