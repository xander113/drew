local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Interface = {}
Interface.__index = Interface

local INK = Color3.fromRGB(15, 38, 79)
local BLUE = Color3.fromRGB(0, 80, 206)
local LIGHT_BLUE = Color3.fromRGB(218, 236, 255)
local PAPER = Color3.fromRGB(255, 251, 230)
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 209, 52)
local MINT = Color3.fromRGB(201, 246, 185)
local RED = Color3.fromRGB(156, 34, 49)
local BODY = Enum.Font.GothamMedium
local BOLD = Enum.Font.GothamBold
local DISPLAY = Enum.Font.FredokaOne
local CENTER = Enum.TextXAlignment.Center
local offset, scale = UDim2.fromOffset, UDim2.fromScale

local function item(class, name, parent)
	local object = Instance.new(class)
	object.Name, object.Parent = name, parent
	return object
end

local function fill(object, color, radius)
	object.BorderSizePixel = 0
	object.BackgroundColor3 = color or WHITE
	object.BackgroundTransparency = if color then 0 else 1
	if radius then item("UICorner", "Corners", object).CornerRadius = UDim.new(0, radius) end
	return object
end

local function box(parent, name, x, y, width, height, color, radius)
	local frame = item("Frame", name, parent)
	frame.Position, frame.Size = offset(x, y), offset(width, height)
	return fill(frame, color, radius)
end

local function label(parent, name, message, x, y, width, height, size, color, font, align)
	local text = item("TextLabel", name, parent)
	text.Position, text.Size = offset(x, y), offset(width, height)
	text.BackgroundTransparency = 1
	text.Text, text.TextSize, text.TextColor3 = message, size, color or INK
	text.Font, text.TextXAlignment = font or BODY, align or Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	return text
end

local function outline(parent, color, width)
	local stroke = item("UIStroke", "Line", parent)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color, stroke.Thickness = color, width or 2
	return stroke
end

local function screen(parent, name, order, full)
	local gui = item("ScreenGui", name, parent)
	gui.DisplayOrder, gui.ResetOnSpawn = order, false
	gui.ScreenInsets = if full then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	return gui
end

local function tween(object, length, values, style)
	if GuiService.ReducedMotionEnabled then
		for key, value in values do object[key] = value end
		return nil
	end
	local animation = TweenService:Create(object, TweenInfo.new(length, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), values)
	animation:Play()
	return animation
end

local function action(view, parent, caption, x, y, width, height, tint, callback, options)
	options = options or {}
	local base = box(parent, caption .. " Button", x, y, width, height + 5)
	local shadow = box(base, "Edge", 0, 5, width, height, INK, options.radius or 15)
	shadow.BackgroundTransparency = .12
	local button = item("TextButton", caption, base)
	button.Position, button.Size = offset(0, 0), offset(width, height)
	button.AutoButtonColor, button.Selectable = false, true
	button.Text = ""
	fill(button, tint, options.radius or 15)

	local color = if tint == BLUE then WHITE else INK
	if options.detail then
		label(button, "Name", caption, 17, 4, width - 34, 32, options.size or 25, color, DISPLAY)
		label(button, "Detail", options.detail, 18, 35, width - 34, 22, 14, color)
	else
		label(button, "Name", caption, 5, 0, width - 10, height, options.size or 22, color, DISPLAY, CENTER)
	end
	local focus = outline(button, INK, 3)
	focus.Transparency = 1
	button.SelectionGained:Connect(function() focus.Transparency = 0 end)
	button.SelectionLost:Connect(function() focus.Transparency = 1 end)
	button.MouseEnter:Connect(function()
		if not GuiService.ReducedMotionEnabled then tween(button, .12, { Position = offset(0, -2) }) end
	end)
	button.MouseLeave:Connect(function() tween(button, .14, { Position = offset(0, 0) }) end)
	button.MouseButton1Down:Connect(function()
		if not GuiService.ReducedMotionEnabled then tween(button, .08, { Position = offset(0, 4) }) end
	end)
	button.MouseButton1Up:Connect(function() tween(button, .13, { Position = offset(0, 0) }) end)
	button.Activated:Connect(callback)
	local key = options.key or caption
	button:SetAttribute("MenuControl", key)
	view.controls[key] = button
	if options.first or not view.first then view.first = button end
	return button
