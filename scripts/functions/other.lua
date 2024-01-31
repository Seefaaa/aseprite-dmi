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

--- Fits the given text within the specified maximum width by truncating it with ellipsis if necessary.
--- @param text string The text to fit.
--- @param ctx GraphicsContext The context object used for measuring the text width.
--- @param maxWidth number The maximum width allowed for the text.
--- @return string text The fitted text.
function fit_text(text, ctx, maxWidth)
	local width = ctx:measureText(text).width
	while width >= maxWidth do
		if text:ends_with("...") then
			text = text:sub(1, text:len() - 4) .. "..."
		else
			text = text:sub(1, text:len() - 1) .. "..."
		end
		width = ctx:measureText(text).width
	end
	return text
end

--- Creates a new DMI file with the specified width and height.
--- Uses native new file dialog to get the dimensions.
--- If the file creation is successful, opens the DMI Editor with the newly created file.
function new_file()
	local previous_sprite = app.sprite
	if app.command.NewFile { width = 32, height = 32 } then
		if previous_sprite ~= app.sprite then
			local width = app.sprite.width
			local height = app.sprite.height

			app.command.CloseFile { ui = false }

			lib:new_file("untitled", width, height, function(dmi, error)
				if not error then
					Editor.new(DIALOG_NAME, nil, dmi)
				else
					app.alert { title = DIALOG_NAME, text = { "Failed to create new DMI file", error } }
				end
			end)
		end
	end
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
