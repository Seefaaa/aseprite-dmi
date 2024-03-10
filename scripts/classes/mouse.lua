--- @class Mouse: table
--- @field x integer
--- @field y integer
--- @field left boolean
--- @field right boolean
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