end

local function scroll(parent, name, x, y, width, height, count, rowHeight)
	local list = item("ScrollingFrame", name, parent)
	list.Position, list.Size = offset(x, y), offset(width, height)
	list.CanvasSize = offset(0, count * rowHeight)
	list.BackgroundTransparency, list.BorderSizePixel = 1, 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = BLUE
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	return list
end

local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Interface.new(parent, config, pay)
	local self = setmetatable({ config = config, pay = pay }, Interface)
	local backdrop = screen(parent, "WWMS Film", 20, true)
	self.backdrop = backdrop
	local shade = fill(item("Frame", "Shade", backdrop), INK)
	shade.Size, shade.BackgroundTransparency = scale(1, 1), .57
	local fade = fill(item("Frame", "Cut", backdrop), INK)
	fade.Size, fade.BackgroundTransparency, fade.ZIndex = scale(1, 1), 1, 2
	self.fade = fade

	local gui = screen(parent, "Cart Catcher", 21, false)
	self.screen = gui
	local menu = box(gui, "Menu", 0, 0, 0, 0)
	menu.Size = scale(1, 1)
	self.menu = menu

	local header = box(menu, "WWMS", 0, 0, 468, 46)
	self.header, self.headerScale = header, item("UIScale", "Scale", header)
	local logo = box(header, "Shop mark", 0, 0, 87, 43, BLUE, 16)
	outline(logo, WHITE, 2)
	label(logo, "Logo", "WWMS", 0, 0, 87, 43, 19, GOLD, DISPLAY, CENTER)
	local wallet = box(header, "Wallet", 267, 1, 201, 42, GOLD, 20)
	local coin = box(wallet, "Coin", 8, 8, 26, 26, PAPER, 20)
	label(coin, "Coin mark", "W", 0, 0, 26, 26, 15, INK, DISPLAY, CENTER)
	self.balance = label(wallet, "Balance", "Walbucks …", 42, 0, 152, 42, 16, INK, BOLD)

	local ticket = box(menu, "Ticket", 0, 0, 468, 488)
	self.ticket, self.ticketScale = ticket, item("UIScale", "Scale", ticket)
	box(ticket, "Ticket shadow", 0, 8, 468, 488, INK, 24)
	local surface = box(ticket, "Paper", 0, 0, 468, 488, PAPER, 24)
	outline(surface, INK, 2)
	box(surface, "Top trim", 20, 0, 428, 6, GOLD, 3)
	self.pageLayer = box(surface, "Pages", 0, 0, 468, 488)
	self.pageLayer.ClipsDescendants = true
	self.notice = label(surface, "Message", "", 23, 451, 420, 26, 14, RED, BOLD, CENTER)
	self.notice.TextWrapped, self.notice.TextTruncate = true, Enum.TextTruncate.None
	self.notice.ZIndex = 4

	local hud = box(gui, "Shift", 0, 0, 0, 0)
	hud.Size, hud.Visible = scale(1, 1), false
	self.hud = hud
	local top = box(hud, "Shift score", 0, 0, 376, 100, PAPER, 18)
	top.AnchorPoint, top.Position = Vector2.new(.5, 0), UDim2.new(.5, 0, 0, 8)
	outline(top, INK, 2)
	self.hudScale = item("UIScale", "Scale", top)
	self.hudLevel = label(top, "Level", "", 15, 8, 230, 18, 13, BLUE, BOLD)
	self.progress = label(top, "Carts", "", 15, 25, 229, 31, 26, INK, DISPLAY)
	self.timer = label(top, "Time", "", 244, 16, 115, 43, 31, INK, DISPLAY, Enum.TextXAlignment.Right)
	local track = box(top, "Cart bar", 15, 64, 346, 8, LIGHT_BLUE, 4)
	self.bar = box(track, "Carts back", 0, 0, 0, 8, BLUE, 4)
	self.personal = label(top, "My carts", "", 15, 74, 342, 20, 13, INK, BOLD)

	local tip = box(hud, "Shift help", 0, 0, 377, 68, INK, 16)
	tip.AnchorPoint = Vector2.new(.5, 1)
	outline(tip, WHITE, 1)
	self.tip, self.tipScale = tip, item("UIScale", "Scale", tip)
	self.tipTitle = label(tip, "Action", "", 15, 8, 346, 24, 20, GOLD, DISPLAY, CENTER)
	self.tipText = label(tip, "Help", "", 13, 33, 351, 25, 14, WHITE, BODY, CENTER)
	return self
