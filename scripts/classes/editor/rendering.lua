local TEXT_HEIGHT = 0
local CONTEXT_BUTTON_HEIGHT = 0
local BOX_BORDER = 4
local BOX_PADDING = 5

--- Repaints the editor.
function Editor:repaint()
	self.dialog:repaint()
end

--- This function is called when the editor needs to repaint its contents.
--- @param ctx GraphicsContext The drawing context used to draw on the editor canvas.
function Editor:onpaint(ctx)
	if self.loading then
		local size = ctx:measureText("Loading file...")
		ctx.color = app.theme.color.text
		ctx:fillText("Loading file...", (ctx.width - size.width) / 2, (ctx.height - size.height) / 2)
		return
	end

	local min_width = self.dmi and (self.dmi.width + BOX_PADDING) or 1
	local min_height = self.dmi and (self.dmi.height + BOX_BORDER + BOX_PADDING * 2 + TEXT_HEIGHT) or 1

	self.canvas_width = math.max(ctx.width, min_width)
	self.canvas_height = math.max(ctx.height, min_height)

	if TEXT_HEIGHT == 0 then
		TEXT_HEIGHT = ctx:measureText("A").height
	end

	if CONTEXT_BUTTON_HEIGHT == 0 then
		CONTEXT_BUTTON_HEIGHT = TEXT_HEIGHT + BOX_PADDING * 2
	end

	local max_row = self.dmi and math.floor(self.canvas_width / min_width) or 1
	local max_column = self.dmi and math.floor(self.canvas_height / min_height) or 1

	if max_row ~= self.max_in_a_row or max_column ~= self.max_in_a_column then
		self.max_in_a_row = math.max(max_row, 1)
		self.max_in_a_column = math.max(max_column, 1)
		self:repaint_states()
		return
	end

	local hovers = {} --[[ @as (string)[] ]]
	for _, widget in ipairs(self.widgets) do
		local state = COMMON_STATE.normal

		if widget == self.focused_widget then
			state = COMMON_STATE.focused or state
		end

		local is_mouse_over = not self.context_widget and widget.bounds:contains(self.mouse.position)

		if is_mouse_over then
			state = COMMON_STATE.hot or state

			if self.mouse.leftClick then
				state = COMMON_STATE.selected or state
			end
		end

		if widget.type == "IconWidget" then
			local widget = widget --[[ @as IconWidget ]]

			ctx:drawThemeRect(state.part, widget.bounds)
			ctx:drawImage(
				widget.icon,
				widget.icon.bounds,
				Rectangle(widget.bounds.x + (widget.bounds.width - self.dmi.width) / 2,
					widget.bounds.y + (widget.bounds.height - self.dmi.height) / 2, widget.icon.bounds.width,
					widget.icon.bounds.height)
			)
		elseif widget.type == "TextWidget" then
			local widget = widget --[[ @as TextWidget ]]

			local text = self.fit_text(widget.text, ctx, widget.bounds.width)
			local size = ctx:measureText(text)

			ctx.color = widget.text_color or app.theme.color[state.color]
			ctx:fillText(
				text,
				widget.bounds.x + (widget.bounds.width - size.width) / 2,
				widget.bounds.y + (widget.bounds.height - size.height) / 2
			)

			if is_mouse_over and widget.hover_text then
				table.insert(hovers, widget.hover_text)
			end
		elseif widget.type == "ThemeWidget" then
			local widget = widget --[[ @as ThemeWidget ]]

			ctx:drawThemeRect(state.part, widget.bounds)

			if widget.partId then
				ctx:drawThemeImage(widget.partId,
					Rectangle(widget.bounds.x, widget.bounds.y, widget.bounds.width, widget.bounds.height))
			end
		end
	end

	if self.context_widget then
		local widget = self.context_widget --[[ @as ContextWidget ]]

		if not widget.drawn then
			local width = 0
			local height = #widget.buttons * CONTEXT_BUTTON_HEIGHT

			for _, button in ipairs(widget.buttons) do
				local text_size = ctx:measureText(button.text)
				if text_size.width > width then
					width = text_size.width
				end
			end

			width = width + BOX_PADDING * 2

			local mouse_x = widget.bounds.x
			local mouse_y = widget.bounds.y

			local x = mouse_x + width >= ctx.width and mouse_x - width or mouse_x + 1
			local y = mouse_y - height >= 0 and mouse_y - height or mouse_y + 1

			local bounds = Rectangle(x, y, width, height)

			widget.bounds = bounds
			widget.drawn = true
		end

		ctx.color = app.theme.color.button_normal_text
		ctx:drawThemeRect("sunken_normal", widget.bounds)

		for i, button in ipairs(widget.buttons) do
			local button_bounds = Rectangle(widget.bounds.x, widget.bounds.y + (i - 1) * CONTEXT_BUTTON_HEIGHT,
				widget.bounds.width,
				CONTEXT_BUTTON_HEIGHT)
			local contains_mouse = button_bounds:contains(self.mouse.position)

			ctx.color = app.theme.color.button_normal_text
			if contains_mouse then
				ctx.color = app.theme.color.button_hot_text
				ctx:drawThemeRect(
					contains_mouse and "sunken_focused" or "sunken_normal", button_bounds)
			end
			ctx:fillText(button.text, button_bounds.x + BOX_PADDING, button_bounds.y + BOX_PADDING)
		end

		return
	end

	for _, text in ipairs(hovers) do
		local text_size = ctx:measureText(text)
		local size = Size(text_size.width + BOX_PADDING * 2, text_size.height + BOX_PADDING * 2)

		local x = self.mouse.position.x - size.width / 2

		if x < 0 then
			x = 0
		elseif x + size.width > ctx.width then
			x = ctx.width - size.width
		end

		ctx.color = app.theme.color.button_normal_text
		ctx:drawThemeRect("sunken_normal", Rectangle(x, self.mouse.position.y - size.height, size.width, size.height))
		ctx:fillText(text, x + BOX_PADDING, self.mouse.position.y - (text_size.height + size.height) / 2)
	end
