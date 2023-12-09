--- Represents sprite of a state.
--- @class StateSprite
--- @field editor Editor The editor object.
--- @field dmi Dmi The DMI file object.
--- @field state State The state of the sprite.
--- @field sprite Sprite The sprite object.
--- @field transparentColor Color The transparent color of the sprite.
StateSprite = {}
StateSprite.__index = StateSprite

--- Creates a new instance of the StateSprite class.
--- @param editor Editor The editor object.
--- @param state State The state of the sprite.
--- @param sprite Sprite The sprite object.
--- @param transparentColor Color The transparent color of the sprite.
--- @return StateSprite statesprite The newly created StateSprite object.
function StateSprite.new(editor, dmi, state, sprite, transparentColor)
	local self = setmetatable({}, StateSprite)

	self.editor = editor
	self.dmi = dmi
	self.state = state
	self.sprite = sprite
	self.transparentColor = transparentColor

	return self
end

--- Saves the state sprite by exporting each layer as a separate image file.
--- @return boolean boolean true if the save operation is successful, false otherwise.
function StateSprite:save()
	if #self.sprite.layers < self.state.dirs then
		app.alert { title = self.editor.title, text = "There must be at least " .. math.floor(self.state.dirs) .. " layers matching direction names" }
		return false
	end

	local matches = {}
	for _, layer in ipairs(self.sprite.layers) do
		local direction = table.index_of(DIRECTION_NAMES, layer.name)
		if direction > 0 and direction <= self.state.dirs then
			if matches[layer.name] then
				app.alert { title = self.editor.title, text = "There must be only one layer for each direction" }
				return false
			else
				matches[layer.name] = true
			end
		end
	end

	if table.keys_len(matches) ~= self.state.dirs then
		app.alert { title = self.editor.title, text = "There must be only one layer for each direction" }
		return false
	end

	self.state.frame_count = #self.sprite.frames
	self.state.delays = {}

	local index = 0
	for frame_index, frame in ipairs(self.sprite.frames) do
		if #self.sprite.frames > 1 then
			self.state.delays[frame_index] = frame.duration * 10
		end
		for layer_index = #self.sprite.layers, 1, -1 do
			local layer = self.sprite.layers[layer_index]
			if table.index_of(DIRECTION_NAMES, layer.name) > 0 then
				local cel = layer:cel(frame.frameNumber)
				local image = Image(ImageSpec {
					width = self.editor.dmi.width,
					height = self.editor.dmi.height,
					colorMode = ColorMode.RGB,
					transparentColor = app.pixelColor.rgba(self.transparentColor.red, self.transparentColor.green, self.transparentColor.blue, self.transparentColor.alpha)
				})

				if cel and cel.image then
					image:drawImage(cel.image, cel.position)
				end

				image:saveAs(app.fs.joinPath(self.editor.dmi.temp, self.state.frame_key .. "." .. index .. ".png"))

				if frame_index == 1 and layer_index == #self.sprite.layers then
					image_cache:set(self.state.frame_key, image)
				end
			end
			index = index + 1
		end
	end

	self.editor:repaint_states()

	return true
end