end

function Interface:resize()
	local size = self.screen.AbsoluteSize
	if size.X < 70 or size.Y < 135 then return end
	local portrait = size.X / size.Y < .94
	local multiplier = math.min(1.14, (size.X - 26) / 468, (size.Y - 76) / 488)
	local x = math.floor((size.X - 468 * multiplier) / 2)
	self.ticketScale.Scale = multiplier
	self.ticket.Position = offset(x, math.max(63, math.floor((size.Y - 488 * multiplier) * .52)))
	self.headerScale.Scale = multiplier
	self.header.Position = offset(x, 9)
	self.hudScale.Scale = math.min(1, (size.X - 24) / 376, size.Y / 385)
	self.tipScale.Scale = self.hudScale.Scale
	self.tip.Position = UDim2.new(.5, 0, 1, if portrait then -108 else -18)
end

function Interface:setWallet(amount, ready, saving)
	self.balance.Text = if ready then self.pay.format(amount) .. " Walbucks" else "Walbucks …"
	self.balance.TextColor3 = if saving then BLUE else INK
end

function Interface:setNotice(message, pending)
	self.notice.Text, self.notice.TextColor3 = message or "", if pending then BLUE else RED
end

local function title(parent, value, subtitle)
	label(parent, "Title", value, 23, 57, 420, 58, 42, INK, DISPLAY)
	if subtitle then label(parent, "Help", subtitle, 24, 115, 420, 27, 17) end
end

local function back(view, parent, callback, text)
	return action(view, parent, text or "Back", 23, 17, 84, 33, LIGHT_BLUE, callback, { radius = 10, size = 17 })
end

local function levelChoices(view, parent, draft, crew, startY, selectLevel)
	local buttons, highlights = {}, {}
	local function paint(level)
		for index, pieces in highlights do
			local selected = index == level
			pieces.dot.Visible = selected
			pieces.border.Color = if selected then BLUE else LIGHT_BLUE
			pieces.row.BackgroundColor3 = if selected then LIGHT_BLUE else WHITE
		end
	end
	for index, level in view.config.Levels do
		local y = startY + (index - 1) * 59
		local row = item("TextButton", level.name, parent)
		row.Position, row.Size = offset(23, y), offset(421, 50)
		row.Text, row.AutoButtonColor, row.Selectable = "", false, true
		fill(row, WHITE, 12)
		local border = outline(row, LIGHT_BLUE)
		local ring = box(row, "Pick", 13, 14, 22, 22, WHITE, 14)
		outline(ring, BLUE)
		local dot = box(ring, "Picked", 4, 4, 14, 14, BLUE, 8)
		label(row, "Level", level.name, 47, 0, 155, 50, 22, INK, DISPLAY)
		label(row, "Time", clock(level.seconds), 225, 0, 66, 50, 17, INK, BOLD, CENTER)
		local goal = view.config.shift(index, crew).goal
		label(row, "Goal", "Return " .. goal, 304, 0, 108, 50, 17, INK, BOLD, CENTER)
		row.Activated:Connect(function()
			selectLevel(index)
			paint(index)
		end)
		row.SelectionGained:Connect(function() border.Thickness = 4 end)
		row.SelectionLost:Connect(function() border.Thickness = 2 end)
		row:SetAttribute("MenuControl", level.name)
		view.controls[level.name] = row
		buttons[index], highlights[index] = row, { row = row, border = border, dot = dot }
	end
	paint(draft)
	view.first = buttons[draft]
end

