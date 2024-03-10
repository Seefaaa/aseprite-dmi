--- @class Widget: table
--- @field x integer
--- @field y integer
Widget = {}
Widget.__index = Widget

function Widget.__call(self, ...)
	local self = setmetatable({}, getmetatable(self)) --[[@as Widget]]
	return self
end

Widget = setmetatable({}, Widget)

--- @class ImageWidget: Widget
--- @field image Image
ImageWidget = {}
ImageWidget.__index = ImageWidget


--- @param image Image
--- @param x integer
--- @param y integer
function ImageWidget.__call(self, image, x, y)
	local self = setmetatable({}, getmetatable(self)) --[[@as ImageWidget]]

	self.image = image
	self.x = x
	self.y = y

	return self
end

ImageWidget = setmetatable({}, ImageWidget)

--- @class TextWidget: Widget
--- @field text string
--- @field color Color
TextWidget = {}
TextWidget.__index = TextWidget

--- @param text string
--- @param color Color
--- @param x integer
--- @param y integer
function TextWidget.__call(self, text, color, x, y)
	local self = setmetatable({}, getmetatable(self)) --[[@as TextWidget]]

	self.text = text
	self.color = color
	self.x = x
	self.y = y

	return self
end

TextWidget = setmetatable({}, TextWidget)
