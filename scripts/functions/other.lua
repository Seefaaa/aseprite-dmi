--- @diagnostic disable: lowercase-global

--- Finds the first transparent color in the given image.
--- @param image Image The image to search for transparent color.
--- @return Color color The first transparent color found in the image, or a fully transparent black color if no transparent color is found.
function transparent_color(image)
	for it in image:pixels() do
		local color = Color(it())
		if color.alpha == 0 then
			if color.index == 0 then
				return color
			end
		end
	end
	return Color(0)
end

--- Returns the name of the file from the given path.
--- @param path string The path to the file.
--- @return string name The name of the file.
function file_name(path)
	return path:match("^.+[\\/](.+)$")
end

--- Function to load image from bytes file.
--- Thanks to `Astropulse` for sharing [this](https://community.aseprite.org/t/loading-ui-images-for-graphicscontext-elements-at-lightning-speed/21128) article.
--- @param file string The path to the file.
--- @return Image image The image loaded from the file.
function load_image_bytes(file)
	local file = io.open(file, "rb")

	assert(file, "File not found")

	local width = tonumber(file:read("*line"))
	local height = tonumber(file:read("*line"))
	local bytes = file:read("*a")

	file:close()

	assert(width and height and bytes, "Invalid file")

	image = Image(width, height)
	image.bytes = bytes

	return image
end

--- Function to save image to bytes file.
--- @param image Image The image to save.
--- @param file string The path to the file.
function save_image_bytes(image, file)
	local file = io.open(file, "wb")

	assert(file, "File not found")

	file:write(image.width .. "\n")
	file:write(image.height .. "\n")
	file:write(image.bytes)

	file:close()
end