end

--- Repaints the states in the editor.
--- Creates state widgets for each state in the DMI file and positions them accordingly.
--- Only creates state widgets for states that are currently visible based on the scroll position.
--- Calls the repaint function to update the editor display.
function Editor:repaint_states()
	self.widgets = {}
	local duplicates = {}
	local min_index = (self.max_in_a_row * self.scroll)
	local max_index = min_index + self.max_in_a_row * (self.max_in_a_column + 1)
	for index, state in ipairs(self.dmi.states) do
		if index > min_index and index <= max_index then
			local bounds = self:box_bounds(index)
			local text_color = nil

			if not (#state.name > 0) then
				text_color = Color { red = 230, green = 223, blue = 69, alpha = 255 }
			end

			if duplicates[state.name] then
				text_color = Color { red = 230, green = 69, blue = 69, alpha = 255 }
			else
				for _, state_ in ipairs(self.dmi.states) do
					if state.name == state_.name then
						duplicates[state.name] = true
						break
					end
				end
			end

			local name = #state.name > 0 and state.name or "no name"

			local icon = self.image_cache:get(state.frame_key)
			local bytes = string.char(libdmi.overlay_color(app.theme.color.face.red, app.theme.color.face.green,
				app.theme.color.face.blue, icon.width, icon.height, string.byte(icon.bytes, 1, #icon.bytes)) --[[@as number]])

			local icon = Image(icon.width, icon.height)
			icon.bytes = bytes

			table.insert(self.widgets, IconWidget.new(
				self,
				bounds,
				icon,
				function() self:open_state(state) end,
				function(ev) self:state_context(state, ev) end
			))

			table.insert(self.widgets, TextWidget.new(
				self,
				Rectangle(
					bounds.x,
					bounds.y + bounds.height + BOX_PADDING,
					bounds.width,
					TEXT_HEIGHT
				),
				name,
				text_color,
				name,
				function() self:state_properties(state) end,
				function(ev) self:state_context(state, ev) end
			))
		end
	end

	if #self.dmi.states < max_index then
		local index = #self.dmi.states + 1
		local bounds = self:box_bounds(index)

		table.insert(self.widgets, ThemeWidget.new(
			self,
			bounds,
			nil,
			function() self:new_state() end
		))

		table.insert(self.widgets, TextWidget.new(
			self,
			Rectangle(
				bounds.x,
				bounds.y + bounds.height / 2 - 3,
				bounds.width,
				TEXT_HEIGHT
			),
			"+"
		))
	end

	self:repaint()
end

function Editor:box_bounds(index)
	local row_index = index - self.max_in_a_row * self.scroll

	return Rectangle(
		(self.dmi.width + BOX_PADDING) * ((row_index - 1) % self.max_in_a_row),
		(self.dmi.height + BOX_BORDER + BOX_PADDING * 2 + TEXT_HEIGHT) * math.floor((row_index - 1) / self.max_in_a_row) +
		BOX_PADDING,
		self.dmi.width + BOX_BORDER,
		self.dmi.height + BOX_BORDER
	)
end

--- Handles the mouse down event in the editor and triggers a repaint.
--- @param ev MouseEvent The mouse event object.
function Editor:onmousedown(ev)
	if ev.button == MouseButton.LEFT then
		self.mouse.leftClick = true
		self.focused_widget = nil
	elseif ev.button == MouseButton.RIGHT then
		self.mouse.rightClick = true
		self.focused_widget = nil
		self.context_widget = nil
	end
	self:repaint()
end

--- Handles the mouse up event in the editor and triggers a repaint.
--- @param ev MouseEvent The mouse event object.
function Editor:onmouseup(ev)
	local repaint = true
	if ev.button == MouseButton.LEFT or ev.button == MouseButton.RIGHT then
		if self.context_widget then
			for i, button in ipairs(self.context_widget.buttons) do
				local button_bounds = Rectangle(self.context_widget.bounds.x,
					self.context_widget.bounds.y + (i - 1) * CONTEXT_BUTTON_HEIGHT,
					self.context_widget.bounds.width, CONTEXT_BUTTON_HEIGHT)
				if button_bounds:contains(self.mouse.position) then
					self.context_widget = nil
					repaint = false
					self:repaint()
					button.onclick()
					break
				end
			end
			self.context_widget = nil
		else
			local triggered = false
			for _, widget in ipairs(self.widgets) do
				local is_mouse_over = widget.bounds:contains(self.mouse.position)
				if is_mouse_over then
					if ev.button == MouseButton.LEFT and widget.onleftclick then
						triggered = true
						widget.onleftclick(ev)
					elseif ev.button == MouseButton.RIGHT and widget.onrightclick then
						triggered = true
						widget.onrightclick(ev)
					end
					self.focused_widget = widget
				end
			end
			if not triggered then
				if ev.button == MouseButton.RIGHT then
					self.context_widget = ContextWidget.new(
						Rectangle(ev.x, ev.y, 0, 0),
						{
							{ text = "Paste", onclick = function() self:paste_state() end },
						}
					)
				end
			end
		end
		if ev.button == MouseButton.LEFT then
			self.mouse.leftClick = false
		elseif ev.button == MouseButton.RIGHT then
			self.mouse.rightClick = false
		end
	end
	if repaint then
		self:repaint()
	end
end

--- Updates the mouse position and triggers a repaint.
--- @param ev table The mouse event containing the x and y coordinates.
function Editor:onmousemove(ev)
	local mouse_position = Point(ev.x, ev.y)
	local should_repaint = false
	local hovering_widgets = {} --[[@type AnyWidget[] ]]

	for _, widget in ipairs(self.widgets) do
		if widget.bounds:contains(mouse_position) then
			table.insert(hovering_widgets, widget)
		end
	end

	if self.context_widget then
		local focus = 0
		for i, _ in ipairs(self.context_widget.buttons) do
			local button_bounds = Rectangle(self.context_widget.bounds.x,
				self.context_widget.bounds.y + (i - 1) * CONTEXT_BUTTON_HEIGHT,
				self.context_widget.bounds.width, CONTEXT_BUTTON_HEIGHT)
			if button_bounds:contains(mouse_position) then
				focus = i
				break
			end
		end
		if self.context_widget.focus ~= focus then
			self.context_widget.focus = focus
			should_repaint = true
		end
	end

	if not should_repaint then
		for _, widget in ipairs(self.hovering_widgets) do
			if table.index_of(hovering_widgets, widget) == 0 or widget.hover_text then
				should_repaint = true
				break
			end
		end
	end

	if not should_repaint then
		for _, widget in ipairs(hovering_widgets) do
			if table.index_of(self.hovering_widgets, widget) == 0 or widget.hover_text then
				should_repaint = true
				break
			end
		end
	end

	self.mouse.position = mouse_position
	self.hovering_widgets = hovering_widgets

	if should_repaint then
		self:repaint()
	end
end

--- Handles the mouse wheel event for scrolling through DMI states.
--- @param ev table The mouse wheel event object.
function Editor:onwheel(ev)
	if not self.dmi then return end

	local overflow = (#self.dmi.states + 1) - self.max_in_a_row * self.max_in_a_column

	if overflow <= 0 then return end

	local last_digit = overflow % self.max_in_a_row
	local rounded = overflow - last_digit

	if last_digit > 0 then
		rounded = rounded + self.max_in_a_row
	end

	local max_scroll = math.floor(rounded / self.max_in_a_row)
	local new_scroll = math.min(math.max(self.scroll + (ev.deltaY > 0 and 1 or -1), 0), max_scroll)

	if new_scroll ~= self.scroll then
		self.scroll = new_scroll
		self:repaint_states()
	end
end

--- Fits the given text within the specified maximum width by truncating it with ellipsis if necessary.
--- @param text string The text to fit.
--- @param ctx GraphicsContext The context object used for measuring the text width.
--- @param maxWidth number The maximum width allowed for the text.
--- @return string text The fitted text.
function Editor.fit_text(text, ctx, maxWidth)
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
