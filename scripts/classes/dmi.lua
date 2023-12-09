--- Dmi is a table representing a DMI file.
--- @class Dmi
--- @field name string The name of the DMI file.
--- @field width number The width of the DMI file.
--- @field height number The height of the DMI file.
--- @field states (State)[] The states of the DMI file.
--- @field temp string The temporary directory of the DMI file.
Dmi = {}
Dmi.__index = Dmi

--- Creates a new Dmi object.
--- @param dmi table The Dmi table containing the properties of the Dmi object.
--- @return Dmi dmi The newly created Dmi object.
function Dmi.new(dmi)
	local self = setmetatable({}, Dmi)

	self.name = dmi.name
	self.width = dmi.width
	self.height = dmi.height
	self.states = {}
	self.temp = dmi.temp

	for _, state in ipairs(dmi.states) do
		self.states[#self.states + 1] = State.new(state)
	end

	return self
end

--- Represents a state object.
--- @class State
--- @field name string The name of the state.
--- @field dirs 1|4|8 The number of directions in the state.
--- @field frame_key string The frame key of the state.
--- @field frame_count number The number of frames in the state.
--- @field delays (number)[] The delays of the state.
--- @field loop_ number Whether the state loops or not.
--- @field rewind boolean Whether the state rewinds or not.
--- @field movement boolean Whether the state is a movement state or not.
--- @field hotspots (string)[] The hotspots of the state.
State = {}
State.__index = State

--- Creates a new State object.
--- @param state table The state table containing the properties of the State object.
--- @return State state The newly created State object.
function State.new(state)
	local self = setmetatable({}, State)

	self.name = state.name or ""
	self.dirs = state.dirs or 1
	self.frame_key = state.frame_key or ""
	self.frame_count = state.frame_count or 1
	self.delays = {}
	self.loop_ = state.loop_ or 0
	self.rewind = state.rewind or false
	self.movement = state.movement or false
	self.hotspots = {}

	for _, delay in ipairs(state.delays) do
		self.delays[#self.delays + 1] = delay
	end

	for _, hotspot in ipairs(state.hotspots) do
		self.hotspots[#self.hotspots + 1] = hotspot
	end

	return self
end
