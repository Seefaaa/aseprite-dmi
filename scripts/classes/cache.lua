--- Represents a cache for storing images.
--- @class ImageCache
--- @field images ImageCache.Table A table containing all images in the cache.
ImageCache = {}
ImageCache.__index = ImageCache

--- @alias ImageCache.Table table<string, table<number, Image>>

--- Creates a new instance of the ImageCache class.
---@return ImageCache image_cache The newly created ImageCache instance.
function ImageCache.new()
	local self = setmetatable({}, ImageCache)
	self.images = {}
	return self
end

--- Retrieves an image from the image cache based on the specified state and frame.
--- If no frame is specified, the first frame is returned.
--- @param key string The key of the image.
--- @param frame number? (optional) The frame number of the image.
--- @return Image image The retrieved image.
function ImageCache:get(key, frame)
	return self.images[key][frame or 1]
end

--- Sets the specified image for the given state and frame in the ImageCache.
--- If the state or frame does not exist in the cache, it will be created.
--- @param key string The key of the image.
--- @param image Image The image to be set.
--- @param frame? number (optional) The frame number. Defaults to 1 if not provided.
function ImageCache:set(key, image, frame)
	if not self.images[key] then
		self.images[key] = {}
	end
	self.images[key][frame or 1] = image
end

--- Removes an image from the cache using the specified key.
--- @param key string The key of the image.
function ImageCache:remove(key)
	if self.images[key] then
		self.images[key] = nil
	end
end

--- Clears the image cache.
function ImageCache:clear()
	self.images = {}
end

--- Loads preview images for each state in the DMI file and caches them in the ImageCache.
--- @param dmi Dmi The DMI file object.
function ImageCache:load_previews(dmi)
	for _, state in ipairs(dmi.states) do
		self:load_state(dmi, state)
	end
end

--- Loads the state of an image from a DMI file and adds it to the cache.
--- @param dmi Dmi The DMI file.
--- @param state State The state of the image.
function ImageCache:load_state(dmi, state)
	local image = load_image_bytes(app.fs.joinPath(dmi.temp, state.frame_key .. ".0" .. ".bytes"))
	self:set(state.frame_key, image)
end
