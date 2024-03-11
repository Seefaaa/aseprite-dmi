--- @class Mouse: table
--- @field x integer Position of the mouse on the x-axis.
--- @field y integer Position of the mouse on the y-axis.
--- @field left boolean Whether the left mouse button is pressed.
--- @field right boolean Whether the right mouse button is pressed.
Mouse = {}

function Mouse.__call(self, ...)
	local self = setmetatable({}, getmetatable(self)) --[[@as Mouse]]

	self.x = 0
	self.y = 0
	self.left = false
	self.right = false

	return self
end

Mouse = setmetatable({}, Mouse)
