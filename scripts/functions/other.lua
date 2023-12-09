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

			local success, _, _, _, dmi = lib:new_file("untitled", width, height)

			if success then
				Editor.new("DMI Editor", nil, dmi)
			end
		end
	end
end