local function roomList(view, page, model, actions)
	local rows = model.rows or {}
	local list = scroll(page, "Public lobbies", 23, 157, 422, 172, #rows, 49)
	view.list = list
	if #rows == 0 then
		local message = if model.rows then "No public lobbies yet." else "Looking for lobbies…"
		label(page, "List state", message, 23, 163, 422, 73, 19, INK, BODY, CENTER)
	end
	for index, row in rows do
		local y = (index - 1) * 49
		local name = label(list, "Host", row.host, 0, y, 147, 41, 17, INK, BOLD)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		label(list, "Level", view.config.Levels[row.level].name, 149, y, 102, 41, 15)
		label(list, "Seats", string.format("%d/%d", row.members, view.config.MaxPlayers), 251, y, 64, 41, 15, INK, BOLD, CENTER)
		action(view, list, "Join", 321, y + 3, 83, 32, MINT, function() actions.send("JoinPublic", row.code) end, { size = 17, radius = 9, key = row.code })
		box(list, "Row line", 0, y + 46, 407, 1, LIGHT_BLUE)
	end
end

function Interface:showPage(route, model, actions)
	local lastRoute = self.route
	local scrollPosition = if self.list then self.list.CanvasPosition else Vector2.zero
	local selection = GuiService.SelectedObject
	local selectedKey
	if route == lastRoute and selection and selection:IsDescendantOf(self.pageLayer) then
		selectedKey = selection:GetAttribute("MenuControl")
	end
	self.route, self.first, self.list, self.countdown, self.controls = route, nil, nil, nil, {}
	if self.slide then self.slide:Cancel() end
	self.pageLayer:ClearAllChildren()
	local page = item("Frame", route, self.pageLayer)
	page.Size = scale(1, 1)
	page.BackgroundTransparency = 1
	if route ~= lastRoute and not GuiService.ReducedMotionEnabled then
		page.Position = offset(16, 0)
		self.slide = tween(page, .23, { Position = offset(0, 0) }, Enum.EasingStyle.Cubic)
	end

	local room = model.room
	if route == "Home" then
		label(page, "Title", "Cart", 23, 37, 331, 69, 65, INK, DISPLAY)
		label(page, "Title", "Catcher!", 23, 95, 331, 72, 65, BLUE, DISPLAY)
		local mark = box(page, "WWMS stamp", 351, 53, 92, 85, GOLD, 19)
		mark.Rotation = -8
		label(mark, "WWMS", "WWMS", 1, 0, 90, 85, 23, INK, DISPLAY, CENTER)
		label(page, "Shop name", "Willy Walter’s Mega Shop", 27, 177, 414, 28, 19, INK, BOLD)
		label(page, "How to play", "Bring carts back before time runs out.", 27, 205, 414, 27, 17)
		action(self, page, "Solo mode", 23, 261, 421, 66, BLUE, function() actions.go("Solo") end, { detail = "Play on your own" })
		action(self, page, "Multi", 23, 344, 421, 65, MINT, function() actions.go("Multi") end, { detail = "Play with others" })
		action(self, page, "Shop", 23, 430, 421, 39, GOLD, actions.shop, { size = 20, radius = 12 })
	elseif route == "Solo" then
		back(self, page, function() actions.go("Home") end)
		title(page, "Solo mode", "Pick a level.")
		levelChoices(self, page, model.solo, 1, 153, actions.soloLevel)
		action(self, page, "Play", 23, 363, 421, 56, BLUE, function() actions.send("Solo", model.solo) end)
	elseif route == "Multi" then
		back(self, page, function() actions.go("Home") end)
		title(page, "Multi", "Public lobbies")
		action(self, page, "Refresh", 350, 112, 94, 31, LIGHT_BLUE, actions.browse, { radius = 9, size = 16 })
		roomList(self, page, model, actions)
		action(self, page, "New lobby", 23, 359, 204, 58, BLUE, function() actions.go("Create") end, { first = true })
		action(self, page, "Join by code", 238, 359, 206, 58, MINT, function() actions.go("Code") end)
		if route == lastRoute and self.list then self.list.CanvasPosition = scrollPosition end
	elseif route == "Code" then
		back(self, page, function() actions.go("Multi") end)
		title(page, "Join by code", "Enter the 7 letters or numbers.")
		local field = item("TextBox", "Lobby code", page)
		field.Position, field.Size = offset(23, 173), offset(421, 65)
		fill(field, WHITE, 14)
		outline(field, BLUE)
		field.Font, field.TextSize = DISPLAY, 31
		field.TextColor3, field.PlaceholderColor3 = INK, BLUE
		field.ClearTextOnFocus, field.Selectable = false, true
		field.Text, field.PlaceholderText = model.code, "Lobby code"
		field:GetPropertyChangedSignal("Text"):Connect(function()
			local code = string.sub(string.upper(string.gsub(field.Text, "[^%w]", "")), 1, 7)
			if field.Text ~= code then field.Text = code end
			actions.code(code)
		end)
		field.FocusLost:Connect(function(enter) if enter then actions.send("JoinCode", field.Text) end end)
		action(self, page, "Join", 23, 277, 421, 58, BLUE, function() actions.send("JoinCode", field.Text) end)
		self.first = field
	elseif route == "Create" then
		back(self, page, function() actions.go("Multi") end)
		title(page, "New lobby", "Pick who can join.")
		for index, name in { "Public", "Private" } do
			local private = index == 2
			action(self, page, name, 23 + (index - 1) * 215, 147, 206, 57, if model.private == private then BLUE else LIGHT_BLUE, function() actions.privacy(private) end, {
				size = 20, radius = 11, detail = if private then "Join with a code" else "Anyone can join",
			})
		end
		levelChoices(self, page, model.multi, 1, 210, actions.multiLevel)
		action(self, page, "Create lobby", 23, 398, 421, 45, BLUE, function() actions.send("Create", model.multi, model.private) end)
	elseif route == "Lobby" then
		back(self, page, function() actions.send("Leave") end, "Leave")
		title(page, if room.private then "Private lobby" else "Public lobby")
		label(page, "Level and count", string.format("%s     %d/%d players", self.config.Levels[room.level].name, #room.members, self.config.MaxPlayers), 24, 113, 420, 28, 16, INK, BOLD)
		local listY = 151
		if room.private then
			local tag = box(page, "Share", 23, 151, 421, 44, GOLD, 12)
			label(tag, "Help", "Share this code", 12, 0, 175, 44, 15, INK, BOLD)
			label(tag, "Code", room.code or "", 186, 0, 219, 44, 25, INK, DISPLAY, Enum.TextXAlignment.Right)
			listY = 206
		end
		local list = scroll(page, "Players", 23, listY, 421, 338 - listY, #room.members, 28)
		for index, name in room.members do
			label(list, "Player", name, 2, (index - 1) * 28, 308, 27, 17)
			if index == 1 then label(list, "Host", "Host", 318, 0, 83, 27, 13, BLUE, BOLD, Enum.TextXAlignment.Right) end
		end
		if room.host then
			action(self, page, "Change level", 23, 367, 196, 55, LIGHT_BLUE, function() actions.roomLevel() end, { size = 18 })
			action(self, page, "Start", 232, 367, 212, 55, BLUE, function() actions.send("Start") end, { first = true })
		else
			label(page, "Wait", "Wait for the host to start.", 23, 370, 420, 50, 19, INK, BOLD, CENTER)
		end
	elseif route == "Level" then
		back(self, page, function() actions.go(if room.phase == "Results" then "Results" else "Lobby") end)
		title(page, "Change level", "Pick a level for the next shift.")
		levelChoices(self, page, model.roomLevel, #room.members, 153, actions.pickRoomLevel)
		action(self, page, "Save", 23, 360, 421, 54, BLUE, function() actions.send("Level", model.roomLevel) end)
	elseif route == "Briefing" then
		title(page, "Get ready", self.config.Levels[room.level].name)
		self.countdown = label(page, "Countdown", "", 23, 164, 421, 129, 108, BLUE, DISPLAY, CENTER)
		label(page, "Help", "Grab a cart and push it back.", 23, 321, 421, 41, 20, INK, BOLD, CENTER)
	elseif route == "Results" then
		local result, mine = room.result, room.mine
		local pay = mine and mine.pay
		back(self, page, function() actions.send("Leave") end, "Leave")
		title(page, if result.outcome == "Filled" then "You filled it!" else "Time’s up",
			string.format("%d/%d crew carts. You brought back %d.", result.banked, result.goal, if mine then mine.carts else 0))
		local bill = box(page, "Pay", 23, 152, 421, 156, MINT, 17)
		label(bill, "Total", "+" .. self.pay.format(if pay then pay.total else 0) .. " Walbucks", 12, 7, 397, 45, 30, INK, DISPLAY, CENTER)
		if pay and pay.total > 0 then
			for index, line in { {"Your work", pay.work}, {"Crew pay", pay.team}, {"Full bay bonus", pay.bonus} } do
				label(bill, "Pay item", line[1], 19, 50 + (index - 1) * 30, 180, 28, 16, INK, BOLD)
				label(bill, "Amount", self.pay.format(line[2]), 206, 50 + (index - 1) * 30, 194, 28, 16, INK, BOLD, Enum.TextXAlignment.Right)
			end
		else
			label(bill, "Help", "Bring back a cart to earn pay.", 12, 63, 397, 42, 16, INK, BOLD, CENTER)
		end
		if room.host then
			local solo = room.mode == "Solo"
			action(self, page, if solo then "Change level" else "Open lobby", 23, 361, 196, 54, LIGHT_BLUE, function()
				if solo then actions.roomLevel() else actions.send("Reopen") end
			end, { size = 18 })
			action(self, page, "Play again", 232, 361, 212, 54, BLUE, function() actions.send("Start") end, { first = true })
		else
			label(page, "Wait", "Wait for the host to pick what’s next.", 23, 362, 421, 50, 17, INK, BOLD, CENTER)
		end
	elseif route == "Return" then
		title(page, "Lobby closed", "Go back and pick a new lobby.")
		action(self, page, "Main menu", 23, 277, 421, 58, BLUE, function() actions.send("Leave") end)
	else
		title(page, "One moment", "Getting your lobby.")
	end
	if selectedKey and self.controls[selectedKey] then GuiService.SelectedObject = self.controls[selectedKey] end
end

function Interface:showShift(room, seconds, personal, carrying, input)
	self.hudLevel.Text = self.config.Levels[room.level].name
	self.progress.Text = string.format("Carts %d/%d", room.banked, room.goal)
	self.timer.Text, self.timer.TextColor3 = clock(seconds), if seconds <= 15 then RED else INK
	local ratio = math.clamp(room.banked / math.max(room.goal, 1), 0, 1)
	if self.ratio ~= ratio then
		if self.fillTween then self.fillTween:Cancel() end
		self.fillTween = tween(self.bar, .19, { Size = UDim2.new(ratio, 0, 0, 8) })
		self.ratio = ratio
	end
	self.personal.Text = "Your carts: " .. personal
	if carrying then
		self.tipTitle.Text, self.tipText.Text = "Bring it back", "Push the cart into the blue cart hole."
	else
		self.tipTitle.Text = "Find a cart"
		if input == Enum.UserInputType.Touch then
			self.tipText.Text = "Tap Grab cart when you get close."
		elseif string.match(input.Name, "^Gamepad") then
			self.tipText.Text = "Press X near a cart."
		else
			self.tipText.Text = "Press E near a cart."
		end
	end
end

function Interface:teleportGui()
	local gui = screen(nil, "Cart Catcher Travel", 30, true)
	local background = fill(item("Frame", "Blue", gui), BLUE)
	background.Size = scale(1, 1)
	local mark = label(background, "Title", "Cart Catcher!", 0, 0, 350, 80, 45, GOLD, DISPLAY, CENTER)
	mark.AnchorPoint, mark.Position = Vector2.new(.5, .5), scale(.5, .46)
	local line = label(background, "Help", "One moment…", 0, 0, 250, 35, 20, WHITE, BOLD, CENTER)
	line.AnchorPoint, line.Position = Vector2.new(.5, .5), scale(.5, .55)
	return gui
end

return Interface
